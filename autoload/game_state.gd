extends Node
## Campaign-wide state that outlives a level scene (GDD 8, 10.1): where the player is in the
## campaign, each zone's evolving population, the best genomes (for Apex bosses), what the
## player carries (samples, scrap), XP / skills between levels, and post-game unlocks.
## Saved to its own slot (SaveSystem.CAMPAIGN_PATH) at level boundaries.
##
## Flow:  start_new_campaign() -> start_current_level() loads main.tscn with the level
##        level done -> finish_level(evolution, player) -> next level / Safehouse / victory
##        Safehouse -> enter_next_zone(): new population = 20 % of the last zone's best + random

const GAME_SCENE: String = "res://world/main.tscn"
const SAFEHOUSE_SCENE: String = "res://ui/menus/safehouse.tscn"
const CAMPAIGN_PATH: String = "res://data/campaign/campaign.tres"
const SAVE_FORMAT: int = 1

## Collected this run (GDD 7.5 samples for research, 7.6 scrap for the Safehouse).
var samples: int = 0
var scrap: int = 0
## Level the next main.tscn load should play (null = prototype loop). Set by menus / campaign.
var pending_level: LevelConfig

## Best genome per zone so far (Apex bosses are built from it): zone -> {fitness, genome dict}.
var zone_best: Dictionary = {}
## Top genomes (by fitness) of each zone's latest wave: zone -> [genome dicts]. Seeds the next zone.
var zone_elite: Dictionary = {}
## Zone being played (1..4). The prototype loop counts as zone 1.
var current_zone: int = 1

## Campaign position and carried state.
var campaign_active: bool = false
var level_index: int = 0
## zone -> WaveManager.get_save_state() at the end of the zone's last finished level.
var zone_evolution: Dictionary = {}
## SaveGame "player" section (XP, level, skills) carried between level scenes.
var player_data: Dictionary = {}
## Side objectives completed (ids).
var side_done: Array[String] = []
## The Seed is destroyed: Endless and New Game+ unlock.
var campaign_won: bool = false
var endless_unlocked: bool = false
var ng_plus_unlocked: bool = false
## This campaign is a New Game+ run (higher mutation rate).
var ng_plus: bool = false
## Endless mode: best wave reached (the local "leaderboard", GDD 8.4).
var endless_best_wave: int = 0
## The prototype loop was started as post-game Endless mode.
var endless_mode: bool = false
## Set by the Safehouse: what it should show ("zone" after an Apex, "victory" at the end).
var safehouse_mode: String = "zone"
## A zone's Apex was beaten and the next zone has not been entered yet: Continue Campaign
## goes to the Safehouse instead of replaying the Apex. Saved with the campaign.
var safehouse_pending: bool = false
## Test scenario run (main menu -> Test Scenarios, see DebugScenarios): the campaign save is
## never written. Ends with end_test_mode() or when the game is closed.
var test_mode: bool = false
## Waves of the next level already counted as done (test scenarios start at the last wave).
var pending_start_wave: int = 0

var _campaign: CampaignConfig


func campaign() -> CampaignConfig:
	if _campaign == null:
		_campaign = load(CAMPAIGN_PATH)
	return _campaign


# --- Inventory and genomes -----------------------------------------------------------

func add_pickup(kind: StringName, amount: int) -> void:
	match kind:
		&"sample": samples += amount
		&"scrap": scrap += amount


func reset_inventory() -> void:
	samples = 0
	scrap = 0


## Remembers the fittest genome of a finished wave if it beats the zone's best so far, and the
## wave's top share as the zone's elite. `results` = WaveManager.last_wave_results (best first).
func record_wave_best(results: Array[Dictionary]) -> void:
	if results.is_empty() or results[0].get("genome") == null:
		return
	var best: Dictionary = zone_best.get(current_zone, {})
	if best.is_empty() or results[0]["fitness"] > best["fitness"]:
		zone_best[current_zone] = {"fitness": results[0]["fitness"], "genome": (results[0]["genome"] as Genome).to_dict()}
	var share: float = campaign().elite_carry_share if campaign() != null else 0.2
	var elite: Array = []
	for i: int in maxi(1, roundi(results.size() * share)):
		elite.append((results[i]["genome"] as Genome).to_dict())
	zone_elite[current_zone] = elite


## The zone's strongest genome so far, or null.
func zone_best_genome(zone: int = -1) -> Genome:
	var best: Dictionary = zone_best.get(current_zone if zone < 0 else zone, {})
	return Genome.from_dict(best["genome"]) if not best.is_empty() else null


## The strongest genome of the whole run (all zones), or null. The Seed is built from it.
func run_best_genome() -> Genome:
	var best: Dictionary = {}
	for z: Variant in zone_best:
		if best.is_empty() or zone_best[z]["fitness"] > best["fitness"]:
			best = zone_best[z]
	return Genome.from_dict(best["genome"]) if not best.is_empty() else null


# --- Campaign flow -------------------------------------------------------------------

## Fresh campaign (New Game+: keeps XP / skills, raises the mutation rate).
func start_new_campaign(as_ng_plus: bool = false) -> void:
	var keep_player: Dictionary = player_data if as_ng_plus else {}
	campaign_active = true
	ng_plus = as_ng_plus
	current_zone = 1
	level_index = 0
	zone_evolution.clear()
	zone_best.clear()
	zone_elite.clear()
	side_done.clear()
	player_data = keep_player
	campaign_won = false  # the previous run's win only hid Continue for the new run; the unlocks stay
	safehouse_pending = false
	reset_inventory()


func current_level() -> LevelConfig:
	return campaign().get_level(current_zone, level_index)


## Loads main.tscn with the current campaign level.
func start_current_level(tree: SceneTree) -> void:
	pending_level = current_level()
	tree.paused = false
	tree.change_scene_to_file(GAME_SCENE)


## True when the current level is the zone's Apex (last) level.
func is_apex_level() -> bool:
	return level_index == campaign().zones[current_zone - 1].levels.size() - 1


## A campaign level was completed. Stores the zone's evolution and the player's progress,
## advances, saves, and returns where to go: "level" (next level), "safehouse" (zone done)
## or "victory" (the Seed is destroyed).
func finish_level(evolution: Dictionary, player: Dictionary) -> String:
	zone_evolution[current_zone] = evolution
	player_data = player
	var destination: String = "level"
	if is_apex_level():
		if current_zone >= campaign().zones.size():
			campaign_won = true
			endless_unlocked = true
			ng_plus_unlocked = true
			destination = "victory"
		else:
			destination = "safehouse"
		safehouse_mode = "victory" if destination == "victory" else "zone"
		safehouse_pending = destination == "safehouse"
	else:
		level_index += 1
	save_campaign()
	return destination


## Same level again from its first wave; evolution and XP so far are kept (GDD 7.2).
func restart_level(evolution: Dictionary, player: Dictionary) -> void:
	zone_evolution[current_zone] = evolution
	player_data = player
	save_campaign()


## Safehouse -> next zone: level 1 of zone + 1, with a new population seeded from the old
## zone's elite (elite_carry_share) and the rest random, at the zone's first-wave budget.
func enter_next_zone() -> void:
	var rules: GenomeRules = load("res://data/genome_rules.tres")
	var size: int = (load("res://data/ga.tres") as GASettings).population_size
	var budget: int = rules.budget_for_wave(1)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 1000 + current_zone
	var population: Array = []
	var carried: int = mini(roundi(size * campaign().elite_carry_share), (zone_elite.get(current_zone, []) as Array).size())
	for i: int in carried:
		var g: Genome = Genome.from_dict(zone_elite[current_zone][i])
		g.repair(rules, budget)
		population.append(g.to_dict())
	while population.size() < size:
		population.append(Genome.random(rng, rules, budget).to_dict())
	current_zone += 1
	level_index = 0
	safehouse_pending = false
	zone_evolution[current_zone] = {"next_wave": 1, "generation": 0, "population": population, "history": []}
	save_campaign()


## Endless mode reached `wave`: remembers (and saves) the best wave so it survives closing the game.
func note_endless_wave(wave: int) -> void:
	if wave <= endless_best_wave:
		return
	endless_best_wave = wave
	save_campaign()


func leave_campaign() -> void:
	campaign_active = false
	pending_level = null


# --- Save ----------------------------------------------------------------------------

func to_dict() -> Dictionary:
	return {
		"format": SAVE_FORMAT, "active": campaign_active, "zone": current_zone, "level_index": level_index,
		"zone_evolution": zone_evolution, "zone_best": zone_best, "zone_elite": zone_elite,
		"player": player_data, "samples": samples, "scrap": scrap, "side_done": side_done,
		"won": campaign_won, "endless_unlocked": endless_unlocked, "ng_plus_unlocked": ng_plus_unlocked,
		"ng_plus": ng_plus, "endless_best_wave": endless_best_wave, "safehouse_pending": safehouse_pending,
	}


## Restores from a saved dictionary. False (state untouched) if it isn't a campaign save.
## Zone keys come back from JSON as strings; they are turned back into ints.
func from_dict(d: Dictionary) -> bool:
	if _num(d.get("format"), 0) != SAVE_FORMAT:
		return false
	campaign_active = _flag(d.get("active"))
	current_zone = clampi(_num(d.get("zone"), 1), 1, 4)
	level_index = clampi(_num(d.get("level_index"), 0), 0, 3)
	zone_evolution = _int_keys(d.get("zone_evolution", {}))
	zone_best = _int_keys(d.get("zone_best", {}))
	zone_elite = _int_keys(d.get("zone_elite", {}))
	player_data = d.get("player", {}) if d.get("player") is Dictionary else {}
	samples = _num(d.get("samples"), 0)
	scrap = _num(d.get("scrap"), 0)
	side_done.clear()
	if d.get("side_done") is Array:
		for id: Variant in d["side_done"]:
			if id is String:
				side_done.append(id)
	campaign_won = _flag(d.get("won"))
	endless_unlocked = _flag(d.get("endless_unlocked"))
	ng_plus_unlocked = _flag(d.get("ng_plus_unlocked"))
	ng_plus = _flag(d.get("ng_plus"))
	endless_best_wave = _num(d.get("endless_best_wave"), 0)
	safehouse_pending = _flag(d.get("safehouse_pending"))
	return true


func save_campaign() -> Error:
	if test_mode:
		return OK  # test scenarios never touch the real campaign save
	return SaveSystem.write_save(to_dict(), SaveSystem.CAMPAIGN_PATH)


## Leaves a test scenario run: forgets everything it set and reloads the real campaign save.
func end_test_mode() -> void:
	test_mode = false
	pending_start_wave = 0
	start_new_campaign()
	campaign_active = false
	player_data = {}
	campaign_won = false
	endless_unlocked = false
	ng_plus_unlocked = false
	endless_best_wave = 0
	endless_mode = false
	load_campaign()


func load_campaign() -> bool:
	var r: Dictionary = SaveSystem.read_save(SaveSystem.CAMPAIGN_PATH)
	return r["ok"] and from_dict(r["data"])


## A hand-edited or damaged save may hold the wrong type: use the default instead of crashing.
static func _num(v: Variant, fallback: int) -> int:
	return int(v) if v is int or v is float else fallback


static func _flag(v: Variant) -> bool:
	return v is bool and v


static func _int_keys(d: Variant) -> Dictionary:
	var out: Dictionary = {}
	if d is Dictionary:
		for k: Variant in d:
			out[int(k)] = d[k]
	return out

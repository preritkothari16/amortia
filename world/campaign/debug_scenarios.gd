class_name DebugScenarios
extends RefCounted
## Test shortcuts (main menu -> Test Scenarios): put the campaign right before a moment worth
## checking - a level's end, an Apex, the Safehouse, a new zone, the Seed, victory - without
## playing up to it. Runs in GameState.test_mode, so the campaign save is never written.
##
## Earlier zones are stood in for by seeded random genomes, recorded through the real
## GameState.record_wave_best() and carried over by the real GameState.enter_next_zone(), so a
## later zone starts the way it would in a campaign (only the genomes are not evolved).
## The player gets the gear of a player who cleared the earlier zones (the shotgun, one vaccine per
## cleared zone, some resources): test convenience only, not a balance number.

const SEED: int = 4242

## Transitions offered by the menu. zone 1..4, level = 0-based index (3 = Apex),
## scene "level" / "safehouse" / "victory", last_wave = start at the level's final wave.
const SCENARIOS: Array[Dictionary] = [
	{"text": "Level end -> next level", "zone": 1, "level": 0, "scene": "level", "last_wave": true},
	{"text": "Apex boss -> Safehouse", "zone": 1, "level": 3, "scene": "level", "last_wave": false},
	{"text": "Safehouse -> Lowtide (new zone)", "zone": 1, "level": 3, "scene": "safehouse", "last_wave": false},
	{"text": "The Seed -> victory", "zone": 4, "level": 3, "scene": "level", "last_wave": false},
	{"text": "Victory -> New Game+", "zone": 4, "level": 3, "scene": "victory", "last_wave": false},
]


## Starts a scenario from SCENARIOS (or any {zone, level, scene, last_wave} dictionary).
static func launch(tree: SceneTree, scenario: Dictionary) -> void:
	if prepare_scenario(scenario):
		tree.paused = false
		tree.change_scene_to_file(GameState.SAFEHOUSE_SCENE)
	else:
		GameState.start_current_level(tree)


## Sets GameState up for a scenario. True if it opens the Safehouse, false if it plays a level.
static func prepare_scenario(scenario: Dictionary) -> bool:
	prepare(scenario["zone"], scenario["level"], scenario["last_wave"])
	if scenario["scene"] == "level":
		return false
	GameState.safehouse_mode = "victory" if scenario["scene"] == "victory" else "zone"
	if scenario["scene"] == "victory":
		# What GameState.finish_level does after the Seed.
		GameState.campaign_won = true
		GameState.endless_unlocked = true
		GameState.ng_plus_unlocked = true
	return true


## Sets GameState up as a test campaign at `zone`, level `level_index` (0-based).
## last_wave: the level starts at its final wave (earlier waves count as done).
static func prepare(zone: int, level_index: int, last_wave: bool) -> void:
	GameState.test_mode = true
	GameState.start_new_campaign()
	GameState.campaign_won = false
	GameState.endless_unlocked = false
	GameState.ng_plus_unlocked = false
	GameState.endless_mode = false
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = SEED
	for z: int in range(1, zone + 1):
		_record_stand_in_wave(rng, z)
		if z < zone:
			GameState.enter_next_zone()
	GameState.level_index = level_index
	_gear_for_zone(zone)
	var level: LevelConfig = GameState.current_level()
	GameState.pending_start_wave = level.waves - 1 if last_wave and level != null else 0


## The gear of a player who has cleared zone - 1 zones: from zone 2 on the shotgun (spare slot) and one
## vaccine per cleared zone, plus some resources to spend in the Safehouse.
static func _gear_for_zone(zone: int) -> void:
	GameState.loadout = PlayerLoadout.new()
	GameState.research().restore([])
	if zone >= 2:
		GameState.loadout.owned.append(&"shotgun")
		GameState.loadout.equip(&"shotgun", 1)
		var vaccines: Array = ["vaccine_1", "vaccine_2", "vaccine_3"].slice(0, zone - 1)
		GameState.research().restore(vaccines)
	GameState.scrap = 60 * (zone - 1)
	GameState.samples = 12 * (zone - 1)


## One wave's results for the current zone made of random genomes (best first), recorded as
## if it had been played: zone best (Apex / Seed boss) and zone elite (next zone's seed).
static func _record_stand_in_wave(rng: RandomNumberGenerator, zone: int) -> void:
	var rules: GenomeRules = load("res://data/genome_rules.tres")
	var size: int = (load("res://data/ga.tres") as GASettings).population_size
	var results: Array[Dictionary] = []
	for i: int in size:
		results.append({"fitness": 1.0 - float(i) / size, "genome": Genome.random(rng, rules, rules.budget_for(zone, 1))})
	GameState.record_wave_best(results)

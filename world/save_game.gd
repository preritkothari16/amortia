class_name SaveGame
extends RefCounted
## Builds the save dictionary from game state and checks a loaded one before it is used.
## Only plain data (numbers, strings, arrays, dictionaries) — never Nodes or Resources.
##
## The save is a checkpoint *between waves*: it holds the population that will play
## `next_wave`. XP and skills bought during a wave are saved at the next wave end.
##
## Format (version 1):
## { "version": 1, "saved_at": "2026-10-03T21:40:00",
##   "player": { "level", "xp", "total_xp", "skill_points", "unlocked": [skill ids] },
##   "evolution": { "next_wave", "generation", "population": [Genome.to_dict()],
##                  "history": [{ "from_wave", "best_fitness", "mean_fitness" }],
##                  "ga_seed", "ga_rng_state", "spawn_rng_state" } }
## RNG states are stored as strings: JSON numbers are doubles and would round 64-bit ints.

const VERSION: int = 1
const MAX_WAVE: int = 100000
const MAX_POPULATION: int = 500


## The save dictionary for the current game. `evolution` comes from WaveManager.get_save_state().
static func capture(progression: PlayerProgression, skills: PlayerSkills, evolution: Dictionary) -> Dictionary:
	var unlocked: Array[String] = []
	for id: StringName in skills.unlocked:
		unlocked.append(String(id))
	return {
		"version": VERSION,
		"saved_at": Time.get_datetime_string_from_system(),
		"player": {
			"level": progression.level, "xp": progression.xp, "total_xp": progression.total_xp,
			"skill_points": progression.skill_points, "unlocked": unlocked,
		},
		"evolution": evolution,
	}


## Checks a loaded save and returns a cleaned copy.
## Result: { "ok": bool, "error": String, "warnings": PackedStringArray, "data": Dictionary }.
## Broken structure (wrong version, missing sections, unreadable genomes) -> ok = false, the
## save is not used. Values that are only out of range are fixed and reported as warnings.
static func validate(data: Variant, settings: ProgressionSettings, tree: SkillTree,
		rules: GenomeRules) -> Dictionary:
	var warnings: PackedStringArray = PackedStringArray()
	if not data is Dictionary:
		return _fail("save is not a dictionary")
	var d: Dictionary = data
	if not _is_number(d.get("version")) or int(d["version"]) != VERSION:
		return _fail("unsupported save version %s (expected %d)" % [d.get("version"), VERSION])
	if not d.get("player") is Dictionary or not d.get("evolution") is Dictionary:
		return _fail("save is missing the player or evolution section")

	var player: Dictionary = _validate_player(d["player"], settings, tree, warnings)
	var evolution: Dictionary = _validate_evolution(d["evolution"], rules, warnings)
	if evolution.has("error"):
		return _fail(evolution["error"])
	return {"ok": true, "error": "", "warnings": warnings,
		"data": {"version": VERSION, "player": player, "evolution": evolution}}


# --- Player ------------------------------------------------------------------------

static func _validate_player(p: Dictionary, settings: ProgressionSettings, tree: SkillTree,
		warnings: PackedStringArray) -> Dictionary:
	var level: int = _int_in(p, "level", 1, settings.level_cap, 1, warnings)
	var xp_max: int = maxi(settings.xp_to_next(level) - 1, 0)  # 0 at the cap
	var xp: int = _int_in(p, "xp", 0, xp_max, 0, warnings)
	var total_xp: int = _int_in(p, "total_xp", 0, 1 << 30, 0, warnings)

	# Skills: known ids only, no duplicates, prerequisites bought earlier in the list.
	var unlocked: Array[StringName] = []
	var raw_ids: Variant = p.get("unlocked", [])
	if not raw_ids is Array:
		warnings.append("player.unlocked is not a list; no skills restored")
		raw_ids = []
	for raw: Variant in raw_ids:
		var id: StringName = StringName(str(raw))
		var node: SkillNode = tree.get_node_by_id(id) if raw is String else null
		if node == null:
			warnings.append("unknown skill %s dropped" % [raw])
		elif unlocked.has(id):
			warnings.append("duplicate skill %s dropped" % id)
		elif not node.requires.all(func(r: StringName) -> bool: return unlocked.has(r)):
			warnings.append("skill %s dropped: prerequisite missing" % id)
		else:
			unlocked.append(id)

	# Points only come from levels, so: earned = spent + unspent. Drop the latest skills if the
	# level can't pay for them, then set unspent points to what is left.
	var earned: int = (level - 1) * settings.skill_points_per_level
	while _cost_of(unlocked, tree) > earned:
		warnings.append("skill %s dropped: level %d can't pay for it" % [unlocked[-1], level])
		unlocked.pop_back()
	var points: int = earned - _cost_of(unlocked, tree)
	if not _is_number(p.get("skill_points")) or int(p["skill_points"]) != points:
		warnings.append("skill_points %s corrected to %d" % [p.get("skill_points"), points])
	return {"level": level, "xp": xp, "total_xp": total_xp, "skill_points": points, "unlocked": unlocked}


static func _cost_of(ids: Array[StringName], tree: SkillTree) -> int:
	var total: int = 0
	for id: StringName in ids:
		total += tree.get_node_by_id(id).cost
	return total


# --- Evolution ---------------------------------------------------------------------

static func _validate_evolution(e: Dictionary, rules: GenomeRules, warnings: PackedStringArray) -> Dictionary:
	var next_wave: int = _int_in(e, "next_wave", 1, MAX_WAVE, 1, warnings)
	var generation: int = _int_in(e, "generation", 0, next_wave - 1, 0, warnings)

	var raw_pop: Variant = e.get("population")
	if not raw_pop is Array or (raw_pop as Array).is_empty() or (raw_pop as Array).size() > MAX_POPULATION:
		return {"error": "population missing, empty or too large"}
	var budget: int = rules.budget_for_wave(next_wave)
	var population: Array[Dictionary] = []
	for i: int in (raw_pop as Array).size():
		var g: Variant = raw_pop[i]
		if not g is Dictionary:
			return {"error": "genome %d is not a dictionary" % i}
		for gene: StringName in Genome.STAT_GENES + Genome.BEHAVIOUR_GENES:
			if not _is_number(g.get(String(gene))):
				return {"error": "genome %d: gene %s missing or not a number" % [i, gene]}
		if not Genome.PathMode.keys().has(g.get("path_mode")):
			return {"error": "genome %d: unknown path_mode %s" % [i, g.get("path_mode")]}
		var genome: Genome = Genome.from_dict(g)
		if not genome.is_valid(rules, budget) or not genome.spends_budget(rules, budget):
			genome.repair(rules, budget)  # clamp genes, spend exactly the stat budget
			warnings.append("genome %d repaired to fit wave %d (budget %d)" % [i, next_wave, budget])
		population.append(genome.to_dict())

	var history: Array[Dictionary] = []
	var raw_history: Variant = e.get("history", [])
	if raw_history is Array:
		for h: Variant in raw_history:
			if h is Dictionary and _is_number(h.get("from_wave")) and _is_number(h.get("best_fitness")) \
					and _is_number(h.get("mean_fitness")):
				history.append({"from_wave": int(h["from_wave"]), "best_fitness": float(h["best_fitness"]),
					"mean_fitness": float(h["mean_fitness"])})
			else:
				warnings.append("bad history entry dropped")
	else:
		warnings.append("history is not a list; dropped")

	var result: Dictionary = {"next_wave": next_wave, "generation": generation,
		"population": population, "history": history}
	for key: String in ["ga_seed", "ga_rng_state", "spawn_rng_state"]:
		var v: Variant = e.get(key)
		if v is String and (v as String).is_valid_int():
			result[key] = v
		else:
			warnings.append("%s missing or invalid; a fresh one will be used" % key)
	return result


# --- Helpers -----------------------------------------------------------------------

static func _fail(message: String) -> Dictionary:
	return {"ok": false, "error": message, "warnings": PackedStringArray(), "data": {}}


## JSON numbers load as float; accept int or float.
static func _is_number(v: Variant) -> bool:
	return v is int or v is float


## d[key] as an int clamped to [lo, hi]; `fallback` if missing. Reports any change.
static func _int_in(d: Dictionary, key: String, lo: int, hi: int, fallback: int,
		warnings: PackedStringArray) -> int:
	if not _is_number(d.get(key)):
		warnings.append("%s missing or not a number; using %d" % [key, fallback])
		return fallback
	var raw: float = float(d[key])
	var value: int = clampi(int(raw), lo, hi)
	if value != raw:
		warnings.append("%s %s out of range; using %d" % [key, d[key], value])
	return value

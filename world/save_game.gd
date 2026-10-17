class_name SaveGame
extends RefCounted
## Builds the save dictionary of the prototype loop and checks a loaded one before it is used.
## Only plain data (numbers, strings, arrays, dictionaries) - never Nodes or Resources.
##
## The save is a checkpoint *between waves*: it holds the population that will play `next_wave`.
##
## Format (version 1):
## { "version": 1, "saved_at": "2026-10-03T21:40:00",
##   "player": {} (older files: XP / level / skills, ignored),
##   "evolution": { "next_wave", "generation", "population": [Genome.to_dict()],
##                  "history": [{ "from_wave", "best_fitness", "mean_fitness" }],
##                  "ga_seed", "ga_rng_state", "spawn_rng_state" } }
## RNG states are stored as strings: JSON numbers are doubles and would round 64-bit ints.

const VERSION: int = 1
const MAX_WAVE: int = 100000
const MAX_POPULATION: int = 500


## The save dictionary for the prototype loop. `evolution` comes from WaveManager.get_save_state().
## (Older saves also carried a "player" section with XP, level and skills; it is written empty now and
## ignored on load.)
static func capture(evolution: Dictionary) -> Dictionary:
	return {
		"version": VERSION,
		"saved_at": Time.get_datetime_string_from_system(),
		"player": {},
		"evolution": evolution,
	}


## Checks a loaded save and returns a cleaned copy.
## Result: { "ok": bool, "error": String, "warnings": PackedStringArray, "data": Dictionary }.
## Broken structure (wrong version, missing evolution, unreadable genomes) -> ok = false, the save is
## not used. Values that are only out of range are fixed and reported as warnings. An old "player"
## section (XP, level, skills) is accepted and ignored, with a warning when it held progress.
static func validate(data: Variant, rules: GenomeRules, zone: int = 1) -> Dictionary:
	var warnings: PackedStringArray = PackedStringArray()
	if not data is Dictionary:
		return _fail("save is not a dictionary")
	var d: Dictionary = data
	if not _is_number(d.get("version")) or int(d["version"]) != VERSION:
		return _fail("unsupported save version %s (expected %d)" % [d.get("version"), VERSION])
	if not d.get("evolution") is Dictionary:
		return _fail("save is missing the evolution section")
	if d.get("player") is Dictionary and _legacy_progress(d["player"]):
		warnings.append("XP, levels and skills no longer exist: ignored")
	var evolution: Dictionary = _validate_evolution(d["evolution"], rules, warnings, zone)
	if evolution.has("error"):
		return _fail(evolution["error"])
	return {"ok": true, "error": "", "warnings": warnings,
		"data": {"version": VERSION, "evolution": evolution}}


static func _legacy_progress(player: Dictionary) -> bool:
	return (_is_number(player.get("level")) and int(player["level"]) > 1) \
			or (player.get("unlocked") is Array and not (player["unlocked"] as Array).is_empty())


# --- Evolution ---------------------------------------------------------------------

static func _validate_evolution(e: Dictionary, rules: GenomeRules, warnings: PackedStringArray, zone: int = 1) -> Dictionary:
	var next_wave: int = _int_in(e, "next_wave", 1, MAX_WAVE, 1, warnings)
	var generation: int = _int_in(e, "generation", 0, next_wave - 1, 0, warnings)

	var raw_pop: Variant = e.get("population")
	if not raw_pop is Array or (raw_pop as Array).is_empty() or (raw_pop as Array).size() > MAX_POPULATION:
		return {"error": "population missing, empty or too large"}
	var budget: int = rules.budget_for(zone, next_wave)
	var population: Array[Dictionary] = []
	for i: int in (raw_pop as Array).size():
		var g: Variant = raw_pop[i]
		if not g is Dictionary:
			return {"error": "genome %d is not a dictionary" % i}
		# A save from before ferocity has no such key: it loads as neutral (5), see below.
		var legacy: bool = not g.has("ferocity")
		for gene: StringName in Genome.STAT_GENES + Genome.BEHAVIOUR_GENES:
			if legacy and gene == &"ferocity":
				continue
			if not _is_number(g.get(String(gene))):
				return {"error": "genome %d: gene %s missing or not a number" % [i, gene]}
		g = g.duplicate()
		for gene: StringName in Genome.TERRAIN_GENES:
			# Absent = an older save (loads as 0). Present but unreadable: 0, not a crash.
			if g.has(String(gene)) and not _is_number(g[String(gene)]):
				warnings.append("genome %d: terrain gene %s is not a number; using 0" % [i, gene])
				g[String(gene)] = 0.0
		var genome: Genome = Genome.from_dict(g)
		if legacy and genome.is_valid(rules, budget):
			pass  # old genome + neutral ferocity fits the budget: keep its stats exactly as they were
		elif not genome.is_valid(rules, budget) or not genome.spends_budget(rules, budget):
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

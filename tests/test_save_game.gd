extends GutTest
## Tests for SaveGame (capture + validation) and the SaveSystem file round trip.

var _rules: GenomeRules
var _rng: RandomNumberGenerator


func before_each() -> void:
	_rules = GenomeRules.new()
	_rng = RandomNumberGenerator.new()
	_rng.seed = 99


## A good save: wave 4 of the prototype loop, generation 3, 20 genomes.
func _good_save() -> Dictionary:
	var pop: Array[Dictionary] = []
	for i: int in 20:
		pop.append(Genome.random(_rng, _rules, _rules.budget_for_wave(4)).to_dict())
	var evolution: Dictionary = {
		"next_wave": 4, "generation": 3, "population": pop,
		"history": [{"from_wave": 1, "best_fitness": 0.15, "mean_fitness": 0.12}],
		"ga_seed": "123", "ga_rng_state": "9223372036854775807", "spawn_rng_state": "-5",
	}
	return SaveGame.capture(evolution)


## Simulates writing to disk and reading back: all ints become floats.
func _through_json(d: Dictionary) -> Dictionary:
	return JSON.parse_string(JSON.stringify(d))


func _validate(d: Variant) -> Dictionary:
	return SaveGame.validate(d, _rules)


func test_round_trip_through_json_is_clean() -> void:
	var r: Dictionary = _validate(_through_json(_good_save()))
	assert_true(r["ok"], r["error"])
	assert_eq(r["warnings"].size(), 0, str(r["warnings"]))
	assert_false(r["data"].has("player"), "XP and skills are gone from the validated save")
	var e: Dictionary = r["data"]["evolution"]
	assert_eq(e["next_wave"], 4)
	assert_eq(e["generation"], 3)
	assert_eq(e["population"].size(), 20)


func test_big_rng_state_survives_json_exactly() -> void:
	var e: Dictionary = _validate(_through_json(_good_save()))["data"]["evolution"]
	assert_eq(e["ga_rng_state"].to_int(), 9223372036854775807)
	assert_eq(e["spawn_rng_state"].to_int(), -5)


func test_genomes_survive_round_trip() -> void:
	var save: Dictionary = _good_save()
	var e: Dictionary = _validate(_through_json(save))["data"]["evolution"]
	for i: int in 20:
		var a: Genome = Genome.from_dict(save["evolution"]["population"][i])
		var b: Genome = Genome.from_dict(e["population"][i])
		assert_eq(a.describe(), b.describe())


func test_not_a_dictionary() -> void:
	assert_false(_validate([1, 2])["ok"])
	assert_false(_validate(null)["ok"])


func test_wrong_version_rejected() -> void:
	var d: Dictionary = _good_save()
	d["version"] = 99
	assert_false(_validate(d)["ok"])


func test_missing_section_rejected() -> void:
	var d: Dictionary = _good_save()
	d.erase("evolution")
	assert_false(_validate(d)["ok"])


func test_empty_population_rejected() -> void:
	var d: Dictionary = _good_save()
	d["evolution"]["population"] = []
	assert_false(_validate(d)["ok"])


func test_genome_missing_gene_rejected() -> void:
	var d: Dictionary = _good_save()
	d["evolution"]["population"][3].erase("speed")
	var r: Dictionary = _validate(d)
	assert_false(r["ok"])
	assert_string_contains(r["error"], "genome 3")


func test_removed_genes_in_an_old_save_are_ignored() -> void:
	var d: Dictionary = _good_save()
	d["evolution"]["population"][0]["path_mode"] = "TELEPORT"
	d["evolution"]["population"][0]["caution"] = "junk"
	var r: Dictionary = _validate(d)
	assert_true(r["ok"], r["error"])
	var healed: Dictionary = r["data"]["evolution"]["population"][0]
	assert_false(healed.has("path_mode"))
	assert_false(healed.has("caution"))


func _old_genome(budget_wave: int) -> Dictionary:
	# A genome as saved before ferocity: 3 stats that spend the OLD budget (15 + wave - 1), caution, path_mode.
	var old_budget: float = 15.0 + (budget_wave - 1)
	return {"speed": old_budget / 3.0 + 1.0, "health": old_budget / 3.0, "vision": old_budget / 3.0 - 1.0,
		"aggression": 0.6, "caution": 0.5, "flanking": 0.4, "cohesion": 0.3, "patience": 0.7,
		"path_mode": "ASTAR"}


func test_old_save_without_ferocity_keeps_its_stats_exactly() -> void:
	var d: Dictionary = _good_save()
	d["evolution"]["next_wave"] = 4
	d["evolution"]["generation"] = 3
	var old: Array = []
	for i: int in 20:
		old.append(_old_genome(4))
	d["evolution"]["population"] = old
	var before: Genome = Genome.from_dict(old[0])
	var r: Dictionary = _validate(_through_json(d))
	assert_true(r["ok"], r["error"])
	assert_eq(Array(r["warnings"]).filter(func(w: String) -> bool: return w.begins_with("genome")).size(), 0,
			"a legacy genome that fits is not flagged or repaired")
	var g: Genome = Genome.from_dict(r["data"]["evolution"]["population"][0])
	assert_almost_eq(g.speed, before.speed, 0.0001, "stats preserved")
	assert_almost_eq(g.health, before.health, 0.0001)
	assert_almost_eq(g.vision, before.vision, 0.0001)
	assert_eq(g.ferocity, 5.0, "neutral ferocity: no boost, no nerf")
	assert_almost_eq(g.melee_dps_factor(_rules), 1.0, 0.0001)
	assert_eq(g.aggression, 0.6)
	assert_true(g.spends_budget(_rules, _rules.budget_for_wave(4)), "old wave-4 total + 5 = the new wave-4 budget")


func test_old_save_past_the_old_cap_is_not_inflated() -> void:
	# Wave 12: old total 24 (cap) + neutral ferocity 5 = 29, new budget 31. The genome fits (is a
	# ceiling for migration), so nothing is rescaled upward; the GA tops it up on the next generation.
	var d: Dictionary = _good_save()
	d["evolution"]["next_wave"] = 12
	d["evolution"]["generation"] = 11
	var old: Array = []
	for i: int in 20:
		old.append({"speed": 9.0, "health": 8.0, "vision": 7.0, "aggression": 0.5, "flanking": 0.5,
			"cohesion": 0.5, "patience": 0.5})
	d["evolution"]["population"] = old
	var r: Dictionary = _validate(_through_json(d))
	assert_true(r["ok"], r["error"])
	var g: Genome = Genome.from_dict(r["data"]["evolution"]["population"][0])
	assert_eq(g.speed, 9.0)
	assert_eq(g.ferocity, 5.0)


func test_new_save_with_ferocity_is_checked_like_any_stat() -> void:
	var d: Dictionary = _good_save()
	d["evolution"]["population"][2]["ferocity"] = "strong"
	var r: Dictionary = _validate(d)
	assert_false(r["ok"])
	assert_string_contains(r["error"], "ferocity")
	var d2: Dictionary = _good_save()
	d2["evolution"]["population"][0]["ferocity"] = 10.0
	d2["evolution"]["population"][0]["speed"] = 10.0
	var r2: Dictionary = _validate(d2)
	assert_true(r2["ok"])
	assert_true(Genome.from_dict(r2["data"]["evolution"]["population"][0]).spends_budget(_rules, _rules.budget_for_wave(4)),
			"an over-budget new genome is repaired")


func test_over_budget_genome_repaired() -> void:
	var d: Dictionary = _good_save()
	d["evolution"]["population"][0]["speed"] = 10.0
	d["evolution"]["population"][0]["health"] = 10.0
	d["evolution"]["population"][0]["vision"] = 10.0
	d["evolution"]["population"][0]["aggression"] = 7.0
	var r: Dictionary = _validate(d)
	assert_true(r["ok"])
	var g: Genome = Genome.from_dict(r["data"]["evolution"]["population"][0])
	assert_true(g.is_valid(_rules, _rules.budget_for_wave(4)))
	assert_eq(g.aggression, 1.0)


# --- Old saves with XP and skills (retired) -------------------------------------------------

func _old_player_section() -> Dictionary:
	return {"level": 9, "xp": 12, "total_xp": 1500, "skill_points": 3, "unlocked": ["rapid_fire", "thick_skin"]}


func test_old_save_with_xp_and_skills_still_loads_and_keeps_its_evolution() -> void:
	var d: Dictionary = _good_save()
	d["player"] = _old_player_section()
	var r: Dictionary = _validate(_through_json(d))
	assert_true(r["ok"], r["error"])
	assert_eq(r["data"]["evolution"]["next_wave"], 4)
	assert_eq(r["data"]["evolution"]["population"].size(), 20)
	assert_true(str(r["warnings"]).contains("no longer exist"), "the player is told once: %s" % str(r["warnings"]))
	assert_false(r["data"].has("player"))


func test_new_save_has_an_empty_player_section_and_no_warning() -> void:
	var d: Dictionary = _good_save()
	assert_eq(d["player"], {})
	assert_eq(_validate(_through_json(d))["warnings"].size(), 0)


func test_garbage_player_section_is_ignored() -> void:
	for junk: Variant in [null, "x", 5, [1, 2], {"level": "high", "unlocked": 3}]:
		var d: Dictionary = _good_save()
		d["player"] = junk
		assert_true(_validate(d)["ok"])
	var no_player: Dictionary = _good_save()
	no_player.erase("player")
	assert_true(_validate(no_player)["ok"], "the section is optional")


func test_generation_not_above_waves_played() -> void:
	var d: Dictionary = _good_save()
	d["evolution"]["generation"] = 40
	assert_eq(_validate(d)["data"]["evolution"]["generation"], 3)


func test_bad_rng_state_dropped_with_warning() -> void:
	var d: Dictionary = _good_save()
	d["evolution"]["ga_rng_state"] = 12.5
	var r: Dictionary = _validate(d)
	assert_true(r["ok"])
	assert_false(r["data"]["evolution"].has("ga_rng_state"))


func test_bad_history_entries_dropped() -> void:
	var d: Dictionary = _good_save()
	d["evolution"]["history"] = [{"from_wave": 1, "best_fitness": 0.2, "mean_fitness": 0.1}, "junk", {}]
	var r: Dictionary = _validate(d)
	assert_eq(r["data"]["evolution"]["history"].size(), 1)


func test_file_round_trip_and_broken_file() -> void:
	var save_system: Node = load("res://autoload/save_system.gd").new()
	var file_path: String = SaveSystem.resolve(SaveSystem.SAVE_PATH)  # the sandbox copy
	# Missing file is safe.
	save_system.delete_save()
	assert_false(save_system.has_save())
	assert_false(save_system.read_save()["ok"])
	# Write twice (second write replaces the first), read back.
	assert_eq(save_system.write_save({"version": 0}), OK)
	assert_eq(save_system.write_save(_good_save()), OK)
	var r: Dictionary = save_system.read_save()
	assert_true(r["ok"], r["error"])
	assert_true(_validate(r["data"])["ok"])
	assert_false(FileAccess.file_exists(file_path + ".tmp"), "temp file renamed away")
	# Garbage on disk is reported, not crashed on.
	var f: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
	f.store_string("{ not json")
	f.close()
	assert_false(save_system.read_save()["ok"])
	save_system.delete_save()
	save_system.free()

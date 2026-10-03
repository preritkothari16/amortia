extends GutTest
## Tests for SaveGame (capture + validation) and the SaveSystem file round trip.

var _settings: ProgressionSettings
var _tree: SkillTree
var _rules: GenomeRules
var _rng: RandomNumberGenerator


func before_each() -> void:
	_settings = ProgressionSettings.new()
	_tree = load("res://data/skill_tree.tres") as SkillTree
	_rules = GenomeRules.new()
	_rng = RandomNumberGenerator.new()
	_rng.seed = 99


## A good save: level 4 (3 points earned), Rapid Fire + Thick Skin bought (2), 1 left.
func _good_save() -> Dictionary:
	var progression: PlayerProgression = PlayerProgression.new(_settings)
	progression.add_xp(40 + 60 + 80 + 25)
	var skills: PlayerSkills = PlayerSkills.new(_tree, progression)
	skills.unlock(&"rapid_fire")
	skills.unlock(&"thick_skin")
	var pop: Array[Dictionary] = []
	for i: int in 20:
		pop.append(Genome.random(_rng, _rules, _rules.budget_for_wave(4)).to_dict())
	var evolution: Dictionary = {
		"next_wave": 4, "generation": 3, "population": pop,
		"history": [{"from_wave": 1, "best_fitness": 0.15, "mean_fitness": 0.12}],
		"ga_seed": "123", "ga_rng_state": "9223372036854775807", "spawn_rng_state": "-5",
	}
	return SaveGame.capture(progression, skills, evolution)


## Simulates writing to disk and reading back: all ints become floats.
func _through_json(d: Dictionary) -> Dictionary:
	return JSON.parse_string(JSON.stringify(d))


func _validate(d: Variant) -> Dictionary:
	return SaveGame.validate(d, _settings, _tree, _rules)


func test_round_trip_through_json_is_clean() -> void:
	var r: Dictionary = _validate(_through_json(_good_save()))
	assert_true(r["ok"], r["error"])
	assert_eq(r["warnings"].size(), 0, str(r["warnings"]))
	var p: Dictionary = r["data"]["player"]
	assert_eq(p["level"], 4)
	assert_eq(p["xp"], 25)
	assert_eq(p["skill_points"], 1)
	assert_eq(p["unlocked"], [&"rapid_fire", &"thick_skin"] as Array[StringName])
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
		assert_eq(a.path_mode, b.path_mode)


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


func test_unknown_path_mode_rejected() -> void:
	var d: Dictionary = _good_save()
	d["evolution"]["population"][0]["path_mode"] = "TELEPORT"
	assert_false(_validate(d)["ok"])


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


func test_level_and_xp_clamped() -> void:
	var d: Dictionary = _good_save()
	d["player"]["level"] = 500
	d["player"]["xp"] = 99999
	var r: Dictionary = _validate(d)
	assert_true(r["ok"])
	assert_eq(r["data"]["player"]["level"], 30)
	assert_eq(r["data"]["player"]["xp"], 0, "no XP at the cap")
	assert_gt(r["warnings"].size(), 0)


func test_negative_xp_clamped() -> void:
	var d: Dictionary = _good_save()
	d["player"]["xp"] = -10
	assert_eq(_validate(d)["data"]["player"]["xp"], 0)


func test_missing_numbers_use_fallbacks() -> void:
	var d: Dictionary = _good_save()
	d["player"] = {}
	var r: Dictionary = _validate(d)
	assert_true(r["ok"])
	assert_eq(r["data"]["player"]["level"], 1)
	assert_eq(r["data"]["player"]["skill_points"], 0)


func test_unknown_and_duplicate_skills_dropped() -> void:
	var d: Dictionary = _good_save()
	d["player"]["unlocked"] = ["rapid_fire", "laser_eyes", "rapid_fire", 7]
	var r: Dictionary = _validate(d)
	assert_eq(r["data"]["player"]["unlocked"], [&"rapid_fire"] as Array[StringName])
	assert_eq(r["data"]["player"]["skill_points"], 2, "3 earned - 1 spent")


func test_skill_without_prerequisite_dropped() -> void:
	var d: Dictionary = _good_save()
	d["player"]["unlocked"] = ["hollow_points"]
	var r: Dictionary = _validate(d)
	assert_eq(r["data"]["player"]["unlocked"].size(), 0)
	assert_eq(r["data"]["player"]["skill_points"], 3)


func test_skills_level_cannot_pay_for_are_dropped() -> void:
	var d: Dictionary = _good_save()
	d["player"]["level"] = 2  # 1 point earned
	d["player"]["xp"] = 0
	var r: Dictionary = _validate(d)
	assert_eq(r["data"]["player"]["unlocked"], [&"rapid_fire"] as Array[StringName])
	assert_eq(r["data"]["player"]["skill_points"], 0)


func test_edited_skill_points_corrected() -> void:
	var d: Dictionary = _good_save()
	d["player"]["skill_points"] = 50
	var r: Dictionary = _validate(d)
	assert_eq(r["data"]["player"]["skill_points"], 1)
	assert_gt(r["warnings"].size(), 0)


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
	var backup: String = ""
	if save_system.has_save():
		backup = FileAccess.get_file_as_string(save_system.SAVE_PATH)
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
	assert_false(FileAccess.file_exists(save_system.TEMP_PATH), "temp file renamed away")
	# Garbage on disk is reported, not crashed on.
	var f: FileAccess = FileAccess.open(save_system.SAVE_PATH, FileAccess.WRITE)
	f.store_string("{ not json")
	f.close()
	assert_false(save_system.read_save()["ok"])
	# Restore whatever was there before the test.
	save_system.delete_save()
	if backup != "":
		f = FileAccess.open(save_system.SAVE_PATH, FileAccess.WRITE)
		f.store_string(backup)
		f.close()
	save_system.free()

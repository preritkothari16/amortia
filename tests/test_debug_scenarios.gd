extends GutTest
## Test scenarios (main menu -> Test Scenarios): GameState is put right before a campaign
## moment, test mode never writes the campaign save, and a level can start at its last wave.
## The real user://campaign.json is backed up and restored around these tests.

var _backup: String = ""
var _had_save: bool = false


func before_all() -> void:
	_had_save = FileAccess.file_exists(SaveSystem.CAMPAIGN_PATH)
	if _had_save:
		_backup = FileAccess.get_file_as_string(SaveSystem.CAMPAIGN_PATH)


func after_all() -> void:
	if _had_save:
		var f: FileAccess = FileAccess.open(SaveSystem.CAMPAIGN_PATH, FileAccess.WRITE)
		f.store_string(_backup)
		f.close()
	else:
		SaveSystem.delete_save(SaveSystem.CAMPAIGN_PATH)


func after_each() -> void:
	GameState.end_test_mode()
	GameState.leave_campaign()
	GameState.current_zone = 1
	get_tree().paused = false


func test_level_end_scenario_starts_at_the_last_wave() -> void:
	DebugScenarios.prepare(1, 0, true)
	assert_true(GameState.test_mode)
	assert_true(GameState.campaign_active)
	assert_eq(GameState.current_level().id, "z1_l1")
	assert_eq(GameState.pending_start_wave, GameState.current_level().waves - 1)
	assert_eq(GameState.player_data["level"], 1, "zone 1: a fresh player")


func test_every_menu_scenario_prepares() -> void:
	for scenario: Dictionary in DebugScenarios.SCENARIOS:
		var safehouse: bool = DebugScenarios.prepare_scenario(scenario)
		assert_eq(safehouse, scenario["scene"] != "level", scenario["text"])
		assert_eq(GameState.current_zone, scenario["zone"], scenario["text"])
		assert_eq(GameState.level_index, scenario["level"], scenario["text"])
		assert_not_null(GameState.current_level(), scenario["text"])
	DebugScenarios.prepare_scenario(DebugScenarios.SCENARIOS[2])
	assert_eq(GameState.safehouse_mode, "zone")
	assert_false(GameState.campaign_won)


func test_later_zone_is_reached_through_the_real_zone_transition() -> void:
	DebugScenarios.prepare(3, 0, false)
	assert_eq(GameState.current_zone, 3)
	assert_eq(GameState.current_level().id, "z3_l1")
	assert_eq(GameState.pending_start_wave, 0)
	var size: int = (load("res://data/ga.tres") as GASettings).population_size
	assert_eq((GameState.zone_evolution[3]["population"] as Array).size(), size, "seeded population for zone 3")
	assert_eq(GameState.zone_evolution[3]["generation"], 0)
	for z: int in [1, 2, 3]:
		assert_true(GameState.zone_best.has(z), "zone %d has a best genome (Apex boss)" % z)
	assert_eq(GameState.player_data["level"], 1 + 2 * DebugScenarios.PLAYER_LEVELS_PER_ZONE)
	assert_eq(GameState.player_data["skill_points"], 2 * DebugScenarios.PLAYER_LEVELS_PER_ZONE)


func test_seed_scenario_has_a_run_best_genome() -> void:
	DebugScenarios.prepare(4, 3, false)
	assert_true(GameState.is_apex_level())
	assert_true(GameState.current_level().objective.boss_uses_run_best)
	assert_not_null(GameState.run_best_genome())


func test_prepare_is_deterministic() -> void:
	DebugScenarios.prepare(2, 1, false)
	var a: Dictionary = GameState.zone_evolution[2].duplicate(true)
	DebugScenarios.prepare(2, 1, false)
	assert_eq(GameState.zone_evolution[2], a)


func test_player_data_passes_save_validation() -> void:
	var settings: ProgressionSettings = load("res://data/progression.tres")
	var warnings: PackedStringArray = PackedStringArray()
	var tree: SkillTree = load("res://data/skill_tree.tres")
	var p: Dictionary = DebugScenarios.player_for_zone(4)
	SaveGame._validate_player(p, settings, tree, warnings)
	assert_eq(warnings.size(), 0, ", ".join(warnings))


func test_test_mode_never_writes_the_campaign_save() -> void:
	SaveSystem.delete_save(SaveSystem.CAMPAIGN_PATH)
	DebugScenarios.prepare(2, 0, false)  # runs enter_next_zone(), which saves
	assert_eq(GameState.save_campaign(), OK)
	assert_eq(GameState.finish_level({}, {}), "level")
	assert_false(FileAccess.file_exists(SaveSystem.CAMPAIGN_PATH))


func test_end_test_mode_forgets_the_test_and_reloads_the_save() -> void:
	GameState.start_new_campaign()
	GameState.level_index = 2
	GameState.save_campaign()
	assert_true(DebugScenarios.prepare_scenario(DebugScenarios.SCENARIOS[4]), "victory opens the Safehouse")
	assert_true(GameState.campaign_won)
	assert_eq(GameState.safehouse_mode, "victory")
	GameState.end_test_mode()
	assert_false(GameState.test_mode)
	assert_false(GameState.campaign_won)
	assert_false(GameState.ng_plus_unlocked)
	assert_eq(GameState.level_index, 2, "real save reloaded")
	assert_eq(GameState.current_zone, 1)


func test_level_can_start_at_its_last_wave() -> void:
	DebugScenarios.prepare(1, 0, true)
	GameState.pending_level = GameState.current_level()
	var main: Node = load("res://world/main.tscn").instantiate()
	main.autosave = false
	var wm: WaveManager = main.get_node("WaveManager")
	wm.log_waves = false
	add_child_autofree(main)
	await wait_physics_frames(2)
	var waves: int = main.level_config.waves
	assert_eq(main.start_wave, waves - 1)
	assert_eq(main.level_flow.waves_done, waves - 1)
	assert_eq(main.level_flow.area_index, waves - 1)
	assert_eq(GameState.pending_start_wave, 0, "used once")
	assert_true(main.level_flow.status_text().begins_with("Wave %d / %d" % [waves, waves]))

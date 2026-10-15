extends GutTest
## Expansion phase 8: campaign data (16 levels), GameState campaign flow (levels, Safehouse,
## zone transitions with 20 % elite carry-over, victory and unlocks), the campaign save slot,
## side objectives, and the level hooks in main.gd. The real user://campaign.json is backed up
## and restored around these tests.

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
	GameState.leave_campaign()
	GameState.start_new_campaign()
	GameState.campaign_active = false
	GameState.campaign_won = false
	GameState.endless_unlocked = false
	GameState.ng_plus_unlocked = false
	GameState.ng_plus = false
	GameState.endless_mode = false
	GameState.current_zone = 1
	get_tree().paused = false


# --- Data ------------------------------------------------------------------------------

func test_campaign_has_four_zones_of_three_levels_and_an_apex() -> void:
	var c: CampaignConfig = GameState.campaign()
	assert_eq(c.zones.size(), 4)
	assert_eq(c.level_count(), 16)
	var types: Dictionary = {}
	for z: int in 4:
		var zone: ZoneConfig = c.zones[z]
		assert_eq(zone.zone, z + 1)
		assert_eq(zone.levels.size(), 4)
		for n: int in 4:
			var level: LevelConfig = zone.levels[n]
			assert_eq(level.zone, z + 1, level.id)
			assert_true(level.has_areas(), level.id)
			assert_not_null(level.objective, level.id)
			types[level.objective.type] = true
			assert_eq(level.objective.type == ObjectiveConfig.Type.APEX, n == 3, "%s: Apex last" % level.id)
			assert_eq(level.side_objectives.size(), 1)
	assert_eq(types.size(), 7, "all seven objective types appear")
	var total: int = 0
	for zone: ZoneConfig in c.zones:
		for n: int in zone.levels.size():
			assert_eq(zone.levels[n].waves, 2 if n == 0 else 1, "%s waves" % zone.levels[n].id)
			total += zone.levels[n].waves
	assert_eq(total, 20, "campaign length (halved from 37)")
	assert_true(c.get_level(4, 3).objective.boss_uses_run_best, "the Seed uses the run's best genome")
	assert_eq(c.zones[0].title, "Maple Hollow")
	assert_eq(c.zones[3].title, "Sunnyseed Labs")


func test_every_campaign_level_builds_its_first_area() -> void:
	for zone: ZoneConfig in GameState.campaign().zones:
		for level: LevelConfig in zone.levels:
			var scene: PackedScene = level.area_scene(0)
			assert_not_null(scene, level.id)
			if scene != null:
				var map: ZoneMap = scene.instantiate()
				assert_gt(map.get_enemy_spawns().size(), 0, level.id)
				map.free()


# --- Flow ------------------------------------------------------------------------------

func _evolution(size: int) -> Dictionary:
	var rules: GenomeRules = load("res://data/genome_rules.tres")
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 4
	var pop: Array = []
	for i: int in size:
		pop.append(Genome.random(rng, rules, rules.budget_for_wave(4)).to_dict())
	return {"next_wave": 4, "generation": 3, "population": pop, "history": []}


func test_campaign_walks_through_levels_safehouse_and_zones() -> void:
	GameState.start_new_campaign()
	assert_eq(GameState.current_level().id, "z1_l1")
	for n: int in 3:
		assert_eq(GameState.finish_level(_evolution(20), {}), "level")
	assert_eq(GameState.current_level().id, "z1_l4")
	assert_true(GameState.is_apex_level())
	# Elite of the zone (top 20 % of a wave), then the Apex.
	var results: Array[Dictionary] = []
	for i: int in 20:
		var g: Genome = Genome.new()
		g.speed = 10.0 - i * 0.2
		results.append({"genome": g, "fitness": 1.0 - i * 0.01})
	GameState.record_wave_best(results)
	assert_eq((GameState.zone_elite[1] as Array).size(), 4, "20 % of 20")
	assert_eq(GameState.finish_level(_evolution(20), {}), "safehouse")
	assert_eq(GameState.safehouse_mode, "zone")
	GameState.enter_next_zone()
	assert_eq(GameState.current_zone, 2)
	assert_eq(GameState.current_level().id, "z2_l1")
	var evo: Dictionary = GameState.zone_evolution[2]
	assert_eq(evo["next_wave"], 1, "new zone: budget starts again")
	assert_eq(evo["generation"], 0)
	assert_eq((evo["population"] as Array).size(), 20)
	var rules: GenomeRules = load("res://data/genome_rules.tres")
	var first: Genome = Genome.from_dict(evo["population"][0])
	assert_true(first.spends_budget(rules, rules.budget_for_wave(1)), "elites repaired to the new budget")
	assert_gt(first.speed, 6.0, "the best genome's proportions carried over")
	# Zones 2-4.
	for zone: int in [2, 3, 4]:
		for n: int in 3:
			GameState.finish_level(_evolution(20), {})
		var dest: String = GameState.finish_level(_evolution(20), {})
		if zone < 4:
			assert_eq(dest, "safehouse")
			GameState.enter_next_zone()
		else:
			assert_eq(dest, "victory")
	assert_true(GameState.campaign_won)
	assert_true(GameState.endless_unlocked)
	assert_true(GameState.ng_plus_unlocked)


func test_campaign_save_round_trip() -> void:
	GameState.start_new_campaign()
	GameState.finish_level(_evolution(20), {"level": 5, "xp": 3, "total_xp": 200, "skill_points": 4, "unlocked": []})
	GameState.zone_best = {1: {"fitness": 0.5, "genome": Genome.new().to_dict()}}
	GameState.scrap = 17
	assert_eq(GameState.save_campaign(), OK)
	# JSON turns ints into floats; compare both sides after one JSON round trip.
	var before: String = JSON.stringify(JSON.parse_string(JSON.stringify(GameState.to_dict())))
	GameState.start_new_campaign()
	assert_true(GameState.load_campaign())
	assert_eq(GameState.level_index, 1)
	assert_eq(GameState.scrap, 17)
	assert_true(GameState.zone_evolution.has(1), "int zone keys restored from JSON")
	assert_true(GameState.zone_best_genome(1) != null)
	assert_eq(JSON.stringify(JSON.parse_string(JSON.stringify(GameState.to_dict()))), before)


func test_campaign_save_is_separate_from_the_prototype_save() -> void:
	assert_ne(SaveSystem.CAMPAIGN_PATH, SaveSystem.SAVE_PATH)
	assert_false(GameState.from_dict({"version": 1, "player": {}, "evolution": {}}), "a prototype save is not a campaign")


func test_new_game_plus_keeps_xp_and_marks_the_run() -> void:
	GameState.player_data = {"level": 9}
	GameState.start_new_campaign(true)
	assert_true(GameState.ng_plus)
	assert_eq(GameState.player_data, {"level": 9})
	assert_eq(GameState.level_index, 0)


# --- Side objectives -----------------------------------------------------------------------

func test_side_objective_challenges() -> void:
	var s: SideObjective = SideObjective.new()
	s.challenge = SideObjective.Challenge.NO_DAMAGE
	assert_true(s.is_met({"damage_taken": 0.0}))
	assert_false(s.is_met({"damage_taken": 3.0}))
	s.challenge = SideObjective.Challenge.UNDER_TIME
	s.time_limit_seconds = 100.0
	assert_true(s.is_met({"seconds": 99.0}))
	assert_false(s.is_met({"seconds": 101.0}))
	s.challenge = SideObjective.Challenge.NO_BARRICADES
	assert_true(s.is_met({"barricades_placed": 0}))
	assert_false(s.is_met({"barricades_placed": 2}))
	s.kind = SideObjective.Kind.RESCUE
	assert_false(s.is_met({}), "placeholder kinds never complete")


# --- In the level ---------------------------------------------------------------------------

func _campaign_level(ng_plus: bool = false) -> Dictionary:
	GameState.start_new_campaign(ng_plus)
	GameState.player_data = {"level": 4, "xp": 0, "total_xp": 180, "skill_points": 3, "unlocked": []}
	GameState.zone_evolution[1] = _evolution(20)
	GameState.pending_level = GameState.current_level()
	var main: Node = load("res://world/main.tscn").instantiate()
	main.autosave = false
	var wm: WaveManager = main.get_node("WaveManager")
	wm.log_waves = false
	add_child_autofree(main)
	await wait_physics_frames(2)
	return {"main": main, "wm": wm, "player": main.get_node("Player")}


func test_campaign_level_restores_xp_and_the_zone_population() -> void:
	var lvl: Dictionary = await _campaign_level()
	var main: Node = lvl["main"]
	var wm: WaveManager = lvl["wm"]
	assert_true(main.in_campaign)
	assert_eq(main.level_config.id, "z1_l1")
	assert_eq((lvl["player"] as Player).progression.level, 4, "XP carried between levels")
	assert_eq(wm.wave_number, 4, "the zone's wave count continues (budget ramp)")
	assert_eq(wm.generation, 3)
	assert_eq(wm.population[0].to_dict()["speed"], GameState.zone_evolution[1]["population"][0]["speed"])
	assert_true(main.get_node("HUD/GameOverScreen").allow_level_restart)


func test_new_game_plus_raises_the_mutation_rate() -> void:
	var lvl: Dictionary = await _campaign_level(true)
	var base: GASettings = load("res://data/ga.tres")
	assert_almost_eq(lvl["wm"].ga_settings.mutation_rate, base.mutation_rate * 2.0, 0.0001)
	assert_eq(base.mutation_rate, 0.1, "the shared ga.tres is untouched")


func test_level_flow_rewards_side_objectives_once() -> void:
	var lvl: Dictionary = await _campaign_level()
	var flow: LevelFlow = lvl["main"].level_flow
	var side: SideObjective = flow.config.side_objectives[0]
	flow.stats = {"damage_taken": 0.0, "seconds": 10.0, "barricades_placed": 0}
	var scrap: int = GameState.scrap
	flow._evaluate_side_objectives()
	flow._evaluate_side_objectives()
	assert_true(flow.side_completed.has(side.id))
	assert_eq(GameState.scrap, scrap + side.reward_scrap, "paid once")


func test_level_end_report_names_the_next_stop() -> void:
	var lvl: Dictionary = await _campaign_level()
	assert_eq(lvl["main"].next_destination_text(), "Next: " + GameState.campaign().get_level(1, 1).title)
	GameState.level_index = 3
	assert_eq(lvl["main"].next_destination_text(), "Next: Safehouse")
	GameState.current_zone = 4
	assert_eq(lvl["main"].next_destination_text(), "Next: The end")

extends GutTest
## Expansion phase 6: the objective framework and the seven objective types, driven by
## LevelFlow in the real level. Checks goals, failures (-> lost wave, Retry), HUD text and the
## objective fitness term O (credited to the responsible enemy, bounded by objective_cap).

const AREA: String = "res://world/zones/maple_hollow/areas/area_1.tscn"


func after_each() -> void:
	get_tree().paused = false


func _config(type: ObjectiveConfig.Type, waves: int = 1) -> LevelConfig:
	var c: LevelConfig = LevelConfig.new()
	c.id = "test_%d" % type
	c.areas = [load(AREA)]
	c.waves = waves
	c.spawn_delay_seconds = 0.1
	c.objective = ObjectiveConfig.new()
	c.objective.type = type
	return c


func _level(config: LevelConfig) -> Dictionary:
	var main: Node = load("res://world/main.tscn").instantiate()
	main.autosave = false
	main.level_config = config
	var wm: WaveManager = main.get_node("WaveManager")
	wm.spawn_seed = 11
	wm.log_waves = false
	add_child_autofree(main)
	await wait_physics_frames(12)  # opening delay over, enemies here
	var player: Player = main.get_node("Player")
	player.health = 100000.0
	return {"main": main, "wm": wm, "player": player, "objective": main.objective, "flow": main.level_flow}


func _freeze(wm: WaveManager) -> void:
	for e: Enemy in wm.alive:
		e.set_physics_process(false)


func test_factory_makes_every_type() -> void:
	var expected: Dictionary = {
		ObjectiveConfig.Type.SURVIVE: SurviveObjective, ObjectiveConfig.Type.HOLD: HoldObjective,
		ObjectiveConfig.Type.ESCORT: EscortObjective, ObjectiveConfig.Type.PURGE: PurgeObjective,
		ObjectiveConfig.Type.EXTRACT: ExtractObjective, ObjectiveConfig.Type.STEALTH: StealthObjective,
		ObjectiveConfig.Type.APEX: ApexObjective,
	}
	for type: int in expected:
		var c: ObjectiveConfig = ObjectiveConfig.new()
		c.type = type
		var o: Objective = ObjectiveFactory.create(c)
		assert_eq(o.get_script(), expected[type])
		o.free()


func test_objective_fitness_is_bounded() -> void:
	var f: Fitness = Fitness.new(load("res://data/fitness.tres"))
	var r: FitnessRecord = FitnessRecord.new()
	r.add_objective(10000.0)
	assert_eq(f.components(r, 30.0)[Fitness.O], 1.0)
	var weights: FitnessSettings = load("res://data/fitness.tres")
	assert_eq([weights.weight_damage, weights.weight_pressure, weights.weight_survival, weights.weight_objective],
			[0.4, 0.25, 0.15, 0.2], "master formula unchanged")


func test_survive_ends_on_kill_all() -> void:
	var lvl: Dictionary = await _level(_config(ObjectiveConfig.Type.SURVIVE))
	assert_eq(lvl["objective"].hud_text(), "Survive")
	for e: Enemy in lvl["wm"].alive.duplicate():
		e.take_damage(99999.0)
	await wait_physics_frames(2)
	assert_eq(lvl["flow"].phase, LevelFlow.Phase.CLEARED)


func test_hold_point_damage_credits_enemies_and_timer_ends_wave() -> void:
	var lvl: Dictionary = await _level(_config(ObjectiveConfig.Type.HOLD))
	var hold: HoldObjective = lvl["objective"]
	var wm: WaveManager = lvl["wm"]
	_freeze(wm)
	var raider: Enemy = wm.alive[0]
	raider.global_position = hold.point
	await wait_physics_frames(60)
	assert_lt(hold.point_health, hold.config.point_health, "the point takes damage")
	assert_almost_eq(raider.fitness_record.objective_score, hold.config.point_health - hold.point_health, 0.01,
			"O credited to the enemy that did it")
	assert_string_contains(hold.hud_text(), "Hold the point")
	for e: Enemy in wm.alive.slice(1):
		e.take_damage(99999.0)
	await wait_physics_frames(2)
	assert_true(wm.is_wave_running(), "killing everyone doesn't end a hold wave")
	hold.hold_left = 0.05
	await wait_physics_frames(5)
	assert_false(wm.is_wave_running())
	assert_eq(lvl["flow"].phase, LevelFlow.Phase.CLEARED)


func test_hold_point_lost_fails_the_wave() -> void:
	var lvl: Dictionary = await _level(_config(ObjectiveConfig.Type.HOLD))
	var hold: HoldObjective = lvl["objective"]
	_freeze(lvl["wm"])
	hold.point_health = 0.5
	lvl["wm"].alive[0].global_position = hold.point
	await wait_physics_frames(30)
	assert_true(lvl["wm"].failed, "point lost = wave lost -> Retry")
	assert_true(lvl["main"].get_node("HUD/GameOverScreen").visible)


func test_escort_walks_with_the_player_and_can_die() -> void:
	var lvl: Dictionary = await _level(_config(ObjectiveConfig.Type.ESCORT))
	var escort: EscortObjective = lvl["objective"]
	var wm: WaveManager = lvl["wm"]
	var player: Player = lvl["player"]
	_freeze(wm)
	var start: Vector2 = escort.survivor
	await wait_physics_frames(60)
	assert_gt(escort.survivor.distance_to(start), 10.0, "walks while the player is close")
	player.global_position = lvl["main"].current_map().get_exit()
	await wait_physics_frames(3)
	assert_true(wm.is_wave_running(), "the player leaving alone completes nothing")
	var stuck: Vector2 = escort.survivor
	await wait_physics_frames(30)
	assert_eq(escort.survivor, stuck, "waits for the player")
	var biter: Enemy = wm.alive[0]
	biter.global_position = escort.survivor
	await wait_physics_frames(3)
	assert_eq(biter.fitness_record.objective_score, escort.config.escort_hit_damage, "O = damage to the survivor")
	escort.survivor_health = 1.0
	await wait_physics_frames(int(biter.stats.attack_cooldown * 60) + 5)
	assert_true(wm.failed, "survivor dead = wave lost")


func test_escort_reaching_the_exit_completes() -> void:
	var lvl: Dictionary = await _level(_config(ObjectiveConfig.Type.ESCORT))
	var escort: EscortObjective = lvl["objective"]
	_freeze(lvl["wm"])
	escort._path_index = escort._path.size()
	await wait_physics_frames(2)
	assert_false(lvl["wm"].is_wave_running())
	assert_eq(lvl["flow"].phase, LevelFlow.Phase.CLEARED)


func test_purge_nests_spawn_stragglers_until_destroyed() -> void:
	var lvl: Dictionary = await _level(_config(ObjectiveConfig.Type.PURGE))
	var purge: PurgeObjective = lvl["objective"]
	var wm: WaveManager = lvl["wm"]
	assert_eq(purge.nests.size(), 3)
	purge.nests[0]._spawn_left = 0.01
	var before: int = wm.alive.size()
	await wait_physics_frames(3)
	assert_eq(wm.alive.size(), before + 1, "a nest spawned a straggler")
	assert_null(wm.alive[-1].fitness_record, "not scored")
	for e: Enemy in wm.alive.duplicate():
		e.take_damage(99999.0)
	await wait_physics_frames(2)
	assert_true(wm.is_wave_running(), "nests still alive")
	for n: Nest in purge.nests.duplicate():
		n.take_damage(99999.0)
	await wait_physics_frames(2)
	assert_false(wm.is_wave_running())
	assert_eq(lvl["flow"].phase, LevelFlow.Phase.CLEARED)


func test_extract_supplies_make_noise_and_complete() -> void:
	var lvl: Dictionary = await _level(_config(ObjectiveConfig.Type.EXTRACT))
	var extract: ExtractObjective = lvl["objective"]
	var player: Player = lvl["player"]
	_freeze(lvl["wm"])
	assert_eq(extract.supplies.size(), 4)
	var noises: Array[float] = []
	var listen: Callable = func(_p: Vector2, r: float) -> void: noises.append(r)
	EventBus.noise_emitted.connect(listen)
	for s: Pickup in extract.supplies.duplicate():
		player.global_position = s.global_position
		await wait_physics_frames(3)
	EventBus.noise_emitted.disconnect(listen)
	assert_eq(extract.collected, 4)
	assert_true(noises.has(extract.config.loot_noise_radius), "looting is loud")
	assert_false(lvl["wm"].is_wave_running())


func test_stealth_alarm_fails_and_exit_completes() -> void:
	var lvl: Dictionary = await _level(_config(ObjectiveConfig.Type.STEALTH))
	var stealth: StealthObjective = lvl["objective"]
	var wm: WaveManager = lvl["wm"]
	assert_false(wm.alert_on_spawn, "no spawn Pulse in stealth")
	for g: Vector2i in lvl["main"].current_map().get_gate_cells():
		assert_eq(lvl["main"].terrain_grid.get_terrain(g), "road", "exit open from the start")
	var watcher: Enemy = wm.alive[0]
	watcher.global_position = lvl["player"].global_position + Vector2(20, 0)
	await wait_physics_frames(3)
	assert_eq(stealth.alarms, 1)
	assert_eq(watcher.fitness_record.objective_score, stealth.config.alarm_points)
	assert_true(wm.failed)


func test_stealth_reaching_the_exit_completes() -> void:
	var c: LevelConfig = _config(ObjectiveConfig.Type.STEALTH)
	c.objective.alarms_allowed = 99
	var lvl: Dictionary = await _level(c)
	lvl["player"].global_position = lvl["main"].current_map().get_exit()
	await wait_physics_frames(2)
	assert_false(lvl["wm"].is_wave_running())
	assert_eq(lvl["flow"].phase, LevelFlow.Phase.COMPLETE, "1-wave level done")
	assert_true(lvl["main"].get_node("HUD/WaveReport").visible, "report before the next level")


func test_apex_boss_from_the_zone_best_genome() -> void:
	var best: Genome = Genome.new()
	best.speed = 9.0
	best.health = 3.0
	best.vision = 3.0
	GameState.zone_best = {1: {"fitness": 0.9, "genome": best.to_dict()}}
	GameState.current_zone = 1
	var lvl: Dictionary = await _level(_config(ObjectiveConfig.Type.APEX))
	var apex: ApexObjective = lvl["objective"]
	await wait_physics_frames(2)
	assert_not_null(apex.boss)
	assert_true(apex.boss.is_boss)
	assert_eq(apex.boss.genome.speed, 9.0, "built from the zone's best genome")
	assert_null(apex.boss.fitness_record, "not part of the GA")
	assert_almost_eq(apex.boss.stats.max_health,
			best.max_health(30.0, load("res://data/genome_rules.tres")) * apex.config.boss_health_multiplier, 0.01)
	apex.boss.take_damage(999999.0)
	await wait_physics_frames(2)
	assert_false(lvl["wm"].is_wave_running())
	GameState.zone_best = {}


func test_zone_best_tracks_the_fittest_genome() -> void:
	GameState.zone_best = {}
	var g: Genome = Genome.new()
	var r: Array[Dictionary] = [{"genome": g, "fitness": 0.3}]
	GameState.record_wave_best(r)
	var worse: Array[Dictionary] = [{"genome": Genome.new(), "fitness": 0.1}]
	GameState.record_wave_best(worse)
	assert_eq(GameState.zone_best[1]["fitness"], 0.3)
	GameState.zone_best = {}

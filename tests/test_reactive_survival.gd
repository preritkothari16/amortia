extends GutTest
## Reactive Survival V1: vision cone + suspicion (Perception, Awareness), the noise-maker,
## survivor commands, threat-aware survivor routes (SafePath), recovery (Stealth SPOTTED
## countdown) and the generated-map fairness check (ObjectiveFairness).
## V2 rule changes are asserted here where V1 tested the old rule (escort death, second alarm);
## the new V2 mechanics live in test_reactive_survival_v2.gd and test_cover_finder.gd.
## Pure rules first, then scenarios in the real level (real time, like test_enemy_tactics).

const AREA: String = "res://world/zones/maple_hollow/areas/area_1.tscn"

var _p: PerceptionSettings
var _rules: TerrainCosts


func before_each() -> void:
	_p = load("res://data/perception.tres")
	_rules = load("res://data/terrain_costs.tres")


func after_each() -> void:
	get_tree().paused = false


## Grid from strings: . grass, # wall, * tall grass, ~ deep water, G gate.
func _grid(lines: Array[String]) -> TerrainGrid:
	var names: Dictionary = {".": "grass", "#": "wall", "*": "tall_grass", "~": "deep_water", "G": "gate"}
	var rows: Array[PackedStringArray] = []
	for line: String in lines:
		var row: PackedStringArray = PackedStringArray()
		for ch: String in line:
			row.append(names[ch])
		rows.append(row)
	return TerrainGrid.from_rows(rows, _rules)


# --- Vision cone and suspicion (pure) ------------------------------------------------------

func test_view_cone() -> void:
	assert_true(Perception.in_view_cone(Vector2(10, 0), Vector2.RIGHT, 120.0), "straight ahead")
	assert_true(Perception.in_view_cone(Vector2(10, 5.7), Vector2.RIGHT, 120.0), "30 degrees off: inside")
	assert_false(Perception.in_view_cone(Vector2(0, 10), Vector2.RIGHT, 120.0), "90 degrees off: outside")
	assert_false(Perception.in_view_cone(Vector2(-10, 0), Vector2.RIGHT, 120.0), "behind")
	assert_true(Perception.in_view_cone(Vector2(-10, 0), Vector2.RIGHT, 360.0), "360 = all round")
	assert_true(Perception.in_view_cone(Vector2(-10, 0), Vector2.ZERO, 120.0), "no facing yet: no free blind spot")


func test_suspicion_fills_faster_up_close_and_when_alert() -> void:
	var near: float = Perception.suspicion_rate(32.0, 32.0, 160.0, false, _p)
	var far: float = Perception.suspicion_rate(160.0, 32.0, 160.0, false, _p)
	assert_almost_eq(near, 1.0 / _p.suspicion_fill_near, 0.001)
	assert_almost_eq(far, 1.0 / _p.suspicion_fill_far, 0.001)
	assert_gt(near, far)
	var alert: float = Perception.suspicion_rate(160.0, 32.0, 160.0, true, _p)
	assert_almost_eq(alert, far * _p.suspicion_alert_multiplier, 0.001)


func test_scan_facing_sweeps_around_the_rest_direction() -> void:
	var widest: float = 0.0
	for i: int in 50:
		var f: Vector2 = Perception.scan_facing(Vector2.RIGHT, i * 0.1, 60.0, 5.0)
		widest = maxf(widest, absf(Vector2.RIGHT.angle_to(f)))
	assert_almost_eq(rad_to_deg(widest), 30.0, 1.0, "60 degrees in total = 30 each side")


func test_suspicion_builds_up_before_the_alarm() -> void:
	var a: Awareness = Awareness.new()
	for i: int in 30:  # 0.5 s at 1 per second
		a.notice(Vector2(50, 0), 1.0, 1.0 / 60.0, 0.5)
	assert_ne(a.state, Awareness.State.CHASE, "half sure is no alarm")
	assert_almost_eq(a.suspicion, 0.5, 0.02)
	for i: int in 31:
		a.notice(Vector2(50, 0), 1.0, 1.0 / 60.0, 0.5)
	assert_eq(a.state, Awareness.State.CHASE, "full = it sees you")
	assert_eq(a.last_known, Vector2(50, 0))


func test_half_suspicion_sends_the_enemy_to_check_the_glimpse_spot() -> void:
	var a: Awareness = Awareness.new()
	for i: int in 20:
		a.notice(Vector2(70, 10), 1.0, 1.0 / 60.0, 0.5)
	assert_eq(a.state, Awareness.State.IDLE, "a faint glimpse: nothing yet")
	for i: int in 12:
		a.notice(Vector2(70, 10), 1.0, 1.0 / 60.0, 0.5)
	assert_eq(a.state, Awareness.State.INVESTIGATE, "past the threshold: goes to look")
	assert_eq(a.last_known, Vector2(70, 10), "at the glimpse spot")
	assert_between(a.lead_strength, 0.5, 0.52, "as strong as it was sure when it decided to look")


func test_suspicion_drains_out_of_view_and_a_chase_can_be_broken() -> void:
	var a: Awareness = Awareness.new()
	for i: int in 20:
		a.notice(Vector2(10, 0), 1.0, 1.0 / 60.0, 0.5)
	var s: float = a.suspicion
	a.unnoticed(0.2, 1.0, 0.5)
	assert_almost_eq(a.suspicion, s - 0.1, 0.001, "decays at decay_per_second")
	a.see(Vector2(30, 0))
	assert_eq(a.state, Awareness.State.CHASE)
	a.unnoticed(1.0 / 60.0, 1.0, 0.5)
	assert_eq(a.state, Awareness.State.INVESTIGATE, "line of sight broken: back to a lead")
	assert_eq(a.last_known, Vector2(30, 0), "where it last saw you, no tracking")


# --- Scenarios in the level ----------------------------------------------------------------

func _arena() -> Dictionary:
	var main: Node = load("res://world/main.tscn").instantiate()
	main.autosave = false
	main.deterministic_ai = true
	var wm: WaveManager = main.get_node("WaveManager")
	wm.auto_start = false
	wm.alert_on_spawn = false
	wm.spawn_scatter_tiles = 0
	wm.spawn_seed = 7
	wm.log_waves = false
	add_child_autofree(main)
	await wait_physics_frames(3)
	var player: Player = main.get_node("Player")
	player.health = 1.0e9
	return {"main": main, "wm": wm, "player": player}


func _open_direction(main: Node, origin: Vector2, dists: Array) -> Vector2:
	var grid: TerrainGrid = main.terrain_grid
	for k: int in 72:
		var dir: Vector2 = Vector2.from_angle(TAU * k / 72.0)
		var ok: bool = true
		for d: float in dists:
			var p: Vector2 = origin + dir * d
			if not grid.is_walkable(grid.coords.world_to_cell(p)) or not grid.has_line_of_sight(p, origin):
				ok = false
				break
		if ok:
			return dir
	return Vector2.ZERO


func _watcher(wm: WaveManager, at: Vector2, look_at: Vector2, patience: float = 0.0) -> Enemy:
	var g: Genome = Genome.new()  # vision 5 -> 160 px
	g.aggression = 0.0
	g.patience = patience
	var e: Enemy = wm.spawn_enemy(at, g)
	e.global_position = at
	e.velocity = Vector2.ZERO
	e.rest_facing = at.direction_to(look_at)
	e.facing = e.rest_facing
	return e


func test_enemy_behind_you_does_not_see_you_but_one_facing_you_does_after_a_moment() -> void:
	var arena: Dictionary = await _arena()
	var player: Player = arena["player"]
	var wm: WaveManager = arena["wm"]
	var dir: Vector2 = _open_direction(arena["main"], player.global_position, [100.0])
	assert_ne(dir, Vector2.ZERO)
	var at: Vector2 = player.global_position + dir * 100.0
	var away: Enemy = _watcher(wm, at, at + dir * 50.0)  # looks away from the player
	await wait_physics_frames(60)
	assert_eq(away.awareness.suspicion, 0.0, "outside its cone: nothing")
	assert_ne(away.awareness.state, Awareness.State.CHASE)
	away.rest_facing = -dir
	away.facing = -dir
	await wait_physics_frames(15)
	assert_gt(away.awareness.suspicion, 0.0, "facing you: suspicion rises")
	assert_ne(away.awareness.state, Awareness.State.CHASE, "...but not at once (warning time)")
	await wait_physics_frames(80)
	assert_eq(away.awareness.state, Awareness.State.CHASE, "kept in view: it sees you")


func test_breaking_line_of_sight_escapes_detection() -> void:
	var arena: Dictionary = await _arena()
	var player: Player = arena["player"]
	var wm: WaveManager = arena["wm"]
	var dir: Vector2 = _open_direction(arena["main"], player.global_position, [120.0])
	var e: Enemy = _watcher(wm, player.global_position + dir * 120.0, player.global_position)
	await wait_physics_frames(30)
	var s: float = e.awareness.suspicion
	assert_gt(s, 0.1)
	assert_ne(e.awareness.state, Awareness.State.CHASE)
	player.global_position = Vector2(-500, -500)  # out of sight
	await wait_physics_frames(30)
	assert_lt(e.awareness.suspicion, s, "suspicion drains once you are out of view")
	assert_ne(e.awareness.state, Awareness.State.CHASE, "no alarm")


func test_noise_maker_lures_to_the_landing_spot_not_the_player() -> void:
	var arena: Dictionary = await _arena()
	var main: Node = arena["main"]
	var player: Player = arena["player"]
	var wm: WaveManager = arena["wm"]
	var grid: TerrainGrid = main.terrain_grid
	var dir: Vector2 = _open_direction(main, player.global_position, [40.0, 80.0, 120.0])
	assert_ne(dir, Vector2.ZERO)
	var listener: Enemy = _watcher(wm, player.global_position + dir * 230.0, player.global_position + dir * 400.0, 1.0)
	var deaf: Enemy = _watcher(wm, Vector2(grid.width * 16 - 40, 40), Vector2(grid.width * 16, 40), 1.0)
	assert_eq(player.noise_makers_left, player.noise_maker.count_per_area)
	var thrown: NoiseMaker = player.throw_noise_maker(player.global_position + dir * 120.0)
	assert_not_null(thrown)
	assert_eq(player.noise_makers_left, player.noise_maker.count_per_area - 1)
	var spot: Vector2 = thrown.to
	await wait_physics_frames(int(player.noise_maker.flight_time * 60) + 3)
	assert_true(thrown.has_landed)
	assert_eq(listener.awareness.state, Awareness.State.INVESTIGATE, "heard it")
	assert_eq(listener.awareness.last_known, spot, "goes to the landing spot")
	assert_ne(listener.awareness.last_known, player.global_position, "not to the player")
	assert_eq(deaf.awareness.state, Awareness.State.IDLE, "out of earshot: ignores it")
	await wait_physics_frames(60)
	assert_lt(listener.global_position.distance_to(spot), (player.global_position + dir * 230.0).distance_to(spot),
			"walked towards it")


## Endless / prototype loop (no campaign level): the count comes back every wave.
func test_noise_maker_count_runs_out_and_refills() -> void:
	var arena: Dictionary = await _arena()
	var player: Player = arena["player"]
	for i: int in player.noise_maker.count_per_area:
		assert_not_null(player.throw_noise_maker(player.global_position + Vector2(30, 0)))
	assert_null(player.throw_noise_maker(player.global_position + Vector2(30, 0)), "none left")
	player.refill_throwables()
	assert_eq(player.noise_makers_left, player.noise_maker.count_per_area, "a new wave / area refills")


func test_noise_maker_range_and_walls() -> void:
	var g: TerrainGrid = _grid(["..........", "..........", ".....#....", ".........."])
	var top: Vector2 = g.coords.cell_to_world(Vector2i(1, 0))
	var far: Vector2 = NoiseMaker.landing_point(g, top, top + Vector2(1000, 0), 64.0)
	assert_almost_eq(far.distance_to(top), 64.0, 0.01, "capped at max_range")
	var origin: Vector2 = g.coords.cell_to_world(Vector2i(1, 2))
	var short: Vector2 = NoiseMaker.landing_point(g, origin, g.coords.cell_to_world(Vector2i(8, 2)), 200.0)
	assert_lt(short.x, g.coords.cell_to_world(Vector2i(5, 2)).x - 4.0, "stops in front of the wall")


# --- Escort --------------------------------------------------------------------------------

func _escort_level(seed_value: int = 11) -> Dictionary:
	var c: LevelConfig = LevelConfig.new()
	c.id = "test_escort_v1"
	c.areas = [load(AREA)]
	c.waves = 1
	c.spawn_delay_seconds = 0.1
	c.objective = ObjectiveConfig.new()
	c.objective.type = ObjectiveConfig.Type.ESCORT
	var main: Node = load("res://world/main.tscn").instantiate()
	main.autosave = false
	main.level_config = c
	main.deterministic_ai = true
	var wm: WaveManager = main.get_node("WaveManager")
	wm.spawn_seed = seed_value
	wm.log_waves = false
	add_child_autofree(main)
	await wait_physics_frames(12)
	var player: Player = main.get_node("Player")
	player.health = 1.0e9
	return {"main": main, "wm": wm, "player": player, "escort": main.objective}


func _freeze_all(wm: WaveManager) -> void:
	for e: Enemy in wm.alive:
		e.set_physics_process(false)
		e.global_position = Vector2(-2000, -2000)


func test_follow_and_wait_commands() -> void:
	var lvl: Dictionary = await _escort_level()
	var escort: EscortObjective = lvl["escort"]
	var player: Player = lvl["player"]
	var grid: TerrainGrid = lvl["main"].terrain_grid
	_freeze_all(lvl["wm"])
	var route: Array[Vector2i] = escort.walk_path(grid.coords.world_to_cell(escort.survivor),
			grid.coords.world_to_cell(lvl["main"].current_map().get_exit()))
	escort.toggle_mode()
	assert_eq(escort.mode, EscortObjective.Mode.WAIT)
	assert_string_contains(escort.hud_text(), "WAITING")
	var start: Vector2 = escort.survivor
	player.global_position = grid.coords.cell_to_world(route[5])
	await wait_physics_frames(60)
	assert_eq(escort.survivor, start, "WAIT: stays put")
	escort.toggle_mode()
	assert_eq(escort.mode, EscortObjective.Mode.FOLLOW)
	await wait_physics_frames(90)
	assert_lt(escort.survivor.distance_to(player.global_position), escort.config.escort_follow_distance + 6.0,
			"FOLLOW: came up to the player")
	assert_gt(escort.survivor.distance_to(player.global_position), 4.0, "...and stopped short of it")
	var key: InputEventAction = InputEventAction.new()
	key.action = &"escort_command"
	key.pressed = true
	escort._unhandled_input(key)
	assert_eq(escort.mode, EscortObjective.Mode.WAIT, "the input action toggles it")


func test_safe_path_detours_around_threats_and_goes_through_when_it_must() -> void:
	var g: TerrainGrid = _grid([
		"..........",
		"..........",
		"..........",
		"..........",
		"..........",
	])
	var safe: SafePath = SafePath.new()
	var plain: Array[Vector2i] = safe.find(g, Vector2i(0, 2), Vector2i(9, 2), [])
	assert_eq(plain.size(), 10, "no threats: the shortest walk")
	var threat: Array[Vector2i] = [Vector2i(5, 2)]
	var around: Array[Vector2i] = safe.find(g, Vector2i(0, 2), Vector2i(9, 2), threat)
	assert_false(around.has(Vector2i(5, 2)), "does not walk through the enemy")
	var worst: float = 0.0
	for c: Vector2i in around:
		worst = maxf(worst, SafePath.danger(c, threat, safe.threat_radius_cells))
	assert_lt(worst, SafePath.danger(Vector2i(5, 2), threat, safe.threat_radius_cells), "keeps away from it")
	var corridor: TerrainGrid = _grid(["##########", "..........", "##########"])
	var forced: Array[Vector2i] = safe.find(corridor, Vector2i(0, 1), Vector2i(9, 1), [Vector2i(5, 1)])
	assert_eq(forced.size(), 10, "only one way: still goes (danger never blocks)")
	var walled: TerrainGrid = _grid(["....#....", "....~....", "....#...."])
	assert_eq(safe.find(walled, Vector2i(0, 1), Vector2i(8, 1), []), [] as Array[Vector2i], "water and walls: no route")
	var gated: TerrainGrid = _grid(["....G...."])
	assert_eq(safe.find(gated, Vector2i(0, 0), Vector2i(8, 0), []).size(), 9, "the exit gate counts as walkable")


func test_survivor_backs_away_from_a_close_enemy() -> void:
	var lvl: Dictionary = await _escort_level()
	var escort: EscortObjective = lvl["escort"]
	var wm: WaveManager = lvl["wm"]
	var player: Player = lvl["player"]
	_freeze_all(wm)
	escort.toggle_mode()  # WAIT: only the flee rule moves it
	var e: Enemy = wm.alive[0]
	var dir: Vector2 = _open_direction(lvl["main"], escort.survivor, [16.0, 32.0, 48.0])
	e.global_position = escort.survivor + dir * 24.0
	player.global_position = escort.survivor - dir * 60.0
	var before: float = escort.survivor.distance_to(e.global_position)
	await wait_physics_frames(20)
	assert_true(escort.scared or escort.survivor.distance_to(e.global_position) > escort.config.escort_flee_radius)
	assert_gt(escort.survivor.distance_to(e.global_position), before, "moved away from the enemy")


func test_survivor_death_fails_at_once() -> void:
	var lvl: Dictionary = await _escort_level()
	var escort: EscortObjective = lvl["escort"]
	var wm: WaveManager = lvl["wm"]
	_freeze_all(wm)
	escort.survivor_health = 0.0
	escort.tick(0.016)
	assert_eq(escort.state, Objective.State.FAILED, "0 HP = mission failed, no downed state, no revive")
	assert_true(wm.failed)
	assert_false(escort.is_survivor_alive())


func test_hunters_warning_shows_before_the_first_hit() -> void:
	var lvl: Dictionary = await _escort_level()
	var escort: EscortObjective = lvl["escort"]
	var wm: WaveManager = lvl["wm"]
	var player: Player = lvl["player"]
	_freeze_all(wm)
	player.global_position = lvl["main"].current_map().get_exit()
	var e: Enemy = wm.alive[0]
	var dir: Vector2 = _open_direction(lvl["main"], escort.survivor, [60.0, 90.0])
	e.global_position = escort.survivor + dir * 90.0
	e.rest_facing = -dir
	e.facing = -dir
	e.set_physics_process(true)
	var warned_first: bool = false
	var hp: float = escort.survivor_health
	for f: int in 240:
		await wait_physics_frames(1)
		if escort.survivor_health < hp:
			break
		if escort.hunters() > 0:
			warned_first = true
	assert_true(warned_first, "HUNTED shows while the enemy is still on its way")


# --- Recovery: Stealth ---------------------------------------------------------------------

func _stealth_level(seed_value: int) -> Dictionary:
	var c: LevelConfig = LevelConfig.new()
	c.id = "test_stealth_v1"
	c.areas = [load(AREA)]
	c.waves = 1
	c.spawn_delay_seconds = 0.1
	c.objective = ObjectiveConfig.new()
	c.objective.type = ObjectiveConfig.Type.STEALTH
	var main: Node = load("res://world/main.tscn").instantiate()
	main.autosave = false
	main.level_config = c
	main.deterministic_ai = true
	var wm: WaveManager = main.get_node("WaveManager")
	wm.spawn_seed = seed_value
	wm.log_waves = false
	add_child_autofree(main)
	await wait_physics_frames(12)
	var player: Player = main.get_node("Player")
	player.health = 1.0e9
	return {"main": main, "wm": wm, "player": player, "stealth": main.objective, "flow": main.level_flow}


func test_breaking_line_of_sight_during_the_countdown_is_a_close_call() -> void:
	var lvl: Dictionary = await _stealth_level(11)
	var stealth: StealthObjective = lvl["stealth"]
	var wm: WaveManager = lvl["wm"]
	var player: Player = lvl["player"]
	_freeze_all(wm)
	var spotter: Enemy = wm.alive[0]
	spotter.global_position = player.global_position + Vector2(20, 0)
	spotter.set_physics_process(true)
	await wait_physics_frames(3)
	assert_eq(stealth.alarms, 1)
	assert_gt(stealth.grace_left, 0.0, "SPOTTED countdown")
	spotter.take_damage(99999.0)  # shoot the spotter: nobody sees you any more
	await wait_physics_frames(int(stealth.config.alarm_grace_seconds * 60) + 5)
	assert_false(wm.failed, "escaped")
	assert_eq(stealth.escapes_used, 1)
	assert_string_contains(stealth.hud_text(), "close call")
	var second: Enemy = wm.alive[0]
	second.global_position = player.global_position + Vector2(20, 0)
	second.set_physics_process(true)
	await wait_physics_frames(3)
	assert_false(wm.failed, "V2: close calls are unlimited...")
	assert_between(stealth.grace_left, 0.0, stealth.config.alarm_grace_seconds - stealth.config.alarm_grace_step,
			"...but the next countdown is shorter")


func test_stealth_completes_under_several_seeds_when_unseen() -> void:
	for seed_value: int in [3, 11, 29]:
		var lvl: Dictionary = await _stealth_level(seed_value)
		var stealth: StealthObjective = lvl["stealth"]
		_freeze_all(lvl["wm"])
		lvl["player"].global_position = lvl["main"].current_map().get_exit()
		await wait_physics_frames(3)
		assert_eq(stealth.state, Objective.State.COMPLETED, "seed %d: unseen at the exit = done" % seed_value)
		assert_eq(stealth.alarms, 0, "seed %d" % seed_value)
		lvl["main"].free()
		get_tree().paused = false  # the finished level's Wave Report paused the tree
		await wait_physics_frames(2)


func test_escort_completes_under_several_seeds_by_following_the_player() -> void:
	for seed_value: int in [3, 11, 29]:
		var lvl: Dictionary = await _escort_level(seed_value)
		var escort: EscortObjective = lvl["escort"]
		var player: Player = lvl["player"]
		var grid: TerrainGrid = lvl["main"].terrain_grid
		_freeze_all(lvl["wm"])
		var route: Array[Vector2i] = escort.walk_path(grid.coords.world_to_cell(escort.survivor),
				grid.coords.world_to_cell(lvl["main"].current_map().get_exit()))
		assert_gt(route.size(), 10, "seed %d: a route exists" % seed_value)
		# The player walks the route a few tiles ahead; the survivor follows (FOLLOW, no enemies near).
		var i: int = 0
		for f: int in 3600:
			if escort.state != Objective.State.ACTIVE:
				break
			var ahead: int = mini(i + 4, route.size() - 1)
			player.global_position = grid.coords.cell_to_world(route[ahead])
			if escort.survivor.distance_to(player.global_position) < escort.config.escort_follow_distance + 4.0:
				i = mini(i + 1, route.size() - 1)
			await wait_physics_frames(1)
		assert_eq(escort.state, Objective.State.COMPLETED, "seed %d: the survivor reached the exit" % seed_value)
		lvl["main"].free()
		get_tree().paused = false  # the finished level's Wave Report paused the tree
		await wait_physics_frames(2)


# --- Fairness of generated objectives -------------------------------------------------------

func test_fairness_rejects_bad_maps() -> void:
	var fair: ObjectiveFairnessSettings = load("res://data/objective_fairness.tres")
	var open_field: TerrainGrid = _grid([
		"....................",
		"....................",
		"....................",
	])
	var bare: Dictionary = ObjectiveFairness.check(open_field, Vector2i(0, 1), Vector2i(19, 1), [], false, fair)
	assert_false(bare["ok"], "no cover anywhere")
	assert_eq(bare["cover_ratio"], 0.0)
	var cut: TerrainGrid = _grid(["....#....", "....~....", "....#...."])
	var unreachable: Dictionary = ObjectiveFairness.check(cut, Vector2i(0, 1), Vector2i(8, 1), [], false, fair)
	assert_false(unreachable["ok"])
	assert_true(unreachable["reasons"].has("exit unreachable"))
	var cover: TerrainGrid = _grid([
		"*.*.*.*.*.*.*.*.*.*.",
		"....................",
		"*.*.*.*.*.*.*.*.*.*.",
	])
	var spawns: Array[Vector2i] = [Vector2i(3, 0), Vector2i(7, 0), Vector2i(11, 0), Vector2i(15, 0), Vector2i(17, 2)]
	var watched: Dictionary = ObjectiveFairness.check(cover, Vector2i(0, 1), Vector2i(19, 1), spawns, true, fair)
	assert_gt(watched["cover_ratio"], 0.9)
	assert_false(watched["ok"], "five spawns watch the only route")
	assert_eq(watched["watching_spawns"], 5)
	var escort_ok: Dictionary = ObjectiveFairness.check(cover, Vector2i(0, 1), Vector2i(19, 1), spawns, false, fair)
	assert_true(escort_ok["ok"], "Escort only needs a route with cover")


func test_campaign_stealth_and_escort_areas_pass_the_fairness_check() -> void:
	var fair: ObjectiveFairnessSettings = load("res://data/objective_fairness.tres")
	var rules: TerrainCosts = load("res://data/terrain_costs.tres")
	for id: String in ["z1_l3", "z3_l1", "z4_l2"]:
		var lvl: LevelConfig = load("res://data/levels/%s.tres" % id)
		for area: int in lvl.waves:
			var scene: PackedScene = lvl.area_scene(area)
			assert_not_null(scene, "%s area %d generated" % [id, area])
			var map: ZoneMap = scene.instantiate()
			add_child(map)
			var grid: TerrainGrid = TerrainGrid.from_rows(map.get_terrain_rows(), rules)
			var spawns: Array[Vector2i] = []
			for p: Vector2 in map.get_enemy_spawns():
				spawns.append(Vector2i(p / 16.0))
			var r: Dictionary = ObjectiveFairness.check(grid, Vector2i(map.get_entry() / 16.0), Vector2i(map.get_exit() / 16.0),
					spawns, lvl.objective.type == ObjectiveConfig.Type.STEALTH, fair)
			assert_true(r["ok"], "%s area %d: %s" % [id, area, r])
			map.free()


func test_fairness_retries_are_deterministic() -> void:
	var settings: LevelGenSettings = load("res://data/levelgen/maple_hollow.tres")
	var a: PackedScene = GeneratedArea.build_scene(settings, 301, ObjectiveConfig.Type.STEALTH)
	var b: PackedScene = GeneratedArea.build_scene(settings, 301, ObjectiveConfig.Type.STEALTH)
	var ma: ZoneMap = a.instantiate()
	var mb: ZoneMap = b.instantiate()
	add_child(ma)
	add_child(mb)
	assert_eq(ma.get_terrain_rows(), mb.get_terrain_rows(), "same level, same map")
	ma.free()
	mb.free()

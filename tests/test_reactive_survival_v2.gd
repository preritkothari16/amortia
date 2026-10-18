extends GutTest
## Reactive Survival V2: wary enemies, shrinking SPOTTED countdowns with unlimited close calls,
## view cones only in the F6 debug overlay, the noise-maker inventory with refill pickups, the
## survivor's Run command, cover-seeking and tall-grass concealment, death = fail.
## CoverFinder itself: test_cover_finder.gd. Real level, real time (like test_reactive_survival).

const AREA: String = "res://world/zones/maple_hollow/areas/area_1.tscn"

var _p: PerceptionSettings


func before_each() -> void:
	_p = load("res://data/perception.tres")


func after_each() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0


# --- Helpers ------------------------------------------------------------------------------

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


func _level(type: ObjectiveConfig.Type, seed_value: int = 11) -> Dictionary:
	var c: LevelConfig = LevelConfig.new()
	c.id = "test_v2_%d" % type
	c.areas = [load(AREA)]
	c.waves = 1
	c.spawn_delay_seconds = 0.1
	c.objective = ObjectiveConfig.new()
	c.objective.type = type
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
	return {"main": main, "wm": wm, "player": player, "objective": main.objective, "flow": main.level_flow}


func _freeze_all(wm: WaveManager) -> void:
	for e: Enemy in wm.alive:
		e.set_physics_process(false)
		e.velocity = Vector2.ZERO
		e.global_position = Vector2(-2000, -2000)


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


func _face(e: Enemy, point: Vector2) -> void:
	e.velocity = Vector2.ZERO
	e.rest_facing = e.global_position.direction_to(point)
	e.facing = e.rest_facing


func _noise_pickups(main: Node) -> Array[Pickup]:
	var out: Array[Pickup] = []
	for child: Node in main.get_children():
		if child is Pickup and (child as Pickup).kind == &"noise_maker" and not child.is_queued_for_deletion():
			out.append(child)
	return out


func _press(node: Node, action: StringName) -> void:
	var key: InputEventAction = InputEventAction.new()
	key.action = action
	key.pressed = true
	node._unhandled_input(key)


# --- Wariness (Awareness, pure) -----------------------------------------------------------

func test_an_enemy_that_saw_you_stays_wary_then_calms_down() -> void:
	var a: Awareness = Awareness.new()
	a.wary_seconds = 20.0
	a.see(Vector2(40, 0))
	a.unnoticed(1.0 / 60.0, 1.0, 0.5)
	assert_true(a.is_wary(), "lost you: wary")
	a.arrive(2.0)
	for i: int in 5 * 60:  # search over, back to idle
		a.tick(1.0 / 60.0)
	assert_eq(a.state, Awareness.State.IDLE)
	assert_true(a.is_alert(), "idle but still wary: counts as alert (fills faster)")
	for i: int in 16 * 60:
		a.tick(1.0 / 60.0)
	assert_false(a.is_wary(), "after wary_seconds it calms down")
	assert_false(a.is_alert())


func test_hearing_or_suspecting_alone_does_not_make_an_enemy_wary() -> void:
	var a: Awareness = Awareness.new()
	a.wary_seconds = 20.0
	a.hear(Vector2(10, 0), 1.0)
	for i: int in 20:
		a.notice(Vector2(80, 0), 1.0, 1.0 / 60.0, 0.5)
	a.unnoticed(1.0, 1.0, 0.5)
	assert_false(a.is_wary(), "only an enemy that actually saw you (CHASE) becomes wary")


func test_wary_enemies_fill_suspicion_faster_and_sweep_wider() -> void:
	var arena: Dictionary = await _arena()
	var wm: WaveManager = arena["wm"]
	var player: Player = arena["player"]
	var e: Enemy = wm.spawn_enemy(Vector2(-900, -900), Genome.new())
	assert_eq(e.awareness.wary_seconds, _p.wary_seconds, "wary time comes from data/perception.tres")
	var calm: float = Perception.suspicion_rate(120.0, 32.0, 160.0, e.awareness.is_alert(), _p)
	e.awareness.see(player.global_position)
	e.awareness.lose_sight(1.0)
	var wary: float = Perception.suspicion_rate(120.0, 32.0, 160.0, e.awareness.is_alert(), _p)
	assert_almost_eq(wary, calm * _p.suspicion_alert_multiplier, 0.001, "x1.5 while wary")


func test_close_range_detection_is_unchanged() -> void:
	var arena: Dictionary = await _arena()
	var wm: WaveManager = arena["wm"]
	var player: Player = arena["player"]
	var dir: Vector2 = _open_direction(arena["main"], player.global_position, [24.0])
	var e: Enemy = wm.spawn_enemy(player.global_position + dir * 24.0, Genome.new())
	e.global_position = player.global_position + dir * 24.0
	e.velocity = Vector2.ZERO
	e.rest_facing = dir  # looking AWAY from the player
	e.facing = dir
	await wait_physics_frames(2)
	assert_eq(e.awareness.state, Awareness.State.CHASE, "within 2 tiles: noticed at once, even from behind")


# --- Cone display -------------------------------------------------------------------------

func test_no_cones_in_gameplay_but_vision_and_markers_are_unchanged() -> void:
	var arena: Dictionary = await _arena()
	var wm: WaveManager = arena["wm"]
	var player: Player = arena["player"]
	var main: Node = arena["main"]
	var dir: Vector2 = _open_direction(main, player.global_position, [150.0])
	var at: Vector2 = player.global_position + dir * 150.0
	var e: Enemy = wm.spawn_enemy(at, Genome.new())
	e.global_position = at
	assert_false("cone_alpha" in e, "no cone display state on enemies")
	assert_false(e.has_method("cone_wanted"), "no cone display logic on enemies")
	_face(e, at + dir * 50.0)  # looks away: the cone still gates sight
	await wait_physics_frames(30)
	assert_eq(e.awareness.suspicion, 0.0, "player behind it, beyond 2 tiles: unseen")
	_face(e, player.global_position)
	await wait_physics_frames(10)
	assert_gt(e.awareness.suspicion, 0.0, "facing the player: suspicion fills (drives the ? marker)")
	var overlay: AwarenessOverlay = main.get_node("AwarenessOverlay")
	assert_false(overlay.visible, "F6 debug overlay (the only place cones are drawn) starts hidden")
	assert_eq(e.view_cone_degrees(), _p.view_cone_degrees, "F6 overlay draws every cone from this")


# --- Stealth recovery ---------------------------------------------------------------------

func test_countdown_shrinks_with_each_escape_down_to_the_minimum() -> void:
	var lvl: Dictionary = await _level(ObjectiveConfig.Type.STEALTH)
	var stealth: StealthObjective = lvl["objective"]
	assert_eq(stealth.grace_for(0), 3.0)
	assert_eq(stealth.grace_for(1), 2.5)
	assert_eq(stealth.grace_for(2), 2.0)
	assert_eq(stealth.grace_for(3), 1.5)
	assert_eq(stealth.grace_for(9), 1.5, "never below alarm_grace_min")


func test_three_escapes_in_one_wave_then_staying_seen_fails() -> void:
	var lvl: Dictionary = await _level(ObjectiveConfig.Type.STEALTH)
	var stealth: StealthObjective = lvl["objective"]
	var wm: WaveManager = lvl["wm"]
	var player: Player = lvl["player"]
	_freeze_all(wm)
	for escape: int in 3:
		var spotter: Enemy = wm.alive[0]
		spotter.global_position = player.global_position + Vector2(20, 0)
		spotter.set_physics_process(true)
		await wait_physics_frames(3)
		assert_between(stealth.grace_left, stealth.grace_for(escape) - 0.1, stealth.grace_for(escape),
				"countdown %d is %.1f s" % [escape + 1, stealth.grace_for(escape)])
		spotter.take_damage(99999.0)  # nobody sees you any more
		await wait_physics_frames(int(stealth.grace_for(escape) * 60) + 5)
		assert_false(wm.failed, "escape %d" % (escape + 1))
		assert_eq(stealth.escapes_used, escape + 1)
	var watcher: Enemy = wm.alive[0]
	watcher.global_position = player.global_position + Vector2(20, 0)
	watcher.set_physics_process(true)
	await wait_physics_frames(3)
	assert_between(stealth.grace_left, 1.4, 1.5, "fourth countdown: the 1.5 s minimum")
	await wait_physics_frames(int(1.5 * 60) + 10)
	assert_true(wm.failed, "still seen when it ran out: mission failed")


# --- Noise-maker inventory ----------------------------------------------------------------

func test_campaign_level_starts_with_two_and_does_not_refill_each_wave() -> void:
	var lvl: Dictionary = await _level(ObjectiveConfig.Type.STEALTH)
	var player: Player = lvl["player"]
	var wm: WaveManager = lvl["wm"]
	assert_true(player.noise_maker_inventory)
	assert_eq(player.noise_makers_left, player.noise_maker.level_start_count)
	player.throw_noise_maker(player.global_position + Vector2(30, 0))
	assert_eq(player.noise_makers_left, 1)
	wm.wave_started.emit(2)  # what the next area's wave does
	assert_eq(player.noise_makers_left, 1, "carried over, not refilled")
	lvl["main"].load_area(load(AREA))
	assert_eq(player.noise_makers_left, 1, "loading the next area keeps it")
	await wait_physics_frames(3)  # let the old area's nodes go


func test_refill_pickups_add_one_up_to_the_maximum_and_wait_when_full() -> void:
	var lvl: Dictionary = await _level(ObjectiveConfig.Type.ESCORT)
	var main: Node = lvl["main"]
	var player: Player = lvl["player"]
	_freeze_all(lvl["wm"])
	await wait_physics_frames(2)
	var pickups: Array[Pickup] = _noise_pickups(main)
	assert_eq(pickups.size(), player.noise_maker.refills_per_area_stealth_escort, "2 on an Escort area")
	player.global_position = pickups[0].global_position
	await wait_physics_frames(4)
	assert_eq(player.noise_makers_left, 3, "+1")
	assert_false(is_instance_valid(pickups[0]) and not pickups[0].is_queued_for_deletion(), "taken")
	player.global_position = pickups[1].global_position
	await wait_physics_frames(4)
	assert_eq(player.noise_makers_left, player.noise_maker.max_carried, "never above the maximum")
	assert_true(is_instance_valid(pickups[1]) and not pickups[1].is_queued_for_deletion(), "full: it stays")
	player.throw_noise_maker(player.global_position + Vector2(30, 0))
	await wait_physics_frames(4)
	assert_eq(player.noise_makers_left, 3, "room again: picked up while standing on it")
	assert_eq(_noise_pickups(main).size(), 0)


func test_refill_pickups_are_reachable_seeded_and_retry_restores_the_count() -> void:
	var lvl: Dictionary = await _level(ObjectiveConfig.Type.STEALTH)
	var main: Node = lvl["main"]
	var player: Player = lvl["player"]
	var wm: WaveManager = lvl["wm"]
	var flow: LevelFlow = lvl["flow"]
	var grid: TerrainGrid = main.terrain_grid
	var settings: NoiseMakerSettings = player.noise_maker
	var cells: Array[Vector2i] = flow.refill_cells.duplicate()
	assert_eq(cells.size(), settings.refills_per_area_stealth_escort)
	var entry: Vector2i = grid.coords.world_to_cell(main.current_map().get_entry())
	var reachable: Array[Vector2i] = ReachableCells.from(grid, entry)
	for c: Vector2i in cells:
		assert_true(reachable.has(c), "%s reachable from the entry" % c)
		assert_between(Vector2(c - entry).length(), settings.refill_min_cells, settings.refill_max_cells)
	assert_gte(Vector2(cells[0] - cells[1]).length(), settings.refill_spacing_cells, "spread out")
	_freeze_all(wm)
	player.throw_noise_maker(player.global_position + Vector2(30, 0))
	assert_eq(player.noise_makers_left, 1)
	wm.fail_wave()
	get_tree().paused = false
	wm.continue_to_next_wave()  # Retry
	await wait_physics_frames(3)
	assert_eq(player.noise_makers_left, 2, "Retry gives back the count the wave started with")
	assert_eq(flow.refill_cells, cells, "same pickups in the same places")
	assert_eq(_noise_pickups(main).size(), cells.size())


# --- Escort: Run --------------------------------------------------------------------------

func test_run_and_follow_wait_keys() -> void:
	var lvl: Dictionary = await _level(ObjectiveConfig.Type.ESCORT)
	var escort: EscortObjective = lvl["objective"]
	_freeze_all(lvl["wm"])
	_press(escort, &"escort_run")
	assert_eq(escort.mode, EscortObjective.Mode.RUN, "R: run")
	_press(escort, &"escort_run")
	assert_eq(escort.mode, EscortObjective.Mode.FOLLOW, "R again: follow")
	_press(escort, &"escort_run")
	_press(escort, &"escort_command")
	assert_eq(escort.mode, EscortObjective.Mode.FOLLOW, "E while running: follow")
	_press(escort, &"escort_command")
	assert_eq(escort.mode, EscortObjective.Mode.WAIT, "E: wait")
	escort.stamina = escort.config.escort_run_min_stamina - 0.1
	assert_false(escort.toggle_run(), "too tired to start a run")
	assert_string_contains(escort.hud_text(), "stamina")
	assert_string_contains(escort.hud_text(), "[R]")


func test_running_is_fast_loud_and_tiring() -> void:
	var lvl: Dictionary = await _level(ObjectiveConfig.Type.ESCORT)
	var escort: EscortObjective = lvl["objective"]
	var wm: WaveManager = lvl["wm"]
	var player: Player = lvl["player"]
	var main: Node = lvl["main"]
	_freeze_all(wm)
	player.global_position = escort.survivor + Vector2(-400, 0)  # far away: FOLLOW would not move
	var behind: Vector2 = _open_direction(main, escort.survivor, [44.0])
	var listener: Enemy = wm.alive[0]
	listener.global_position = escort.survivor + behind * 44.0
	var noises: Array[Vector2] = []
	var record: Callable = func(pos: Vector2, radius: float) -> void:
		if is_equal_approx(radius, escort.config.escort_run_noise_radius):
			noises.append(pos)
	EventBus.noise_emitted.connect(record)
	var start: Vector2 = escort.survivor
	assert_true(escort.toggle_run())
	await wait_physics_frames(60)
	EventBus.noise_emitted.disconnect(record)
	assert_gt(escort.survivor.distance_to(start), escort.config.escort_speed * 1.2, "faster than walking")
	assert_gte(noises.size(), 2, "a noise every %.1f s" % escort.config.escort_run_noise_interval)
	assert_eq(listener.awareness.state, Awareness.State.INVESTIGATE, "an enemy close by heard it")
	assert_false(escort.is_survivor_concealed() and escort.running, "running is never hidden")
	assert_lt(escort.stamina, escort.config.escort_stamina_seconds - 0.8, "uses stamina")
	escort.stamina = 0.2
	await wait_physics_frames(20)
	assert_eq(escort.mode, EscortObjective.Mode.FOLLOW, "out of stamina: back to follow")
	var rested: float = escort.stamina
	await wait_physics_frames(60)
	assert_almost_eq(escort.stamina - rested, escort.config.escort_stamina_refill, 0.1, "stamina comes back")


func test_run_reaches_the_exit_under_several_seeds_with_the_player_far_behind() -> void:
	for seed_value: int in [3, 11, 29]:
		var lvl: Dictionary = await _level(ObjectiveConfig.Type.ESCORT, seed_value)
		var escort: EscortObjective = lvl["objective"]
		var player: Player = lvl["player"]
		_freeze_all(lvl["wm"])
		var start: Vector2 = escort.survivor
		Engine.time_scale = 3.0
		for f: int in 1800:
			if escort.state != Objective.State.ACTIVE:
				break
			player.global_position = start  # the player stays at the entry
			if escort.mode != EscortObjective.Mode.RUN and escort.stamina >= escort.config.escort_run_min_stamina:
				escort.toggle_run()  # R whenever it can run again
			await wait_physics_frames(1)
		Engine.time_scale = 1.0
		assert_eq(escort.state, Objective.State.COMPLETED, "seed %d: ran to the exit alone" % seed_value)
		lvl["main"].free()
		get_tree().paused = false
		await wait_physics_frames(2)


# --- Escort: cover, concealment, death ----------------------------------------------------

## Maple Hollow area 1 (a fixed scene) around the entry, rows 14-22:
##   14 #.............==      road on rows 16-17, entry at the left end
##   16 #==============
##   21 #....******...==      tall grass at x 5-10, rows 21-22
func test_threatened_survivor_takes_cover_out_of_sight_then_returns_to_its_post() -> void:
	var lvl: Dictionary = await _level(ObjectiveConfig.Type.ESCORT)
	var escort: EscortObjective = lvl["objective"]
	var wm: WaveManager = lvl["wm"]
	var main: Node = lvl["main"]
	var grid: TerrainGrid = main.terrain_grid
	_freeze_all(wm)
	assert_eq(grid.get_terrain(Vector2i(7, 21)), "tall_grass", "map layout as expected")
	escort.survivor = grid.coords.cell_to_world(Vector2i(7, 19))
	escort.toggle_mode()  # WAIT here
	var post: Vector2 = escort.survivor
	var e: Enemy = wm.alive[0]
	e.global_position = grid.coords.cell_to_world(Vector2i(7, 14))
	e.velocity = Vector2(0, 50)  # closing in (frozen, so it stays put)
	await wait_physics_frames(2)
	assert_true(escort.scared, "an enemy closing in = threatened")
	assert_eq(escort.retreat, EscortObjective.Retreat.COVER, "heads for cover instead of fighting")
	var hid: bool = false
	for f: int in 120:
		await wait_physics_frames(1)
		if escort.is_hiding():
			hid = true
			break
	assert_true(hid, "reached its cover")
	assert_string_contains(escort.hud_text(), "HIDING")
	var hidden: bool = escort.is_survivor_concealed() 			or not grid.has_line_of_sight(e.global_position, escort.survivor)
	assert_true(hidden, "the threat can't see it there")
	assert_gte(escort.survivor.distance_to(e.global_position), escort.config.escort_cover_gap_cells * 16.0 - 8.0)
	e.velocity = Vector2.ZERO
	e.global_position = Vector2(-2000, -2000)  # threat gone
	await wait_physics_frames(int(escort.config.escort_hide_seconds * 60) + 120)
	assert_eq(escort.retreat, EscortObjective.Retreat.NONE, "nobody saw it for a while: obeys again")
	assert_lt(escort.survivor.distance_to(post), 3.0, "WAIT: back at its post")


func test_no_reachable_cover_runs_to_the_player() -> void:
	var lvl: Dictionary = await _level(ObjectiveConfig.Type.ESCORT)
	var escort: EscortObjective = lvl["objective"]
	var wm: WaveManager = lvl["wm"]
	var main: Node = lvl["main"]
	var player: Player = lvl["player"]
	var grid: TerrainGrid = main.terrain_grid
	_freeze_all(wm)
	escort.survivor = grid.coords.cell_to_world(Vector2i(3, 16))
	player.global_position = grid.coords.cell_to_world(Vector2i(3, 10))
	var e: Enemy = wm.alive[0]
	e.global_position = grid.coords.cell_to_world(Vector2i(8, 16))
	e.velocity = Vector2(-50, 0)  # closing in along the road; the grass is nearer to it than to the survivor
	var before: float = escort.survivor.distance_to(player.global_position)
	await wait_physics_frames(30)
	assert_eq(escort.retreat, EscortObjective.Retreat.TO_PLAYER, "no cover it could reach in time: to the player")
	assert_lt(escort.survivor.distance_to(player.global_position), before - 16.0, "on its way")


func test_tall_grass_hides_a_still_survivor_beyond_two_tiles() -> void:
	var lvl: Dictionary = await _level(ObjectiveConfig.Type.ESCORT)
	var escort: EscortObjective = lvl["objective"]
	var wm: WaveManager = lvl["wm"]
	var main: Node = lvl["main"]
	var grid: TerrainGrid = main.terrain_grid
	_freeze_all(wm)
	var grass: Vector2 = Vector2.INF
	var dir: Vector2 = Vector2.ZERO
	for y: int in grid.height:
		for x: int in grid.width:
			if grid.get_terrain(Vector2i(x, y)) != "tall_grass":
				continue
			var at: Vector2 = grid.coords.cell_to_world(Vector2i(x, y))
			dir = _open_direction(main, at, [24.0, 80.0])
			if dir != Vector2.ZERO:
				grass = at
				break
		if grass != Vector2.INF:
			break
	assert_ne(grass, Vector2.INF, "the map has open tall grass")
	escort.survivor = grass
	var e: Enemy = wm.alive[0]
	e.global_position = grass + dir * 80.0
	_face(e, grass)
	e._can_perceive_player()  # sets effective_sight_range
	e._update_survivor_sight()
	assert_false(e.survivor_visible, "in tall grass, 5 tiles away: hidden")
	escort.running = true
	e._update_survivor_sight()
	assert_true(e.survivor_visible, "running through it: seen")
	escort.running = false
	e.global_position = grass + dir * 24.0
	e._update_survivor_sight()
	assert_true(e.survivor_visible, "within 2 tiles: seen anyway")


func test_no_cover_and_a_clear_route_runs_to_the_player() -> void:
	var clear: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]
	assert_true(EscortObjective._keeps_clear(clear, [Vector2i(0, 3)] as Array[Vector2i]))
	assert_false(EscortObjective._keeps_clear(clear, [Vector2i(2, 1)] as Array[Vector2i]), "passes next to a threat")


func test_survivor_never_fights() -> void:
	var lvl: Dictionary = await _level(ObjectiveConfig.Type.ESCORT)
	var escort: EscortObjective = lvl["objective"]
	var wm: WaveManager = lvl["wm"]
	_freeze_all(wm)
	var e: Enemy = wm.alive[0]
	e.global_position = escort.survivor + Vector2(12, 0)
	var hp: float = e.health
	await wait_physics_frames(60)
	assert_eq(e.health, hp, "enemies next to it take no damage from it")

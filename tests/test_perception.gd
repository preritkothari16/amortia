extends GutTest
## Expansion phase 3: vision (fog, night, concealment), hearing (night), stealth and player
## noise. Pure rules in Perception, grid overlays, the player's noise, and enemies in the level.

var _settings: PerceptionSettings
var _rules: TerrainCosts


func before_each() -> void:
	_settings = load("res://data/perception.tres")
	_rules = load("res://data/terrain_costs.tres")


# --- Perception rules ----------------------------------------------------------------

func test_effective_sight_range_fog_and_night() -> void:
	assert_almost_eq(Perception.effective_sight_range(160.0, 1.0, false, 0.0, _settings), 160.0, 0.001)
	assert_almost_eq(Perception.effective_sight_range(160.0, 0.5, false, 0.0, _settings), 80.0, 0.001, "fog -50 %")
	assert_almost_eq(Perception.effective_sight_range(160.0, 1.0, true, 0.0, _settings), 96.0, 0.001, "night -40 %")
	assert_almost_eq(Perception.effective_sight_range(160.0, 1.0, true, 1.0, _settings), 160.0, 0.001, "full night sense")
	assert_almost_eq(Perception.effective_sight_range(160.0, 0.5, true, 0.5, _settings), 64.0, 0.001, "both: 160 x .5 x .8")


func test_can_see_rules() -> void:
	assert_true(Perception.can_see(20.0, 32.0, 160.0, false, true), "inside 2 tiles: always noticed")
	assert_false(Perception.can_see(80.0, 32.0, 160.0, true, true), "concealed beyond 2 tiles")
	assert_true(Perception.can_see(80.0, 32.0, 160.0, true, false))
	assert_false(Perception.can_see(80.0, 32.0, 160.0, false, false), "wall in the way")
	assert_false(Perception.can_see(170.0, 32.0, 160.0, true, false), "out of range")


func test_hearing_radius_only_grows_at_night() -> void:
	assert_eq(Perception.hearing_radius(100.0, false, 1.0, _settings), 100.0)
	assert_almost_eq(Perception.hearing_radius(100.0, true, 0.0, _settings), 125.0, 0.001)
	assert_almost_eq(Perception.hearing_radius(100.0, true, 1.0, _settings), 175.0, 0.001)


func test_concealment_rule() -> void:
	assert_true(Perception.is_concealed(true, INF, false, _settings))
	assert_false(Perception.is_concealed(false, INF, false, _settings), "out of cover")
	assert_false(Perception.is_concealed(true, 0.5, false, _settings), "just shot")
	assert_true(Perception.is_concealed(true, 1.5, false, _settings), "exposure over")
	assert_false(Perception.is_concealed(true, INF, true, _settings), "rolling = running")


func test_footstep_radius_by_noise_level() -> void:
	var levels: Dictionary = {"grass": 24.0, "tall_grass": 24.0, "road": 48.0, "mud": 96.0, "shallow_water": 96.0}
	for terrain: String in levels:
		assert_eq(Perception.footstep_radius(_rules.get_definition(terrain).noise, _settings), levels[terrain], terrain)
	assert_eq(Perception.footstep_radius(99, _settings), 0.0)


# --- Grid overlays -------------------------------------------------------------------

func _grid(row: Array) -> TerrainGrid:
	return TerrainGrid.from_rows([PackedStringArray(row)] as Array[PackedStringArray], _rules)


func test_overlay_combines_without_losing_the_base_tile() -> void:
	var g: TerrainGrid = _grid(["grass", "mud", "wall", "road"])
	g.set_overlay(Vector2i(0, 0), "fire")
	g.set_overlay(Vector2i(1, 0), "fog")
	g.set_overlay(Vector2i(2, 0), "fog")
	assert_eq(g.get_cost(Vector2i(0, 0)), 20.0, "fire raises grass to 20")
	assert_eq(g.get_cost(Vector2i(1, 0)), 3.0, "fog doesn't lower mud")
	assert_eq(g.get_cost(Vector2i(2, 0)), INF, "a wall stays a wall")
	assert_eq(g.get_terrain(Vector2i(0, 0)), "grass")
	assert_eq(g.get_overlay(Vector2i(0, 0)), "fire")
	assert_eq(g.vision_multiplier(Vector2i(1, 0)), 0.5)
	assert_eq(g.vision_multiplier(Vector2i(3, 0)), 1.0)
	assert_eq(g.build_cost_array()[0], 20.0, "flow-field costs see the overlay too")
	g.set_overlay(Vector2i(0, 0), "")
	assert_eq(g.get_cost(Vector2i(0, 0)), 1.0, "cleared: back to grass")


func test_concealing_tiles() -> void:
	var g: TerrainGrid = _grid(["tall_grass", "grass", "fence"])
	assert_true(g.conceals(Vector2i(0, 0)))
	assert_false(g.conceals(Vector2i(1, 0)))
	assert_false(g.blocks_vision(Vector2i(0, 0)), "tall grass hides units IN it, lines pass through")


func test_changes_bump_version_and_report_cost_changes() -> void:
	var g: TerrainGrid = _grid(["road", "road", "grass"])
	watch_signals(g)
	var v: int = g.version
	g.set_overlay(Vector2i(0, 0), "fog")
	assert_eq(g.version, v + 1)
	assert_signal_emitted_with_parameters(g, "terrain_changed", [[Vector2i(0, 0)], false], 0)
	g.set_overlay(Vector2i(2, 0), "fire")
	assert_signal_emitted_with_parameters(g, "terrain_changed", [[Vector2i(2, 0)], true], 1)
	g.set_terrain(Vector2i(1, 0), "mud")
	assert_signal_emit_count(g, "terrain_changed", 3)
	g.set_overlay(Vector2i(0, 0), "fog")  # no change
	assert_signal_emit_count(g, "terrain_changed", 3)


func test_load_rows_replaces_the_map_in_place() -> void:
	var g: TerrainGrid = _grid(["road", "road"])
	g.set_overlay(Vector2i(0, 0), "fire")
	var astar: AStar = AStar.new(g)
	g.load_rows([PackedStringArray(["grass", "wall", "grass"])] as Array[PackedStringArray])
	assert_eq(g.width, 3)
	assert_eq(g.get_overlay(Vector2i(0, 0)), "", "overlays cleared")
	assert_eq(astar.find_path(Vector2i(0, 0), Vector2i(2, 0)), [] as Array[Vector2i], "same object, new map")


# --- Player noise and stealth ----------------------------------------------------------

func _player_on(terrain: String) -> Player:
	var row: PackedStringArray = PackedStringArray()
	row.resize(40)
	row.fill(terrain)
	var player: Player = load("res://entities/player/player.tscn").instantiate()
	player.terrain_grid = TerrainGrid.from_rows([row] as Array[PackedStringArray], _rules)
	add_child_autofree(player)
	player.global_position = Vector2(40, 8)
	return player


var _noises: Array[Array] = []


func _on_noise(pos: Vector2, radius: float) -> void:
	_noises.append([pos, radius])


func _walk_and_listen(terrain: String, frames: int) -> Array[Array]:
	_noises.clear()
	var player: Player = _player_on(terrain)
	EventBus.noise_emitted.connect(_on_noise)
	Input.action_press("move_right")
	await wait_physics_frames(frames)
	Input.action_release("move_right")
	EventBus.noise_emitted.disconnect(_on_noise)
	player.queue_free()
	return _noises.duplicate()


func test_footsteps_are_as_loud_as_the_tile() -> void:
	var road: Array[Array] = await _walk_and_listen("road", 70)
	assert_between(road.size(), 1, 3, "about one step per 0.5 s")
	assert_eq(road[0][1], 48.0)
	var mud: Array[Array] = await _walk_and_listen("mud", 70)
	assert_eq(mud[0][1], 96.0, "mud is loud")
	var grass: Array[Array] = await _walk_and_listen("grass", 70)
	assert_eq(grass[0][1], 24.0, "grass is quiet")


func test_standing_still_is_silent() -> void:
	_noises.clear()
	_player_on("mud")
	EventBus.noise_emitted.connect(_on_noise)
	await wait_physics_frames(60)
	EventBus.noise_emitted.disconnect(_on_noise)
	assert_eq(_noises.size(), 0)


func test_player_concealed_in_tall_grass_until_shooting() -> void:
	var player: Player = _player_on("tall_grass")
	await wait_physics_frames(1)
	assert_true(player.is_concealed())
	player.seconds_since_shot = 0.0
	assert_false(player.is_concealed())
	await wait_physics_frames(100)
	assert_true(player.is_concealed(), "1.5 s later hidden again")
	var open: Player = _player_on("grass")
	await wait_physics_frames(1)
	assert_false(open.is_concealed())


# --- Enemies in the level --------------------------------------------------------------

func _level() -> Dictionary:
	var main: Node = load("res://world/main.tscn").instantiate()
	main.autosave = false
	var wm: WaveManager = main.get_node("WaveManager")
	wm.auto_start = false
	wm.alert_on_spawn = false
	wm.spawn_scatter_tiles = 0
	wm.log_waves = false
	add_child_autofree(main)
	await wait_physics_frames(2)
	return {"main": main, "wm": wm, "player": main.get_node("Player")}


func _cell(c: Vector2i) -> Vector2:
	return Vector2(c * 16) + Vector2(8, 8)


func _watcher(lvl: Dictionary, at: Vector2i, night_sense: float = 0.0) -> Enemy:
	var g: Genome = Genome.new()  # vision 5 -> sight range 160 px (10 tiles)
	g.aggression = 0.0
	g.patience = 0.0
	g.night_sense = night_sense
	var e: Enemy = (lvl["wm"] as WaveManager).spawn_enemy(_cell(at), g)
	e.global_position = _cell(at)
	e.velocity = Vector2.ZERO
	# Looking at the player: these tests are about range, fog, night and cover, not the view cone.
	e.rest_facing = e.global_position.direction_to((lvl["player"] as Player).global_position)
	e.facing = e.rest_facing
	return e


func test_concealed_player_unseen_at_5_tiles_but_seen_inside_2() -> void:
	var lvl: Dictionary = await _level()
	var player: Player = lvl["player"]
	player.global_position = _cell(Vector2i(25, 23))  # tall grass
	var e: Enemy = _watcher(lvl, Vector2i(25, 28))      # 5 tiles south, clear line
	await wait_physics_frames(60)
	assert_true(player.is_concealed())
	assert_ne(e.awareness.state, Awareness.State.CHASE, "hidden in the grass")
	assert_eq(e.awareness.suspicion, 0.0, "not even a glimpse")
	player.seconds_since_shot = 0.0  # a shot gives the position away (for 1.5 s)
	await wait_physics_frames(90)  # 80 px: suspicion fills in about 1.0 s (shot exposure lasts 1.5 s)
	assert_eq(e.awareness.state, Awareness.State.CHASE)


func test_concealed_player_noticed_within_two_tiles() -> void:
	var lvl: Dictionary = await _level()
	var player: Player = lvl["player"]
	player.global_position = _cell(Vector2i(25, 24))
	var e: Enemy = _watcher(lvl, Vector2i(25, 26))  # 2 tiles = 32 px
	await wait_physics_frames(3)
	assert_true(player.is_concealed())
	assert_eq(e.awareness.state, Awareness.State.CHASE)


func test_night_shortens_sight_and_night_sense_restores_it() -> void:
	var lvl: Dictionary = await _level()
	var player: Player = lvl["player"]
	player.global_position = _cell(Vector2i(30, 10))
	var plain: Enemy = _watcher(lvl, Vector2i(30, 18))  # 8 tiles = 128 px down the road
	await wait_physics_frames(110)  # 128 px: suspicion fills in about 1.5 s
	assert_eq(plain.awareness.state, Awareness.State.CHASE, "day: 128 px < 160 px")
	plain.despawn()
	(lvl["wm"] as WaveManager).alive.erase(plain)
	lvl["main"].conditions.is_night = true
	var blind: Enemy = _watcher(lvl, Vector2i(30, 18))
	var owl: Enemy = _watcher(lvl, Vector2i(31, 18), 1.0)
	await wait_physics_frames(30)  # before the owl is sure (and could call the other one over)
	assert_almost_eq(blind.effective_sight_range, 96.0, 0.01)
	assert_ne(blind.awareness.state, Awareness.State.CHASE, "night: 128 px > 96 px")
	assert_eq(blind.awareness.suspicion, 0.0, "out of range: no suspicion either")
	assert_gt(owl.awareness.suspicion, 0.0, "the owl has noticed something")
	await wait_physics_frames(80)
	assert_eq(owl.awareness.state, Awareness.State.CHASE, "night sense 1 keeps full range")


func test_fog_halves_sight() -> void:
	var lvl: Dictionary = await _level()
	var grid: TerrainGrid = lvl["main"].terrain_grid
	var player: Player = lvl["player"]
	player.global_position = _cell(Vector2i(30, 10))
	grid.set_overlay(Vector2i(30, 10), "fog")
	var e: Enemy = _watcher(lvl, Vector2i(30, 16))  # 6 tiles = 96 px > 80 px
	await wait_physics_frames(90)
	assert_almost_eq(e.effective_sight_range, 80.0, 0.01)
	assert_ne(e.awareness.state, Awareness.State.CHASE)
	assert_eq(e.awareness.suspicion, 0.0)


func test_hearing_gives_only_the_noise_position() -> void:
	var lvl: Dictionary = await _level()
	var player: Player = lvl["player"]
	player.global_position = _cell(Vector2i(10, 16))
	var e: Enemy = _watcher(lvl, Vector2i(10, 30))  # far, no sight
	e.brain.genes.patience = 1.0
	await wait_physics_frames(2)
	var shot_at: Vector2 = player.global_position
	EventBus.noise_emitted.emit(shot_at, 400.0)
	await wait_physics_frames(1)
	assert_eq(e.awareness.last_known, shot_at)
	player.global_position = _cell(Vector2i(40, 16))
	await wait_physics_frames(5)
	assert_eq(e.awareness.last_known, shot_at, "no live tracking after the noise")

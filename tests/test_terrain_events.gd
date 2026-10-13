extends GutTest
## Expansion phase 4: dynamic terrain. Events (fire, bridge collapse, rising tide, fog banks,
## day/night, living walls), destructible tiles (TerrainHealth), hazards, and navigation /
## TileMap updates when terrain changes.

var _rules: TerrainCosts


func before_each() -> void:
	_rules = load("res://data/terrain_costs.tres")


## Grid from characters: . road  , grass  * tall_grass  F fence  # wall  = bridge
## ~ deep_water  s shallow_water  B barricade  D door
func _grid(lines: Array[String]) -> TerrainGrid:
	var legend: Dictionary = {".": "road", ",": "grass", "*": "tall_grass", "F": "fence", "#": "wall",
		"=": "bridge", "~": "deep_water", "s": "shallow_water", "B": "barricade", "D": "door"}
	var rows: Array[PackedStringArray] = []
	for line: String in lines:
		var row: PackedStringArray = PackedStringArray()
		for c: String in line:
			row.append(legend[c])
		rows.append(row)
	return TerrainGrid.from_rows(rows, _rules)


func _run(event: TerrainEvent, seconds: float, step: float = 0.1) -> void:
	for i: int in ceili(seconds / step - 0.001):  # 5.05 / 0.1 = 50.4999... -> 51 ticks
		event.tick(step)


# --- Fire ------------------------------------------------------------------------------

func _fire(g: TerrainGrid, seed_value: int = 1) -> FireSpread:
	var fire: FireSpread = FireSpread.new()
	fire.start(g, seed_value)
	return fire


func test_fire_is_warned_then_burns_then_leaves_ash() -> void:
	var g: TerrainGrid = _grid(["*,.", "...", "..."])
	var fire: FireSpread = _fire(g)
	fire.spread_chance = 0.0
	assert_true(fire.ignite(Vector2i(0, 0)))
	assert_true(fire.warnings.has(Vector2i(0, 0)), "warned first")
	assert_eq(g.get_overlay(Vector2i(0, 0)), "")
	_run(fire, 1.05)
	assert_eq(g.get_overlay(Vector2i(0, 0)), "fire")
	assert_eq(g.get_cost(Vector2i(0, 0)), 20.0)
	assert_eq(g.get_terrain(Vector2i(0, 0)), "tall_grass", "the tile under the fire is kept")
	_run(fire, 4.1)
	assert_eq(g.get_overlay(Vector2i(0, 0)), "")
	assert_eq(g.get_terrain(Vector2i(0, 0)), "ash")
	assert_eq(g.get_cost(Vector2i(0, 0)), 1.0, "ash costs 1")


func test_fire_only_spreads_to_burnable_tiles_and_is_capped() -> void:
	var g: TerrainGrid = _grid([",,,,,,,,", ",,,,,,,,", "........"])
	var fire: FireSpread = _fire(g, 3)
	fire.spread_chance = 1.0
	fire.max_burning = 6
	fire.burn_seconds = 100.0
	fire.ignite(Vector2i(0, 0), true)
	_run(fire, 10.0)
	for x: int in 8:
		assert_eq(g.get_overlay(Vector2i(x, 2)), "", "road never burns")
	assert_lte(fire.burning.size(), 6)
	assert_gt(fire.burning.size(), 1, "it spread")
	assert_false(fire.ignite(Vector2i(0, 2)), "road can't be lit")


func test_fire_is_deterministic_per_seed() -> void:
	var results: Array[String] = []
	for run: int in 2:
		var g: TerrainGrid = _grid([",,,,,,,,,,", ",,,,,,,,,,", ",,,,,,,,,,", ",,,,,,,,,,"])
		var fire: FireSpread = _fire(g, 42)
		fire.ignite(Vector2i(5, 2), true)
		_run(fire, 8.0)
		var cells: Array = fire.burning.keys()
		cells.sort()
		results.append(str(cells) + str(fire.warnings.keys()))
	assert_eq(results[0], results[1])


# --- Bridge ----------------------------------------------------------------------------

func test_bridge_collapses_after_crossings_with_warning() -> void:
	var g: TerrainGrid = _grid(["~~~~", ".==.", "~~~~"])
	var unit: Array[Vector2i] = [Vector2i(-1, -1)]
	var bridge: BridgeCollapse = BridgeCollapse.new()
	bridge.crossings_to_collapse = 2
	bridge.start(g, 1, func(cell: Vector2i) -> bool: return cell == unit[0])
	for crossing: int in 2:
		for x: int in [1, 2, 3]:
			unit[0] = Vector2i(x, 1)
			bridge.tick(0.1)
	assert_eq(bridge.crossings[0], 4, "two cells left twice")
	assert_eq(bridge.warnings.size(), 2, "whole bridge warned")
	assert_eq(g.get_terrain(Vector2i(1, 1)), "bridge", "not yet")
	unit[0] = Vector2i(3, 1)
	_run(bridge, 1.6)
	assert_eq(g.get_terrain(Vector2i(1, 1)), "deep_water")
	assert_eq(g.get_terrain(Vector2i(2, 1)), "deep_water")
	var field: FlowField = FlowField.new(g)
	field.build(Vector2i(3, 1))
	assert_false(field.is_reachable(Vector2i(0, 1)), "walkers cut off")
	field.build(Vector2i(3, 1), g.make_profile({"swimmer": 1.0}))
	assert_true(field.is_reachable(Vector2i(0, 1)), "swimmers still get through")


func test_bridge_waits_for_a_unit_standing_on_it() -> void:
	var g: TerrainGrid = _grid([".==."])
	var occupied: Array[Vector2i] = [Vector2i(1, 0)]
	var bridge: BridgeCollapse = BridgeCollapse.new()
	bridge.start(g, 1, func(cell: Vector2i) -> bool: return cell == occupied[0])
	bridge.explode(Vector2i(2, 0))
	_run(bridge, 3.0)
	assert_eq(g.get_terrain(Vector2i(2, 0)), "deep_water")
	assert_eq(g.get_terrain(Vector2i(1, 0)), "bridge", "someone is on it")
	occupied[0] = Vector2i(0, 0)
	_run(bridge, 0.2)
	assert_eq(g.get_terrain(Vector2i(1, 0)), "deep_water")


# --- Tide ------------------------------------------------------------------------------

func test_tide_rises_from_the_deep_water_edge() -> void:
	var g: TerrainGrid = _grid(["~sss."])
	var tide: RisingTide = RisingTide.new()
	tide.interval_seconds = 5.0
	tide.max_stages = 2
	tide.start(g, 1)
	_run(tide, 5.05)
	assert_eq(tide.warnings.keys(), [Vector2i(1, 0)] as Array[Vector2i])
	_run(tide, 2.1)
	assert_eq(g.get_terrain(Vector2i(1, 0)), "deep_water")
	assert_eq(g.get_terrain(Vector2i(2, 0)), "shallow_water")
	_run(tide, 10.0)
	assert_eq(g.get_terrain(Vector2i(2, 0)), "deep_water")
	assert_eq(g.get_terrain(Vector2i(3, 0)), "shallow_water", "stopped after 2 stages")


# --- Fog -------------------------------------------------------------------------------

func test_fog_moves_deterministically_and_only_changes_vision() -> void:
	var results: Array[String] = []
	for run: int in 2:
		var lines: Array[String] = []
		for y: int in 20:
			lines.append(".".repeat(30))
		var g: TerrainGrid = _grid(lines)
		var cost_changes: Array[bool] = []
		g.terrain_changed.connect(func(_c: Array[Vector2i], affects: bool) -> void: cost_changes.append(affects))
		var fog: FogBanks = FogBanks.new()
		fog.bank_count = 2
		fog.start(g, 99)
		var first: Array = fog.fogged.keys()
		_run(fog, 6.0)
		var later: Array = fog.fogged.keys()
		assert_ne(str(first), str(later), "banks move")
		assert_false(cost_changes.has(true), "fog over road never changes a cost")
		var some: Vector2i = later[0]
		assert_eq(g.get_terrain(some), "road", "base tile kept")
		assert_eq(g.vision_multiplier(some), 0.5)
		later.sort()
		results.append(str(later))
	assert_eq(results[0], results[1])


func test_fog_never_covers_fire() -> void:
	var g: TerrainGrid = _grid([",,,", ",,,", ",,,"])
	g.set_overlay(Vector2i(1, 1), "fire")
	var fog: FogBanks = FogBanks.new()
	fog.bank_count = 1
	fog.radius_tiles = 10.0
	fog.start(g, 5)
	assert_eq(g.get_overlay(Vector2i(1, 1)), "fire")
	assert_eq(g.get_overlay(Vector2i(0, 0)), "fog")


# --- Day / night -----------------------------------------------------------------------

func test_day_night_switches_and_warns() -> void:
	var g: TerrainGrid = _grid(["."])
	var conditions: WorldConditions = WorldConditions.new()
	var cycle: DayNight = DayNight.new()
	cycle.day_seconds = 10.0
	cycle.night_seconds = 5.0
	cycle.start(g, 1, Callable(), conditions)
	assert_false(conditions.is_night)
	_run(cycle, 6.0)
	assert_string_contains(cycle.status_text(), "Night falls")
	_run(cycle, 4.1)
	assert_true(conditions.is_night)
	_run(cycle, 5.2)  # night is 5 s (plus float slack)
	assert_false(conditions.is_night)


# --- Living walls ----------------------------------------------------------------------

func test_living_walls_grow_but_never_cut_protected_cells_apart() -> void:
	var g: TerrainGrid = _grid([
		"#####",
		"#...#",
		"#.#.#",
		"#...#",
		"#####",
	])
	var walls: LivingWalls = LivingWalls.new()
	walls.grow_interval = 1.0
	walls.warning_seconds = 0.5
	walls.candidate_cells = [Vector2i(2, 1), Vector2i(2, 3)]
	walls.protected_cells = [Vector2i(1, 2), Vector2i(3, 2)]
	walls.start(g, 7)
	_run(walls, 1.05)
	assert_eq(walls.warnings.size(), 1, "warned first")
	_run(walls, 6.0)
	assert_eq(walls.grown.size(), 1, "the second wall would close the loop: skipped")
	var a: bool = g.get_terrain(Vector2i(2, 1)) == "living_wall"
	var b: bool = g.get_terrain(Vector2i(2, 3)) == "living_wall"
	assert_true(a != b)
	assert_true(walls.would_disconnect(Vector2i(2, 1) if b else Vector2i(2, 3)), "the other one would")


# --- Destructible tiles ----------------------------------------------------------------

func test_fence_breaks_into_grass_after_40_damage() -> void:
	var g: TerrainGrid = _grid([".F."])
	var health: TerrainHealth = TerrainHealth.new(g)
	assert_eq(health.health_of(Vector2i(1, 0)), 40.0)
	assert_true(health.damage(Vector2i(1, 0), 30.0))
	assert_eq(g.get_terrain(Vector2i(1, 0)), "fence")
	health.damage(Vector2i(1, 0), 10.0)
	assert_eq(g.get_terrain(Vector2i(1, 0)), "grass")
	assert_false(health.damage(Vector2i(0, 0), 10.0), "road is indestructible")


func test_barricade_remembers_the_tile_under_it() -> void:
	var g: TerrainGrid = _grid([".*."])
	var health: TerrainHealth = TerrainHealth.new(g)
	assert_true(health.place(Vector2i(1, 0), "barricade"))
	assert_eq(g.get_cost(Vector2i(1, 0)), 5.0, "break-through cost")
	assert_true(g.blocks_vision(Vector2i(1, 0)))
	health.damage(Vector2i(1, 0), 50.0)
	assert_eq(g.get_terrain(Vector2i(1, 0)), "tall_grass")
	g.set_terrain(Vector2i(0, 0), "wall")
	assert_false(health.place(Vector2i(0, 0), "barricade"), "only on walkable tiles")


func test_doors_open_close_and_break() -> void:
	var g: TerrainGrid = _grid([".D."])
	var health: TerrainHealth = TerrainHealth.new(g)
	var occupied: Array[bool] = [false]
	health.is_occupied = func(_c: Vector2i) -> bool: return occupied[0]
	assert_true(g.blocks_vision(Vector2i(1, 0)))
	assert_true(health.open_door(Vector2i(1, 0)))
	assert_false(g.blocks_vision(Vector2i(1, 0)))
	assert_eq(g.get_cost(Vector2i(1, 0)), 1.0)
	occupied[0] = true
	assert_false(health.close_door(Vector2i(1, 0)), "someone in the doorway")
	occupied[0] = false
	assert_true(health.close_door(Vector2i(1, 0)))
	health.damage(Vector2i(1, 0), 60.0)
	assert_eq(g.get_terrain(Vector2i(1, 0)), "door_open")
	assert_false(health.close_door(Vector2i(1, 0)), "a broken door can't close")


# --- In the level ----------------------------------------------------------------------

func _level() -> Dictionary:
	var main: Node = load("res://world/main.tscn").instantiate()
	main.autosave = false
	var wm: WaveManager = main.get_node("WaveManager")
	wm.auto_start = false
	wm.spawn_scatter_tiles = 0
	wm.log_waves = false
	add_child_autofree(main)
	await wait_physics_frames(2)
	return {"main": main, "wm": wm, "player": main.get_node("Player"), "grid": main.terrain_grid}


func test_level_fence_shot_down_updates_tilemap_collision_and_navigation() -> void:
	var lvl: Dictionary = await _level()
	var grid: TerrainGrid = lvl["grid"]
	var main: Node = lvl["main"]
	var fence: Vector2i = Vector2i(13, 20)  # SW long fence
	assert_eq(grid.get_terrain(fence), "fence")
	var layer: TileMapLayer = main.get_node("MapleHollow").terrain_layer
	var v: int = grid.cost_version
	for i: int in 4:
		EventBus.terrain_hit.emit(grid.coords.cell_to_world(fence), 10.0)
	assert_eq(grid.get_terrain(fence), "grass")
	assert_gt(grid.cost_version, v)
	var tile: TileData = layer.get_cell_tile_data(fence)
	assert_eq(tile.get_custom_data(ZoneMap.TERRAIN_DATA_LAYER), "grass", "TileMap follows the grid")
	assert_eq(tile.get_collision_polygons_count(0), 0, "no collision any more")
	await wait_physics_frames(2)
	var next: Vector2i = main.flow_field.get_next_cell(fence)
	var step: float = grid.get_step_cost(fence, next)
	assert_almost_eq(main.flow_field.get_cost(fence), main.flow_field.get_cost(next) + step, 0.0001,
			"field rebuilt with grass (cost 1) where the fence was")
	assert_lt(step, 6.0)


func test_level_bullet_damages_a_fence() -> void:
	var lvl: Dictionary = await _level()
	var grid: TerrainGrid = lvl["grid"]
	var main: Node = lvl["main"]
	var fence: Vector2i = Vector2i(13, 20)
	var bullet: Bullet = load("res://entities/projectiles/bullet.tscn").instantiate()
	bullet.setup(Vector2.RIGHT, 300.0, 15.0, 1.0)
	bullet.global_position = grid.coords.cell_to_world(fence) + Vector2(-20, 0)
	main.add_child(bullet)
	await wait_physics_frames(10)
	assert_eq(main.terrain_health.health_of(fence), 25.0)


func test_level_enemy_breaks_a_barricade_in_its_way() -> void:
	var lvl: Dictionary = await _level()
	var grid: TerrainGrid = lvl["grid"]
	var main: Node = lvl["main"]
	var wm: WaveManager = lvl["wm"]
	var player: Player = lvl["player"]
	player.health = 100000.0
	player.global_position = grid.coords.cell_to_world(Vector2i(30, 3))
	# Fence the enemy in with a ring of barricades: the only way out is through one.
	var centre: Vector2i = Vector2i(40, 16)
	var ring: Array[Vector2i] = []
	for dy: int in range(-1, 2):
		for dx: int in range(-1, 2):
			if dx != 0 or dy != 0:
				ring.append(centre + Vector2i(dx, dy))
				assert_true(main.terrain_health.place(ring[-1], "barricade"))
	var g: Genome = Genome.new()
	g.patience = 1.0
	g.aggression = 1.0
	var e: Enemy = wm.spawn_enemy(grid.coords.cell_to_world(centre), g)
	e.global_position = grid.coords.cell_to_world(centre)
	e.alert(player.global_position)
	var broke: bool = false
	var hit: bool = false
	for i: int in 900:
		await wait_physics_frames(1)
		for c: Vector2i in ring:
			hit = hit or main.terrain_health.health_of(c) < 50.0
			if grid.get_terrain(c) != "barricade":
				broke = true
		if broke:
			break
	assert_true(hit, "the enemy hit a barricade")
	assert_true(broke, "and broke through")
	await wait_physics_frames(120)
	assert_ne(grid.coords.world_to_cell(e.global_position), centre, "and left the ring")


func test_level_hazards_hurt_and_toxin_resistance_protects() -> void:
	var lvl: Dictionary = await _level()
	var grid: TerrainGrid = lvl["grid"]
	var wm: WaveManager = lvl["wm"]
	var player: Player = lvl["player"]
	var cell: Vector2i = grid.coords.world_to_cell(player.global_position)
	grid.set_overlay(cell, "fire")
	await wait_physics_frames(40)
	assert_lt(player.health, 100.0, "fire burns the player")
	grid.set_overlay(cell, "")
	# Toxic pool under two enemies, one fully resistant.
	var spot: Vector2i = Vector2i(40, 16)
	grid.set_terrain(spot, "toxic_pool")
	var weak: Genome = Genome.new()
	var strong: Genome = Genome.new()
	strong.toxin_resistance = 1.0
	var a: Enemy = wm.spawn_enemy(grid.coords.cell_to_world(spot), weak)
	var b: Enemy = wm.spawn_enemy(grid.coords.cell_to_world(spot), strong)
	for e: Enemy in [a, b]:
		e.global_position = grid.coords.cell_to_world(spot)
		e.set_physics_process(false)  # keep them in the pool
	await wait_physics_frames(40)
	assert_lt(a.health, a.stats.max_health)
	assert_eq(b.health, b.stats.max_health)

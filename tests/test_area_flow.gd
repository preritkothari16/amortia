extends GutTest
## Expansion phase 5: wave-to-wave area progression. WaveManager delayed / behind spawns and
## unscored stragglers, the three hand-made area variants, and LevelFlow in the real level.

const LEVEL: String = "res://data/levels/test_area_flow.tres"
const AREAS: Array[String] = [
	"res://world/zones/maple_hollow/areas/area_1.tscn",
	"res://world/zones/maple_hollow/areas/area_2.tscn",
	"res://world/zones/maple_hollow/areas/area_3.tscn",
]


func after_each() -> void:
	get_tree().paused = false
	GameState.reset_inventory()


# --- Area variants ---------------------------------------------------------------------

func test_each_area_connects_entry_to_exit_with_far_spawns() -> void:
	var rules: TerrainCosts = load("res://data/terrain_costs.tres")
	for path: String in AREAS:
		var map: ZoneMap = load(path).instantiate()
		add_child_autofree(map)
		var grid: TerrainGrid = TerrainGrid.from_rows(map.get_terrain_rows(), rules)
		var entry: Vector2i = map.world_to_cell(map.get_entry())
		var exit_cell: Vector2i = map.world_to_cell(map.get_exit())
		var gates: Array[Vector2i] = map.get_gate_cells()
		assert_eq(gates.size(), 4, path)
		for g: Vector2i in gates:
			assert_eq(g.x, grid.width - 1, "gate in the right border")
		# BFS over player-walkable cells.
		var seen: Dictionary = {entry: true}
		var queue: Array[Vector2i] = [entry]
		while not queue.is_empty():
			var c: Vector2i = queue.pop_front()
			for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var n: Vector2i = c + d
				var def: TerrainDefinition = grid.get_definition(n)
				if not seen.has(n) and def != null and def.player_passable:
					seen[n] = true
					queue.append(n)
		assert_true(seen.has(exit_cell), "%s: entry reaches the exit" % path)
		for s: Vector2 in map.get_enemy_spawns():
			var cell: Vector2i = map.world_to_cell(s)
			assert_true(seen.has(cell), "%s spawn %s reachable" % [path, cell])
			assert_gte(Vector2(cell - entry).length(), 15.0, "%s spawn %s far from the entry" % [path, cell])
		assert_eq(map.get_behind_spawns().size(), 2)


# --- WaveManager -----------------------------------------------------------------------

func _level(config: LevelConfig = null, seed_value: int = 5) -> Dictionary:
	var main: Node = load("res://world/main.tscn").instantiate()
	main.autosave = false
	main.level_config = config
	var wm: WaveManager = main.get_node("WaveManager")
	wm.spawn_seed = seed_value
	wm.log_waves = false
	add_child_autofree(main)
	await wait_physics_frames(2)
	var player: Player = main.get_node("Player")
	player.health = 100000.0
	return {"main": main, "wm": wm, "player": player}


func test_spawn_delay_holds_enemies_back() -> void:
	var main: Node = load("res://world/main.tscn").instantiate()
	main.autosave = false
	var wm: WaveManager = main.get_node("WaveManager")
	wm.spawn_delay_seconds = 1.0
	wm.log_waves = false
	watch_signals(wm)
	add_child_autofree(main)
	await wait_physics_frames(2)
	assert_signal_emitted(wm, "wave_started")
	assert_eq(wm.alive.size(), 0, "nobody yet")
	assert_true(wm.is_arriving())
	assert_eq(wm.wave_seconds, 0.0, "the clock waits too")
	await wait_physics_frames(62)
	assert_signal_emitted(wm, "enemies_arrived")
	assert_eq(wm.alive.size(), wm.population.size())


func test_stragglers_are_never_scored() -> void:
	var lvl: Dictionary = await _level()
	var wm: WaveManager = lvl["wm"]
	var entries: int = wm._wave_entries.size()
	var straggler: Enemy = wm.spawn_straggler()
	assert_not_null(straggler)
	assert_null(straggler.fitness_record, "no fitness record")
	assert_eq(wm._wave_entries.size(), entries, "not part of the wave")
	assert_true(wm.population.has(straggler.genome), "a member of the current population")
	wm.end_wave()
	for r: Dictionary in wm.last_wave_results:
		assert_ne(r["record"], null)
	assert_eq(wm.last_wave_results.size(), entries)


# --- LevelFlow in the level ------------------------------------------------------------

func _kill_all(wm: WaveManager) -> void:
	for e: Enemy in wm.alive.duplicate():
		e.take_damage(99999.0)


func test_full_level_flow_three_areas() -> void:
	var lvl: Dictionary = await _level(load(LEVEL))
	var main: Node = lvl["main"]
	var wm: WaveManager = lvl["wm"]
	var player: Player = lvl["player"]
	var flow: LevelFlow = main.level_flow
	var grid: TerrainGrid = main.terrain_grid
	watch_signals(flow)
	assert_not_null(flow)
	assert_eq(flow.phase, LevelFlow.Phase.ENTERING)
	assert_eq(grid.coords.world_to_cell(player.global_position), Vector2i(2, 16), "at the left entry")
	assert_eq(wm.alive.size(), 0, "enemies come after the opening delay")
	# Build two barricades in the opening.
	player.build_requested.emit(Vector2i(6, 16))
	player.build_requested.emit(Vector2i(6, 17))
	assert_eq(grid.get_terrain(Vector2i(6, 16)), "barricade")
	assert_eq(flow.barricades_left, 1)
	await wait_physics_frames(185)
	assert_eq(flow.phase, LevelFlow.Phase.FIGHTING)
	player.build_requested.emit(Vector2i(7, 16))
	assert_eq(grid.get_terrain(Vector2i(7, 16)), "road", "no building once they're here")
	var gen: int = wm.generation
	_kill_all(wm)
	await wait_physics_frames(2)
	assert_eq(flow.phase, LevelFlow.Phase.CLEARED)
	assert_eq(wm.generation, gen + 1, "the wave was bred as usual")
	for g: Vector2i in main.current_map().get_gate_cells():
		assert_eq(grid.get_terrain(g), "road", "exit gate open")
	assert_gt(GameState.scrap, -1)
	var drops: int = 0
	for child: Node in main.get_children():
		if child is Pickup:
			drops += 1
	assert_gt(drops, 0, "kills drop samples / scrap")
	# Stragglers after 15 s (shortened here), not scored.
	flow.straggler_left = 0.05
	await wait_physics_frames(5)
	assert_gt(flow.stragglers_spawned, 0)
	for e: Enemy in wm.alive:
		assert_null(e.fitness_record)
	# Walk out -> report; Continue -> next area, wave 2, part of it from behind.
	player.global_position = main.current_map().get_exit()
	await wait_physics_frames(1)
	assert_eq(flow.phase, LevelFlow.Phase.EXITED)
	assert_true(main.get_node("HUD/WaveReport").visible, "Wave Report at the exit")
	assert_eq(wm.alive.size(), 0, "stragglers gone")
	var old_map: ZoneMap = main.current_map()
	main.get_node("HUD/WaveReport")._continue_button.pressed.emit()
	assert_ne(main.current_map(), old_map, "next area loaded")
	assert_eq(main.current_map().scene_file_path, AREAS[1])
	assert_eq(grid.get_terrain(Vector2i(6, 16)), "road", "barricades don't carry over")
	assert_eq(wm.wave_number, 2)
	assert_true(wm.use_behind_spawns)
	await wait_physics_frames(185)
	var behind: int = 0
	for e: Enemy in wm.alive:
		if e.global_position.x < 9 * 16:
			behind += 1
	assert_gt(behind, 0, "some arrive from behind")
	# Waves 2 and 3.
	for wave: int in [2, 3]:
		_kill_all(wm)
		await wait_physics_frames(2)
		assert_eq(flow.phase, LevelFlow.Phase.CLEARED)
		player.global_position = main.current_map().get_exit()
		await wait_physics_frames(1)
		if wave < 3:
			main.get_node("HUD/WaveReport")._continue_button.pressed.emit()
			await wait_physics_frames(185)
	assert_eq(flow.phase, LevelFlow.Phase.COMPLETE)
	assert_signal_emitted(flow, "level_completed")


func test_retry_reloads_the_same_area_and_wave() -> void:
	var lvl: Dictionary = await _level(load(LEVEL))
	var main: Node = lvl["main"]
	var wm: WaveManager = lvl["wm"]
	var player: Player = lvl["player"]
	var grid: TerrainGrid = main.terrain_grid
	player.build_requested.emit(Vector2i(6, 16))
	await wait_physics_frames(185)
	var population: Array[Genome] = wm.population.duplicate()
	player.health = 1.0
	player.take_damage(10.0)
	await wait_physics_frames(2)
	assert_true(wm.failed)
	assert_true(main.get_node("HUD/GameOverScreen").visible)
	main.get_node("HUD/GameOverScreen")._retry_button.pressed.emit()
	assert_eq(wm.wave_number, 1)
	assert_eq(wm.population, population, "same genomes")
	assert_eq(main.current_map().scene_file_path, AREAS[0], "same area")
	assert_eq(grid.get_terrain(Vector2i(6, 16)), "road", "fresh area: the barricade is gone")
	assert_eq(main.level_flow.phase, LevelFlow.Phase.ENTERING)
	assert_eq(grid.coords.world_to_cell(player.global_position), Vector2i(2, 16))


func test_downed_after_clearing_keeps_the_wave() -> void:
	var lvl: Dictionary = await _level(load(LEVEL))
	var main: Node = lvl["main"]
	var wm: WaveManager = lvl["wm"]
	var player: Player = lvl["player"]
	await wait_physics_frames(185)
	_kill_all(wm)
	await wait_physics_frames(2)
	assert_eq(main.level_flow.phase, LevelFlow.Phase.CLEARED)
	player.health = 1.0
	player.take_damage(10.0)
	await wait_physics_frames(2)
	assert_false(wm.failed, "not a lost wave")
	assert_eq(main.level_flow.waves_done, 1)
	assert_eq(main.level_flow.phase, LevelFlow.Phase.EXITED)
	assert_true(main.get_node("HUD/WaveReport").visible)


func test_pickups_add_to_the_inventory() -> void:
	var lvl: Dictionary = await _level()
	var main: Node = lvl["main"]
	var player: Player = lvl["player"]
	GameState.reset_inventory()
	main.add_child(Pickup.create(&"sample", 1, player.global_position))
	main.add_child(Pickup.create(&"scrap", 3, player.global_position))
	await wait_physics_frames(3)
	assert_eq(GameState.samples, 1)
	assert_eq(GameState.scrap, 3)

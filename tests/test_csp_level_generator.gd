extends GutTest
## Expansion phase 7: CSP level generator (backtracking + MRV + forward checking) over the
## hand-made Maple Hollow room chunks. Every layout is re-checked here independently of the
## solver's own checks.

var _rules: TerrainCosts
var _settings: LevelGenSettings


func before_each() -> void:
	_rules = load("res://data/terrain_costs.tres")
	_settings = (load("res://data/levelgen/maple_hollow.tres") as LevelGenSettings).duplicate()


func _generate(seed_value: int, settings: LevelGenSettings = null) -> Dictionary:
	var gen: CspLevelGenerator = CspLevelGenerator.new(settings if settings != null else _settings, _rules)
	var result: Dictionary = gen.generate(seed_value)
	result["nodes"] = gen.nodes
	return result


## Independent BFS (4-way). player: player_passable (gate open); else enemy cost < INF.
func _reach(rows: Array[PackedStringArray], start: Vector2i, player: bool) -> Dictionary:
	var seen: Dictionary = {start: true}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		for d: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
			var n: Vector2i = c + d
			if n.y < 0 or n.x < 0 or n.y >= rows.size() or n.x >= rows[0].size() or seen.has(n):
				continue
			var t: String = rows[n.y][n.x]
			var ok: bool = (t == "gate" or _rules.get_definition(t).player_passable) if player \
					else (t != "gate" and _rules.cost_of(t) < INF)
			if ok:
				seen[n] = true
				queue.append(n)
	return seen


func _assert_valid(layout: Dictionary, label: String) -> void:
	var lib: RoomChunkLibrary = _settings.library
	var ids: Array = layout["chunk_ids"]
	var cols: int = _settings.columns
	var rows_n: int = _settings.rows
	var rows: Array[PackedStringArray] = layout["rows"]
	assert_eq(rows.size(), rows_n * 16, label)
	assert_eq(rows[0].size(), cols * 16, label)
	# Every tile is known terrain.
	for row: PackedStringArray in rows:
		for t: String in row:
			assert_not_null(_rules.get_definition(t), "%s: unknown terrain %s" % [label, t])
	# Shared edges match, nothing opens off the map except entry (W) and exit (E).
	var hazard: bool = false
	for r: int in rows_n:
		for c: int in cols:
			var chunk: RoomChunk = lib.find(ids[r * cols + c])
			hazard = hazard or chunk.hazard
			if c + 1 < cols:
				assert_eq(chunk.has_exit(RoomChunk.E), lib.find(ids[r * cols + c + 1]).has_exit(RoomChunk.W), "%s: E/W edge at %d,%d" % [label, c, r])
			if r + 1 < rows_n:
				assert_eq(chunk.has_exit(RoomChunk.S), lib.find(ids[(r + 1) * cols + c]).has_exit(RoomChunk.N), "%s: S/N edge at %d,%d" % [label, c, r])
			if r == 0:
				assert_false(chunk.has_exit(RoomChunk.N), label)
			if r == rows_n - 1:
				assert_false(chunk.has_exit(RoomChunk.S), label)
			if c == 0:
				assert_eq(chunk.has_exit(RoomChunk.W), r == layout["entry_row"], label)
			if c == cols - 1:
				assert_eq(chunk.has_exit(RoomChunk.E), r == layout["exit_row"], label)
	assert_true(hazard, "%s: at least one hazard" % label)
	# No run of 3 chokepoints in a row or column.
	for r: int in rows_n:
		var run: int = 0
		for c: int in cols:
			run = run + 1 if lib.find(ids[r * cols + c]).chokepoint else 0
			assert_lte(run, 2, label)
	for c: int in cols:
		var run: int = 0
		for r: int in rows_n:
			run = run + 1 if lib.find(ids[r * cols + c]).chokepoint else 0
			assert_lte(run, 2, label)
	# Player spawn reaches the exit / objective; spawns far and reachable by enemies.
	var spawn: Vector2i = layout["player_spawn"]
	assert_true(_rules.get_definition(rows[spawn.y][spawn.x]).player_passable, label)
	assert_true(_reach(rows, spawn, true).has(layout["exit"]), "%s: exit reachable" % label)
	var enemy_reach: Dictionary = _reach(rows, spawn, false)
	assert_gte((layout["enemy_spawns"] as Array).size(), _settings.min_spawns, label)
	for s: Vector2i in layout["enemy_spawns"]:
		assert_gte(Vector2(s - spawn).length(), 15.0, "%s: spawn %s too close" % [label, s])
		assert_true(enemy_reach.has(s), "%s: spawn %s unreachable" % [label, s])
		assert_true(_rules.cost_of(rows[s.y][s.x]) < INF and _rules.get_definition(rows[s.y][s.x]).player_passable,
				"%s: spawn on open ground" % label)
	for g: Vector2i in layout["gate_cells"]:
		assert_eq(g.x, cols * 16 - 1, "gate in the right edge")
		assert_eq(rows[g.y][g.x], "gate")


# --- Chunks ----------------------------------------------------------------------------

func test_chunk_library_is_valid() -> void:
	var lib: RoomChunkLibrary = _settings.library
	assert_gte(lib.chunks.size(), 12)
	var combos: Dictionary = {}
	for chunk: RoomChunk in lib.chunks:
		combos[chunk.exits] = true
		assert_eq(chunk.cells.size(), 16)
		for row: String in chunk.cells:
			assert_eq(row.length(), 16, chunk.id)
			for c: String in row:
				assert_ne(lib.terrain_of(c), "", "%s: legend has %s" % [chunk.id, c])
		for dir: int in [RoomChunk.N, RoomChunk.E, RoomChunk.S, RoomChunk.W]:
			for cell: Vector2i in RoomChunk.opening_cells(dir):
				var open: bool = _rules.get_definition(lib.terrain_of(chunk.char_at(cell))).player_passable
				assert_eq(open, chunk.has_exit(dir), "%s edge %d" % [chunk.id, dir])
	assert_gte(combos.size(), 10, "enough exit combinations")


# --- Solver ----------------------------------------------------------------------------

func test_same_seed_same_level() -> void:
	var a: Dictionary = _generate(1234)
	var b: Dictionary = _generate(1234)
	assert_true(a["ok"], a["error"])
	assert_eq(a["layout"]["chunk_ids"], b["layout"]["chunk_ids"])
	assert_eq(str(a["layout"]["rows"]), str(b["layout"]["rows"]))
	assert_eq(a["layout"]["enemy_spawns"], b["layout"]["enemy_spawns"])


func test_many_seeds_valid_and_different() -> void:
	var seen: Dictionary = {}
	for seed_value: int in range(1, 41):
		var r: Dictionary = _generate(seed_value)
		assert_true(r["ok"], "seed %d: %s" % [seed_value, r["error"]])
		if r["ok"]:
			_assert_valid(r["layout"], "seed %d" % seed_value)
			seen[str(r["layout"]["chunk_ids"])] = true
			assert_lte(r["nodes"], _settings.max_nodes)
	assert_gt(seen.size(), 10, "different seeds give different levels (%d distinct)" % seen.size())


func test_bigger_grid() -> void:
	_settings.columns = 5
	_settings.rows = 3
	for seed_value: int in [3, 9, 27]:
		var r: Dictionary = _generate(seed_value)
		assert_true(r["ok"], r["error"])
		if r["ok"]:
			_assert_valid(r["layout"], "5x3 seed %d" % seed_value)


func test_impossible_edges_fail_clearly() -> void:
	var lib: RoomChunkLibrary = RoomChunkLibrary.new()
	lib.legend = _settings.library.legend
	var only_ns: Array[RoomChunk] = []
	only_ns.append(_settings.library.find("avenue"))
	lib.chunks = only_ns
	_settings.library = lib
	var r: Dictionary = _generate(1)
	assert_false(r["ok"])
	assert_string_contains(r["error"], "no chunk fits slot")


func test_unsatisfiable_global_constraint_fails() -> void:
	var lib: RoomChunkLibrary = RoomChunkLibrary.new()
	lib.legend = _settings.library.legend
	var safe: Array[RoomChunk] = []
	for c: RoomChunk in _settings.library.chunks:
		if not c.hazard:
			safe.append(c)
	lib.chunks = safe
	_settings.library = lib
	_settings.max_nodes = 200000
	var r: Dictionary = _generate(5)
	assert_false(r["ok"], "no hazard chunk -> can't satisfy 'at least one hazard'")
	assert_true(r["error"].contains("no layout") or r["error"].contains("budget"), r["error"])


func test_search_budget_is_respected() -> void:
	_settings.max_nodes = 3
	var r: Dictionary = _generate(1)
	assert_false(r["ok"])
	assert_string_contains(r["error"], "budget")
	assert_lte(r["nodes"], 3)


func test_spawn_distance_constraint_bites() -> void:
	_settings.min_spawn_distance = 200.0  # impossible on a 64 x 32 map
	_settings.max_nodes = 3000
	var r: Dictionary = _generate(2)
	assert_false(r["ok"])


# --- In the game ---------------------------------------------------------------------------

func test_generated_area_plays_in_the_level() -> void:
	var scene: PackedScene = GeneratedArea.build_scene(load("res://data/levelgen/maple_hollow.tres"), 7)
	assert_not_null(scene)
	var map: ZoneMap = scene.instantiate()
	add_child_autofree(map)
	assert_eq(map.get_grid_size(), Vector2i(64, 32))
	assert_eq(map.get_gate_cells().size(), 2)
	assert_gte(map.get_enemy_spawns().size(), 4)
	var main: Node = load("res://world/main.tscn").instantiate()
	main.autosave = false
	main.level_config = load("res://data/levels/test_generated.tres")
	main.level_config.spawn_delay_seconds = 0.1
	var wm: WaveManager = main.get_node("WaveManager")
	wm.log_waves = false
	add_child_autofree(main)
	await wait_physics_frames(12)
	assert_eq(main.terrain_grid.width, 64)
	assert_eq(wm.alive.size(), wm.population.size(), "the wave spawned on the generated map")
	assert_true(main.flow_field.is_reachable(main.terrain_grid.coords.world_to_cell(wm.alive[0].global_position)))
	main.level_config.spawn_delay_seconds = 3.0

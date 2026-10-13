class_name CspLevelGenerator
extends RefCounted
## Hand-written CSP level generator (GDD 4.6, syllabus Unit 4). Places room chunks on a grid of
## slots with backtracking search, Minimum Remaining Values and forward checking.
## Approach and pseudocode: docs/graded_ai_notes.md, "Phase 7".
##
##   variables  : slots (column, row)
##   domains    : chunk indices allowed in each slot (edge rules applied up front)
##   constraints: shared edges match; no run of > max_consecutive_chokepoints chokepoints;
##                globally: >= 1 hazard, entry reaches exit (player), >= min_spawns enemy
##                spawns reachable by enemies and >= min_spawn_distance from the player spawn
##
## generate(seed) -> {ok, error, layout}. layout = {
##   rows: Array[PackedStringArray] (terrain names, rows[y][x]), chunk_ids (per slot),
##   player_spawn: Vector2i, exit: Vector2i, gate_cells: Array[Vector2i],
##   enemy_spawns: Array[Vector2i], behind_spawns: Array[Vector2i] }
## Pure logic: needs only the settings and the terrain rules, no Nodes.

const DIRECTIONS: Array[int] = [RoomChunk.N, RoomChunk.E, RoomChunk.S, RoomChunk.W]

var settings: LevelGenSettings
var rules: TerrainCosts

## Search statistics of the last generate() call (for tests and experiments).
var nodes: int = 0
var backtracks: int = 0

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _chunks: Array[RoomChunk] = []
## Slot index -> array of chunk indices still allowed.
var _domains: Array[Array] = []
## Slot index -> chunk index (-1 = unassigned).
var _assignment: PackedInt32Array = PackedInt32Array()
var _entry_row: int = 0
var _exit_row: int = 0
var _budget_hit: bool = false


func _init(level_settings: LevelGenSettings, terrain_rules: TerrainCosts) -> void:
	settings = level_settings
	rules = terrain_rules


## Runs the search for this seed. Same seed + same settings = same layout.
func generate(seed_value: int) -> Dictionary:
	_rng.seed = seed_value
	nodes = 0
	backtracks = 0
	_budget_hit = false
	_chunks = settings.library.chunks
	var cols: int = settings.columns
	var rows: int = settings.rows
	if _chunks.is_empty() or cols < 1 or rows < 1:
		return _fail("empty chunk library or grid")
	_entry_row = settings.entry_row if settings.entry_row >= 0 else _rng.randi_range(0, rows - 1)
	_exit_row = settings.exit_row if settings.exit_row >= 0 else _rng.randi_range(0, rows - 1)
	if _entry_row >= rows or _exit_row >= rows:
		return _fail("entry/exit row outside the grid")

	# Node consistency: each slot only keeps chunks whose exits fit the map edge.
	_domains.clear()
	_assignment.resize(cols * rows)
	_assignment.fill(-1)
	for slot: int in cols * rows:
		var allowed: Array = []
		for i: int in _chunks.size():
			if _fits_edges(slot, _chunks[i]):
				allowed.append(i)
		if allowed.is_empty():
			return _fail("no chunk fits slot %s (edge exits)" % _slot_cell(slot))
		_domains.append(allowed)

	if not _backtrack():
		return _fail("search budget exhausted (%d nodes)" % nodes if _budget_hit
				else "no layout satisfies the constraints")
	return {"ok": true, "error": "", "layout": _build_layout()}


# --- Search --------------------------------------------------------------------------

## Backtracking search with MRV and forward checking. True when _assignment is complete and
## passes the global constraints.
func _backtrack() -> bool:
	if nodes >= settings.max_nodes:
		_budget_hit = true
		return false
	var slot: int = _select_mrv_slot()
	if slot < 0:
		return _global_constraints_ok()  # every slot assigned
	# Value order: the seeded shuffle is the only randomness, so a seed fixes the layout.
	var values: Array = _domains[slot].duplicate()
	_shuffle(values)
	for value: int in values:
		nodes += 1
		if nodes >= settings.max_nodes:
			_budget_hit = true
			return false
		if not _run_constraint_ok(slot, value):
			continue
		var saved: Dictionary = _save_neighbour_domains(slot)
		_assignment[slot] = value
		if _forward_check(slot, value) and _backtrack():
			return true
		# Undo and try the next chunk.
		_assignment[slot] = -1
		_restore_domains(saved)
		backtracks += 1
		if _budget_hit:
			return false
	return false


## MRV: the unassigned slot with the fewest values left; ties -> lowest index (deterministic).
## -1 = all assigned.
func _select_mrv_slot() -> int:
	var best: int = -1
	var best_size: int = 1 << 30
	for slot: int in _assignment.size():
		if _assignment[slot] >= 0:
			continue
		var size: int = _domains[slot].size()
		if size < best_size:
			best = slot
			best_size = size
	return best


## Forward checking: removes from each unassigned neighbour every chunk whose shared edge
## doesn't match `value`'s. False if a neighbour is left with nothing (dead end).
func _forward_check(slot: int, value: int) -> bool:
	var chunk: RoomChunk = _chunks[value]
	for dir: int in DIRECTIONS:
		var n: int = _neighbour(slot, dir)
		if n < 0 or _assignment[n] >= 0:
			continue
		var needs_exit: bool = chunk.has_exit(dir)
		var opposite: int = _opposite(dir)
		var kept: Array = []
		for other: int in _domains[n]:
			if _chunks[other].has_exit(opposite) == needs_exit:
				kept.append(other)
		_domains[n] = kept
		if kept.is_empty():
			return false
	return true


func _save_neighbour_domains(slot: int) -> Dictionary:
	var saved: Dictionary = {}
	for dir: int in DIRECTIONS:
		var n: int = _neighbour(slot, dir)
		if n >= 0:
			saved[n] = _domains[n].duplicate()
	return saved


func _restore_domains(saved: Dictionary) -> void:
	for n: int in saved:
		_domains[n] = saved[n]


## Unary edge rule: no exit may point off the map, except the entry slot's West exit and the
## exit slot's East exit, which are required.
func _fits_edges(slot: int, chunk: RoomChunk) -> bool:
	var cell: Vector2i = _slot_cell(slot)
	var is_entry: bool = cell.x == 0 and cell.y == _entry_row
	var is_exit: bool = cell.x == settings.columns - 1 and cell.y == _exit_row
	if cell.y == 0 and chunk.has_exit(RoomChunk.N):
		return false
	if cell.y == settings.rows - 1 and chunk.has_exit(RoomChunk.S):
		return false
	if cell.x == 0 and chunk.has_exit(RoomChunk.W) != is_entry:
		return false
	if cell.x == settings.columns - 1 and chunk.has_exit(RoomChunk.E) != is_exit:
		return false
	return true


## No more than max_consecutive_chokepoints chokepoint chunks in a row, horizontally or
## vertically, counting the assigned slots next to `slot` on both sides.
func _run_constraint_ok(slot: int, value: int) -> bool:
	if not _chunks[value].chokepoint:
		return true
	for axis: Array in [[RoomChunk.W, RoomChunk.E], [RoomChunk.N, RoomChunk.S]]:
		var run: int = 1
		for dir: int in axis:
			var n: int = _neighbour(slot, dir)
			while n >= 0 and _assignment[n] >= 0 and _chunks[_assignment[n]].chokepoint:
				run += 1
				n = _neighbour(n, dir)
		if run > settings.max_consecutive_chokepoints:
			return false
	return true


## Checks on the finished layout: hazard, player route entry -> exit, enemy spawns.
func _global_constraints_ok() -> bool:
	if settings.require_hazard:
		var any: bool = false
		for slot: int in _assignment.size():
			any = any or _chunks[_assignment[slot]].hazard
		if not any:
			return false
	var layout: Dictionary = _build_layout()
	var rows: Array[PackedStringArray] = layout["rows"]
	var player_seen: Dictionary = _bfs(rows, layout["player_spawn"], true)
	if not player_seen.has(layout["exit"]):
		return false
	return (layout["enemy_spawns"] as Array).size() >= settings.min_spawns


# --- Layout --------------------------------------------------------------------------

## Turns the assignment into terrain rows, spawns and the exit gate.
func _build_layout() -> Dictionary:
	var size: int = RoomChunk.SIZE
	var width: int = settings.columns * size
	var height: int = settings.rows * size
	var rows: Array[PackedStringArray] = []
	for y: int in height:
		var row: PackedStringArray = PackedStringArray()
		row.resize(width)
		rows.append(row)
	var candidates: Array[Vector2i] = []
	var ids: Array[String] = []
	for slot: int in _assignment.size():
		var origin: Vector2i = _slot_cell(slot) * size
		var chunk: RoomChunk = _chunks[_assignment[slot]] if _assignment[slot] >= 0 else null
		ids.append(chunk.id if chunk != null else "")
		for y: int in size:
			for x: int in size:
				rows[origin.y + y][origin.x + x] = settings.library.terrain_of(chunk.char_at(Vector2i(x, y))) if chunk != null else "wall"
		if chunk != null:
			for c: Vector2i in chunk.spawn_cells:
				candidates.append(origin + c)
	# Entry: the West opening of the entry slot is closed off (map edge); the player starts just
	# inside it. Exit: the East opening of the exit slot becomes the gate.
	var entry_open: Array[Vector2i] = RoomChunk.opening_cells(RoomChunk.W)
	var entry_origin: Vector2i = Vector2i(0, _entry_row * size)
	for c: Vector2i in entry_open:
		rows[entry_origin.y + c.y][entry_origin.x + c.x] = "wall"
	var player_spawn: Vector2i = entry_origin + Vector2i(1, 7)
	var exit_origin: Vector2i = Vector2i((settings.columns - 1) * size, _exit_row * size)
	var gates: Array[Vector2i] = []
	for c: Vector2i in RoomChunk.opening_cells(RoomChunk.E):
		gates.append(exit_origin + c)
		rows[exit_origin.y + c.y][exit_origin.x + c.x] = "gate"
	var exit_cell: Vector2i = exit_origin + Vector2i(size - 2, 7)
	# Enemy spawns: candidates far enough from the player and reachable by enemies.
	var enemy_seen: Dictionary = _bfs(rows, player_spawn, false)
	var spawns: Array[Vector2i] = []
	var behind: Array[Vector2i] = []
	for c: Vector2i in candidates:
		if not enemy_seen.has(c):
			continue
		if Vector2(c - player_spawn).length() >= settings.min_spawn_distance:
			spawns.append(c)
		elif c.x < size:
			behind.append(c)  # near the left edge: arrivals "from behind"
	return {
		"rows": rows, "chunk_ids": ids, "player_spawn": player_spawn, "exit": exit_cell,
		"gate_cells": gates, "enemy_spawns": spawns, "behind_spawns": behind,
		"entry_row": _entry_row, "exit_row": _exit_row,
	}


## Breadth-first search over the tiles from `start`. for_player: tiles the player can walk on
## (the exit gate counts as open); else tiles an enemy can enter (base cost < INF).
## Returns the set of reached cells.
func _bfs(rows: Array[PackedStringArray], start: Vector2i, for_player: bool) -> Dictionary:
	var seen: Dictionary = {start: true}
	var queue: Array[Vector2i] = [start]
	var height: int = rows.size()
	var width: int = rows[0].size()
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		for d: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
			var n: Vector2i = c + d
			if n.x < 0 or n.y < 0 or n.x >= width or n.y >= height or seen.has(n):
				continue
			if not _passable(rows[n.y][n.x], for_player):
				continue
			seen[n] = true
			queue.append(n)
	return seen


func _passable(terrain: String, for_player: bool) -> bool:
	if terrain == "gate":
		return for_player
	if for_player:
		var d: TerrainDefinition = rules.get_definition(terrain)
		return d != null and d.player_passable
	return rules.cost_of(terrain) < INF


# --- Small helpers -------------------------------------------------------------------

func _slot_cell(slot: int) -> Vector2i:
	return Vector2i(slot % settings.columns, slot / settings.columns)


## Neighbouring slot index in a direction, or -1 off the grid.
func _neighbour(slot: int, dir: int) -> int:
	var c: Vector2i = _slot_cell(slot)
	match dir:
		RoomChunk.N: c.y -= 1
		RoomChunk.E: c.x += 1
		RoomChunk.S: c.y += 1
		RoomChunk.W: c.x -= 1
	if c.x < 0 or c.y < 0 or c.x >= settings.columns or c.y >= settings.rows:
		return -1
	return c.y * settings.columns + c.x


static func _opposite(dir: int) -> int:
	match dir:
		RoomChunk.N: return RoomChunk.S
		RoomChunk.E: return RoomChunk.W
		RoomChunk.S: return RoomChunk.N
		_: return RoomChunk.E


## Seeded Fisher-Yates shuffle.
func _shuffle(values: Array) -> void:
	for i: int in range(values.size() - 1, 0, -1):
		var j: int = _rng.randi_range(0, i)
		var tmp: Variant = values[i]
		values[i] = values[j]
		values[j] = tmp


func _fail(reason: String) -> Dictionary:
	return {"ok": false, "error": reason, "layout": {}}

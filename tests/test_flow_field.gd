extends GutTest
## Tests for the shared flow field on small hand-made grids.
## Codes: . road (1), * tall_grass (2), F fence (6), # wall (blocked), T = target (road).

const SQRT2: float = 1.41421356

var _rules: TerrainCosts


func before_each() -> void:
	_rules = TerrainCosts.new()
	_rules.costs = {"road": 1.0, "tall_grass": 2.0, "fence": 6.0}
	_rules.impassable = PackedStringArray(["wall"])
	_rules.adaptations = {"climber": {"fence": 2.0}}


func _grid(lines: Array[String]) -> TerrainGrid:
	var names: Dictionary = {".": "road", "T": "road", "*": "tall_grass", "F": "fence", "#": "wall"}
	var rows: Array[PackedStringArray] = []
	for line: String in lines:
		var row: PackedStringArray = PackedStringArray()
		for c: String in line:
			row.append(names[c])
		rows.append(row)
	return TerrainGrid.from_rows(rows, _rules)


func _find_target(lines: Array[String]) -> Vector2i:
	for y: int in lines.size():
		var x: int = lines[y].find("T")
		if x >= 0:
			return Vector2i(x, y)
	return Vector2i(-1, -1)


func _field(lines: Array[String], profile_genes: Dictionary[String, float] = {}) -> FlowField:
	var g: TerrainGrid = _grid(lines)
	var field: FlowField = FlowField.new(g)
	var profile: TerrainCostProfile = g.make_profile(profile_genes) if not profile_genes.is_empty() else null
	field.build(_find_target(lines), profile)
	return field


## Every reachable cell: its arrow is a legal move, and following the arrows to the target
## costs exactly what the field says. Unreachable cells have no arrow.
func _assert_field_consistent(field: FlowField) -> void:
	var g: TerrainGrid = field.grid
	for y: int in g.height:
		for x: int in g.width:
			var cell: Vector2i = Vector2i(x, y)
			if not field.is_reachable(cell):
				assert_eq(field.get_direction(cell), Vector2.ZERO, "no arrow at unreachable %s" % cell)
				continue
			if cell == field.target:
				continue
			var next: Vector2i = field.get_next_cell(cell)
			assert_has(g.get_neighbors(cell, true, field.profile), next, "arrow at %s is a legal move" % cell)
			var walked: float = 0.0
			var path: Array[Vector2i] = field.get_path_from(cell)
			for i: int in range(1, path.size()):
				walked += g.get_step_cost(path[i - 1], path[i], field.profile)
			assert_almost_eq(walked, field.get_cost(cell), 0.0001, "arrows from %s add up to its cost" % cell)


# --- Direct route --------------------------------------------------------------------

func test_direct_route_costs_count_up_from_target() -> void:
	var field: FlowField = _field(["T...."])
	for x: int in 5:
		assert_eq(field.get_cost(Vector2i(x, 0)), float(x))
	assert_eq(field.get_direction(Vector2i(4, 0)), Vector2.LEFT)
	assert_eq(field.get_path_from(Vector2i(4, 0)), [Vector2i(4, 0), Vector2i(3, 0), Vector2i(2, 0), Vector2i(1, 0), Vector2i(0, 0)])


func test_target_has_zero_cost_and_no_arrow() -> void:
	var field: FlowField = _field(["..T.."])
	assert_eq(field.get_cost(Vector2i(2, 0)), 0.0)
	assert_eq(field.get_direction(Vector2i(2, 0)), Vector2.ZERO)
	assert_eq(field.get_next_cell(Vector2i(2, 0)), Vector2i(2, 0))


func test_open_ground_uses_diagonals() -> void:
	var field: FlowField = _field(["T...", "....", "....", "...."])
	assert_almost_eq(field.get_cost(Vector2i(3, 3)), 3.0 * SQRT2, 0.0001)
	assert_eq(field.get_next_cell(Vector2i(3, 3)), Vector2i(2, 2))
	assert_almost_eq(field.get_direction(Vector2i(3, 3)), Vector2(-1, -1).normalized(), Vector2(0.0001, 0.0001))
	_assert_field_consistent(field)


# --- Obstacle routing ----------------------------------------------------------------

func test_routes_through_gap_in_wall() -> void:
	var lines: Array[String] = [
		"..#..",
		"..#.T",
		".....",
	]
	var field: FlowField = _field(lines)
	var path: Array[Vector2i] = field.get_path_from(Vector2i(0, 0))
	assert_has(path, Vector2i(2, 2), "must pass the gap")
	for cell: Vector2i in path:
		assert_true(field.grid.is_walkable(cell))
	_assert_field_consistent(field)


func test_walls_are_unreachable() -> void:
	var field: FlowField = _field(["T#."])
	assert_eq(field.get_cost(Vector2i(1, 0)), INF)
	assert_false(field.is_reachable(Vector2i(1, 0)))


# --- Weighted terrain ----------------------------------------------------------------

func test_routes_around_expensive_fences() -> void:
	# From (0,1): straight through 3 fences = 19, around = 2 + 2*sqrt2.
	var field: FlowField = _field([
		".....",
		".FFFT",
		".....",
	])
	var path: Array[Vector2i] = field.get_path_from(Vector2i(0, 1))
	for cell: Vector2i in path:
		assert_ne(field.grid.get_terrain(cell), "fence")
	assert_almost_eq(field.get_cost(Vector2i(0, 1)), 2.0 + 2.0 * SQRT2, 0.0001)
	_assert_field_consistent(field)


func test_standing_on_fence_pays_only_for_tiles_ahead() -> void:
	# An enemy already on a fence pays for the tiles it enters next, not the fence itself.
	var field: FlowField = _field(["F.T"])
	assert_eq(field.get_cost(Vector2i(0, 0)), 2.0)
	assert_eq(field.get_cost(Vector2i(1, 0)), 1.0)


func test_entering_fence_costs_six() -> void:
	var field: FlowField = _field([".FT"])
	assert_eq(field.get_cost(Vector2i(0, 0)), 7.0, "enter fence 6 + enter target 1")


func test_climber_profile_changes_the_field() -> void:
	var lines: Array[String] = [
		".FT",
		".#.",
		"...",
	]
	var base: FlowField = _field(lines)
	assert_eq(base.get_cost(Vector2i(0, 0)), 6.0, "detour around the wall")
	assert_eq(base.get_next_cell(Vector2i(0, 0)), Vector2i(0, 1))

	var climber: FlowField = _field(lines, {"climber": 1.0})
	assert_eq(climber.get_cost(Vector2i(0, 0)), 3.0, "climb the fence: 2 + 1")
	assert_eq(climber.get_next_cell(Vector2i(0, 0)), Vector2i(1, 0))
	_assert_field_consistent(climber)


# --- Unreachable ---------------------------------------------------------------------

func test_walled_off_pocket_is_unreachable() -> void:
	var field: FlowField = _field([
		"T....",
		"..###",
		"..#..",
		"..###",
	])
	for cell: Vector2i in [Vector2i(3, 2), Vector2i(4, 2)]:
		assert_false(field.is_reachable(cell), "pocket %s" % cell)
		assert_eq(field.get_cost(cell), INF)
		assert_eq(field.get_direction(cell), Vector2.ZERO)
		assert_eq(field.get_next_cell(cell), cell)
		assert_true(field.get_path_from(cell).is_empty())
	assert_true(field.is_reachable(Vector2i(1, 3)), "outside the pocket is fine")
	_assert_field_consistent(field)


func test_target_on_wall_makes_everything_unreachable() -> void:
	var g: TerrainGrid = _grid(["..#"])
	var field: FlowField = FlowField.new(g)
	field.build(Vector2i(2, 0))
	assert_false(field.is_reachable(Vector2i(0, 0)))
	assert_eq(field.last_expanded, 0)


func test_outside_map_and_unbuilt_are_unreachable() -> void:
	var g: TerrainGrid = _grid(["T.."])
	var field: FlowField = FlowField.new(g)
	assert_false(field.is_built())
	assert_eq(field.get_cost(Vector2i(1, 0)), INF, "before build")
	field.build(Vector2i(0, 0))
	assert_eq(field.get_cost(Vector2i(-1, 0)), INF)
	assert_eq(field.get_direction(Vector2i(9, 9)), Vector2.ZERO)


# --- Direction field around an obstacle ----------------------------------------------

func test_arrows_flow_around_wall_block() -> void:
	# Target below a wall. Cells above the wall must go round the ends, never into the wall.
	var field: FlowField = _field([
		".....",
		".###.",
		"..T..",
	])
	assert_eq(field.get_direction(Vector2i(0, 0)), Vector2.DOWN, "left column runs down")
	assert_eq(field.get_direction(Vector2i(0, 1)), Vector2.DOWN)
	assert_eq(field.get_direction(Vector2i(0, 2)), Vector2.RIGHT, "bottom row runs to target")
	assert_eq(field.get_direction(Vector2i(1, 2)), Vector2.RIGHT)
	assert_eq(field.get_direction(Vector2i(4, 0)), Vector2.DOWN, "right column runs down")
	assert_eq(field.get_direction(Vector2i(3, 2)), Vector2.LEFT)
	# Top-middle has equal routes left and right: it must go sideways, not into the wall.
	var top: Vector2 = field.get_direction(Vector2i(2, 0))
	assert_eq(top.y, 0.0)
	assert_ne(top.x, 0.0)
	assert_eq(field.get_cost(Vector2i(2, 0)), 6.0)
	_assert_field_consistent(field)


func test_rebuild_moves_the_field() -> void:
	var g: TerrainGrid = _grid(["....."])
	var field: FlowField = FlowField.new(g)
	field.build(Vector2i(0, 0))
	assert_eq(field.get_direction(Vector2i(2, 0)), Vector2.LEFT)
	field.build(Vector2i(4, 0))
	assert_eq(field.get_direction(Vector2i(2, 0)), Vector2.RIGHT)
	assert_eq(field.get_cost(Vector2i(0, 0)), 4.0)


func test_world_position_lookup() -> void:
	var field: FlowField = _field(["T...."])
	assert_eq(field.get_direction_at(Vector2(4 * 16 + 3, 5)), Vector2.LEFT)


# --- Agreement with A* ---------------------------------------------------------------

func test_matches_astar_from_every_cell_on_random_grids() -> void:
	# Field cost at every cell = A* cost from that cell to the target.
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 11
	var codes: Array[String] = [".", ".", ".", "*", "F", "#"]
	for trial: int in 15:
		var lines: Array[String] = []
		for y: int in 8:
			var line: String = ""
			for x: int in 10:
				line += codes[rng.randi_range(0, codes.size() - 1)]
			lines.append(line)
		var g: TerrainGrid = _grid(lines)
		var target: Vector2i = Vector2i(rng.randi_range(0, 9), rng.randi_range(0, 7))
		var field: FlowField = FlowField.new(g)
		field.build(target)
		var astar: AStar = AStar.new(g)
		for y: int in g.height:
			for x: int in g.width:
				var cell: Vector2i = Vector2i(x, y)
				astar.find_path(cell, target)
				if astar.last_cost == INF:
					assert_false(field.is_reachable(cell), "trial %d %s" % [trial, cell])
				else:
					assert_almost_eq(field.get_cost(cell), astar.last_cost, 0.0001, "trial %d %s" % [trial, cell])
		_assert_field_consistent(field)

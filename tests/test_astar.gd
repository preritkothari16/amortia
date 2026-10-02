extends GutTest
## Tests for the hand-written A* on small hand-made grids.
## Codes: . road (1), * tall_grass (2), F fence (6), # wall (blocked).

const SQRT2: float = 1.41421356

var _rules: TerrainCosts


func before_each() -> void:
	_rules = TerrainCosts.new()
	_rules.costs = {"road": 1.0, "tall_grass": 2.0, "fence": 6.0}
	_rules.impassable = PackedStringArray(["wall"])
	_rules.adaptations = {"climber": {"fence": 2.0}}


func _grid(lines: Array[String]) -> TerrainGrid:
	var names: Dictionary = {".": "road", "*": "tall_grass", "F": "fence", "#": "wall"}
	var rows: Array[PackedStringArray] = []
	for line: String in lines:
		var row: PackedStringArray = PackedStringArray()
		for c: String in line:
			row.append(names[c])
		rows.append(row)
	return TerrainGrid.from_rows(rows, _rules)


## Checks a path is usable: right ends, every step is a legal neighbour move, and the
## step costs add up to the cost A* reported.
func _assert_valid_path(g: TerrainGrid, path: Array[Vector2i], start: Vector2i, goal: Vector2i, reported_cost: float, profile: TerrainCostProfile = null) -> void:
	assert_false(path.is_empty(), "path should exist")
	if path.is_empty():
		return
	assert_eq(path[0], start, "path starts at start")
	assert_eq(path[-1], goal, "path ends at goal")
	var total: float = 0.0
	for i: int in range(1, path.size()):
		assert_has(g.get_neighbors(path[i - 1], true, profile), path[i], "legal step %s -> %s" % [path[i - 1], path[i]])
		total += g.get_step_cost(path[i - 1], path[i], profile)
	assert_almost_eq(total, reported_cost, 0.0001, "reported cost = sum of steps")


# --- 1. Straight path ----------------------------------------------------------------

func test_straight_path() -> void:
	var g: TerrainGrid = _grid([".....", ".....", "....."])
	var astar: AStar = AStar.new(g)
	var path: Array[Vector2i] = astar.find_path(Vector2i(0, 1), Vector2i(4, 1))
	assert_eq(path, [Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1), Vector2i(4, 1)])
	assert_eq(astar.last_cost, 4.0)


func test_diagonal_path_on_open_ground() -> void:
	var g: TerrainGrid = _grid(["....", "....", "....", "...."])
	var astar: AStar = AStar.new(g)
	var path: Array[Vector2i] = astar.find_path(Vector2i(0, 0), Vector2i(3, 3))
	assert_eq(path, [Vector2i(0, 0), Vector2i(1, 1), Vector2i(2, 2), Vector2i(3, 3)])
	assert_almost_eq(astar.last_cost, 3.0 * SQRT2, 0.0001)


func test_start_equals_goal() -> void:
	var g: TerrainGrid = _grid(["..."])
	var astar: AStar = AStar.new(g)
	assert_eq(astar.find_path(Vector2i(1, 0), Vector2i(1, 0)), [Vector2i(1, 0)])
	assert_eq(astar.last_cost, 0.0)


# --- 2. Obstacle avoidance -----------------------------------------------------------

func test_goes_around_wall_through_gap() -> void:
	# Wall at x=2 with a gap only in the bottom row.
	var g: TerrainGrid = _grid([
		"..#..",
		"..#..",
		".....",
	])
	var astar: AStar = AStar.new(g)
	var start: Vector2i = Vector2i(0, 0)
	var goal: Vector2i = Vector2i(4, 0)
	var path: Array[Vector2i] = astar.find_path(start, goal)
	_assert_valid_path(g, path, start, goal, astar.last_cost)
	assert_has(path, Vector2i(2, 2), "must use the gap")
	for cell: Vector2i in path:
		assert_true(g.is_walkable(cell), "no wall cells in path")
	# Best route: diagonal, straight, straight through the gap, straight, diagonal, straight.
	# Diagonals next to the wall are blocked by the no-corner-cutting rule.
	assert_almost_eq(astar.last_cost, 4.0 + 2.0 * SQRT2, 0.0001)


func test_does_not_cut_wall_corners() -> void:
	var g: TerrainGrid = _grid([
		"..",
		"#.",
	])
	var astar: AStar = AStar.new(g)
	# (0,0) -> (1,1) diagonally would squeeze past the wall at (0,1).
	var path: Array[Vector2i] = astar.find_path(Vector2i(0, 0), Vector2i(1, 1))
	assert_eq(path, [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1)])
	assert_eq(astar.last_cost, 2.0)


# --- 3. Weighted terrain changes the route -------------------------------------------

func test_avoids_expensive_fences() -> void:
	# Straight through 3 fences costs 6+6+6+1 = 19; around via the top row costs 2 + 2*sqrt2.
	var g: TerrainGrid = _grid([
		".....",
		".FFF.",
		".....",
	])
	var astar: AStar = AStar.new(g)
	var start: Vector2i = Vector2i(0, 1)
	var goal: Vector2i = Vector2i(4, 1)
	var path: Array[Vector2i] = astar.find_path(start, goal)
	_assert_valid_path(g, path, start, goal, astar.last_cost)
	for cell: Vector2i in path:
		assert_ne(g.get_terrain(cell), "fence", "should walk around fences")
	assert_almost_eq(astar.last_cost, 2.0 + 2.0 * SQRT2, 0.0001)


func test_same_layout_without_weights_goes_straight() -> void:
	# Control for the test above: same shape, all road -> the straight line wins.
	var g: TerrainGrid = _grid([".....", ".....", "....."])
	var astar: AStar = AStar.new(g)
	var path: Array[Vector2i] = astar.find_path(Vector2i(0, 1), Vector2i(4, 1))
	assert_eq(path.size(), 5)
	assert_eq(astar.last_cost, 4.0)


func test_tall_grass_detour_only_when_cheaper() -> void:
	# Crossing 1 tile of tall grass (cost 2) beats any detour around a long patch.
	var g: TerrainGrid = _grid([
		"..*..",
		"..*..",
		"..*..",
	])
	var astar: AStar = AStar.new(g)
	var path: Array[Vector2i] = astar.find_path(Vector2i(0, 1), Vector2i(4, 1))
	assert_has(path, Vector2i(2, 1), "goes straight through the grass")
	assert_eq(astar.last_cost, 5.0)


func test_climber_profile_takes_the_fence_shortcut() -> void:
	# Base: fence route 6+1 = 7, detour around the wall = 6 -> detour.
	# Climber 1.0: fence route 2+1 = 3 -> climbs the fence.
	var g: TerrainGrid = _grid([
		".F.",
		".#.",
		"...",
	])
	var astar: AStar = AStar.new(g)
	var start: Vector2i = Vector2i(0, 0)
	var goal: Vector2i = Vector2i(2, 0)

	var base_path: Array[Vector2i] = astar.find_path(start, goal)
	_assert_valid_path(g, base_path, start, goal, astar.last_cost)
	assert_does_not_have(base_path, Vector2i(1, 0))
	assert_eq(astar.last_cost, 6.0)

	var climber: TerrainCostProfile = g.make_profile({"climber": 1.0})
	var climb_path: Array[Vector2i] = astar.find_path(start, goal, climber)
	_assert_valid_path(g, climb_path, start, goal, astar.last_cost, climber)
	assert_eq(climb_path, [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)])
	assert_eq(astar.last_cost, 3.0)


# --- 4. Unreachable target -----------------------------------------------------------

func test_walled_off_goal_returns_empty() -> void:
	var g: TerrainGrid = _grid([
		".....",
		"..###",
		"..#..",
		"..###",
	])
	var astar: AStar = AStar.new(g)
	var path: Array[Vector2i] = astar.find_path(Vector2i(0, 0), Vector2i(3, 2))
	assert_eq(path, [] as Array[Vector2i])
	assert_eq(astar.last_cost, INF)
	assert_gt(astar.last_expanded, 0, "searched before giving up")


func test_goal_on_wall_returns_empty() -> void:
	var g: TerrainGrid = _grid(["..#"])
	var astar: AStar = AStar.new(g)
	assert_true(astar.find_path(Vector2i(0, 0), Vector2i(2, 0)).is_empty())
	assert_eq(astar.last_expanded, 0, "rejected without searching")


func test_start_or_goal_outside_map_returns_empty() -> void:
	var g: TerrainGrid = _grid(["..."])
	var astar: AStar = AStar.new(g)
	assert_true(astar.find_path(Vector2i(-1, 0), Vector2i(2, 0)).is_empty())
	assert_true(astar.find_path(Vector2i(0, 0), Vector2i(9, 9)).is_empty())


func test_stats_reset_between_calls() -> void:
	var g: TerrainGrid = _grid(["..#.."])
	var astar: AStar = AStar.new(g)
	astar.find_path(Vector2i(0, 0), Vector2i(1, 0))
	assert_eq(astar.last_cost, 1.0)
	astar.find_path(Vector2i(0, 0), Vector2i(4, 0))
	assert_eq(astar.last_cost, INF)


# --- Heuristic and optimality --------------------------------------------------------

func test_octile_heuristic() -> void:
	assert_eq(AStar.octile(Vector2i(0, 0), Vector2i(0, 0)), 0.0)
	assert_eq(AStar.octile(Vector2i(0, 0), Vector2i(5, 0)), 5.0)
	assert_almost_eq(AStar.octile(Vector2i(0, 0), Vector2i(3, 3)), 3.0 * SQRT2, 0.0001)
	assert_almost_eq(AStar.octile(Vector2i(0, 0), Vector2i(5, 2)), 3.0 + 2.0 * SQRT2, 0.0001)
	assert_eq(AStar.octile(Vector2i(2, 7), Vector2i(4, 1)), AStar.octile(Vector2i(4, 1), Vector2i(2, 7)), "symmetric")


func test_heuristic_guides_search() -> void:
	# On open ground A* should expand far fewer cells than the whole map.
	var lines: Array[String] = []
	for y: int in 20:
		lines.append("....................")
	var g: TerrainGrid = _grid(lines)
	var astar: AStar = AStar.new(g)
	astar.find_path(Vector2i(0, 0), Vector2i(19, 19))
	assert_lt(astar.last_expanded, 60, "expanded %d of 400 cells" % astar.last_expanded)


func test_matches_brute_force_dijkstra_on_random_grids() -> void:
	# Optimality check: A* cost must equal a plain Dijkstra (no heuristic) on random maps.
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7
	var codes: Array[String] = [".", ".", ".", "*", "F", "#"]
	for trial: int in 40:
		var lines: Array[String] = []
		for y: int in 10:
			var line: String = ""
			for x: int in 12:
				line += codes[rng.randi_range(0, codes.size() - 1)]
			lines.append(line)
		var g: TerrainGrid = _grid(lines)
		var start: Vector2i = Vector2i(rng.randi_range(0, 11), rng.randi_range(0, 9))
		var goal: Vector2i = Vector2i(rng.randi_range(0, 11), rng.randi_range(0, 9))
		var astar: AStar = AStar.new(g)
		var path: Array[Vector2i] = astar.find_path(start, goal)
		var expected: float = _dijkstra_cost(g, start, goal)
		if expected == INF:
			assert_true(path.is_empty(), "trial %d: no path expected" % trial)
		else:
			assert_almost_eq(astar.last_cost, expected, 0.0001, "trial %d" % trial)
			_assert_valid_path(g, path, start, goal, astar.last_cost)


## Reference: slow but obviously correct Dijkstra with a linear scan for the cheapest cell.
func _dijkstra_cost(g: TerrainGrid, start: Vector2i, goal: Vector2i) -> float:
	if not g.is_walkable(start) or not g.is_walkable(goal):
		return INF
	var dist: Dictionary = {start: 0.0}
	var done: Dictionary = {}
	while true:
		var best: Variant = null
		for cell: Vector2i in dist:
			if not done.has(cell) and (best == null or dist[cell] < dist[best]):
				best = cell
		if best == null:
			return INF
		if best == goal:
			return dist[goal]
		done[best] = true
		for next: Vector2i in g.get_neighbors(best):
			var d: float = dist[best] + g.get_step_cost(best, next)
			if not dist.has(next) or d < dist[next]:
				dist[next] = d
	return INF

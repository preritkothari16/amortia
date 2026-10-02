extends GutTest
## Tests for TerrainGrid. Uses small hand-made maps, no scenes.

var _rules: TerrainCosts


func before_each() -> void:
	_rules = TerrainCosts.new()
	_rules.costs = {"road": 1.0, "grass": 1.0, "tall_grass": 2.0, "fence": 6.0}
	_rules.impassable = PackedStringArray(["wall", "deep_water"])
	_rules.adaptations = {"climber": {"fence": 2.0}, "swimmer": {"deep_water": 2.0}}


## Builds a grid from short codes: . road, , grass, * tall_grass, F fence, # wall, ~ deep_water.
func _grid(lines: Array[String]) -> TerrainGrid:
	var names: Dictionary = {".": "road", ",": "grass", "*": "tall_grass", "F": "fence", "#": "wall", "~": "deep_water"}
	var rows: Array[PackedStringArray] = []
	for line: String in lines:
		var row: PackedStringArray = PackedStringArray()
		for c: String in line:
			row.append(names[c])
		rows.append(row)
	return TerrainGrid.from_rows(rows, _rules)


func test_size_matches_rows() -> void:
	var g: TerrainGrid = _grid(["....", "...."])
	assert_eq(g.width, 4)
	assert_eq(g.height, 2)


func test_terrain_names_round_trip() -> void:
	var g: TerrainGrid = _grid([".,*F#~"])
	var expected: Array[String] = ["road", "grass", "tall_grass", "fence", "wall", "deep_water"]
	for x: int in expected.size():
		assert_eq(g.get_terrain(Vector2i(x, 0)), expected[x])


func test_base_costs_per_terrain() -> void:
	var g: TerrainGrid = _grid([".,*F#~"])
	assert_eq(g.get_cost(Vector2i(0, 0)), 1.0, "road")
	assert_eq(g.get_cost(Vector2i(1, 0)), 1.0, "grass")
	assert_eq(g.get_cost(Vector2i(2, 0)), 2.0, "tall grass")
	assert_eq(g.get_cost(Vector2i(3, 0)), 6.0, "fence")
	assert_eq(g.get_cost(Vector2i(4, 0)), INF, "wall")
	assert_eq(g.get_cost(Vector2i(5, 0)), INF, "deep water")


func test_out_of_bounds_is_impassable() -> void:
	var g: TerrainGrid = _grid(["..", ".."])
	for cell: Vector2i in [Vector2i(-1, 0), Vector2i(0, -1), Vector2i(2, 0), Vector2i(0, 2)]:
		assert_false(g.in_bounds(cell))
		assert_eq(g.get_cost(cell), INF)
		assert_false(g.is_walkable(cell))
		assert_eq(g.get_terrain(cell), "")


func test_unknown_terrain_is_impassable() -> void:
	var g: TerrainGrid = _grid(["..."])
	g.set_terrain(Vector2i(1, 0), "lava_typo")
	assert_false(g.is_walkable(Vector2i(1, 0)))
	assert_eq(g.get_terrain(Vector2i(1, 0)), "")


func test_neighbors_straight_only() -> void:
	var g: TerrainGrid = _grid(["...", "...", "..."])
	var n: Array[Vector2i] = g.get_neighbors(Vector2i(1, 1), false)
	assert_eq(n.size(), 4)
	assert_does_not_have(n, Vector2i(0, 0))


func test_neighbors_with_diagonals_in_open_field() -> void:
	var g: TerrainGrid = _grid(["...", "...", "..."])
	assert_eq(g.get_neighbors(Vector2i(1, 1)).size(), 8)
	assert_eq(g.get_neighbors(Vector2i(0, 0)).size(), 3, "corner of the map")


func test_neighbors_skip_walls() -> void:
	var g: TerrainGrid = _grid([".#.", "...", "..."])
	assert_does_not_have(g.get_neighbors(Vector2i(1, 1)), Vector2i(1, 0))


func test_no_diagonal_corner_cutting() -> void:
	# A wall in the middle: diagonals that would squeeze past its corner are not allowed.
	var g: TerrainGrid = _grid(["...", ".#.", "..."])
	var n: Array[Vector2i] = g.get_neighbors(Vector2i(0, 0))
	assert_has(n, Vector2i(1, 0))
	assert_has(n, Vector2i(0, 1))
	assert_does_not_have(n, Vector2i(1, 1), "wall itself")
	# (2,1) -> (1,0) would squeeze past the wall corner at (1,1).
	assert_does_not_have(g.get_neighbors(Vector2i(2, 1)), Vector2i(1, 0))


func test_fences_are_walkable_but_expensive() -> void:
	var g: TerrainGrid = _grid([".F."])
	assert_true(g.is_walkable(Vector2i(1, 0)))
	assert_has(g.get_neighbors(Vector2i(0, 0)), Vector2i(1, 0))


func test_step_cost_straight_and_diagonal() -> void:
	var g: TerrainGrid = _grid(["..", ".*"])
	assert_eq(g.get_step_cost(Vector2i(0, 0), Vector2i(1, 0)), 1.0)
	assert_almost_eq(g.get_step_cost(Vector2i(0, 0), Vector2i(1, 1)), 2.0 * 1.41421356, 0.0001)


func test_set_terrain_updates_cost() -> void:
	var g: TerrainGrid = _grid(["..."])
	g.set_terrain(Vector2i(1, 0), "wall")
	assert_false(g.is_walkable(Vector2i(1, 0)))
	assert_eq(g.get_terrain(Vector2i(1, 0)), "wall")
	g.set_terrain(Vector2i(1, 0), "road")
	assert_eq(g.get_cost(Vector2i(1, 0)), 1.0)


func test_climber_profile_lowers_fence_cost() -> void:
	var g: TerrainGrid = _grid([".F."])
	var climber: TerrainCostProfile = g.make_profile({"climber": 1.0})
	assert_eq(g.get_cost(Vector2i(1, 0)), 6.0, "base unchanged")
	assert_eq(g.get_cost(Vector2i(1, 0), climber), 2.0)
	assert_eq(g.get_step_cost(Vector2i(0, 0), Vector2i(1, 0), climber), 2.0)


func test_swimmer_profile_opens_deep_water() -> void:
	# Deep water splits the map: a normal mover has no way across, a swimmer does.
	var g: TerrainGrid = _grid([".~."])
	var swimmer: TerrainCostProfile = g.make_profile({"swimmer": 0.8})
	assert_does_not_have(g.get_neighbors(Vector2i(0, 0)), Vector2i(1, 0))
	assert_has(g.get_neighbors(Vector2i(0, 0), true, swimmer), Vector2i(1, 0))


func test_profile_changes_corner_cutting_too() -> void:
	# Deep water blocks the diagonal for a normal mover, but not for a swimmer who can enter it.
	var g: TerrainGrid = _grid(["..", ".~"])
	var swimmer: TerrainCostProfile = g.make_profile({"swimmer": 1.0})
	assert_eq(g.get_neighbors(Vector2i(0, 0)).size(), 2)
	assert_eq(g.get_neighbors(Vector2i(0, 0), true, swimmer).size(), 3)


func test_coords_are_attached() -> void:
	var g: TerrainGrid = _grid(["...."])
	assert_not_null(g.coords)
	assert_eq(g.coords.tile_size, 16)

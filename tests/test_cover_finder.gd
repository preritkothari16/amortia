extends GutTest
## CoverFinder (Reactive Survival V2): where a threatened Escort survivor hides. Pure grids.

var _rules: TerrainCosts


func before_each() -> void:
	_rules = load("res://data/terrain_costs.tres")


## Grid from strings: . grass, # wall, * tall grass.
func _grid(lines: Array[String]) -> TerrainGrid:
	var names: Dictionary = {".": "grass", "#": "wall", "*": "tall_grass"}
	var rows: Array[PackedStringArray] = []
	for line: String in lines:
		var row: PackedStringArray = PackedStringArray()
		for ch: String in line:
			row.append(names[ch])
		rows.append(row)
	return TerrainGrid.from_rows(rows, _rules)


func _hidden_from(g: TerrainGrid, cell: Vector2i, threat: Vector2i) -> bool:
	return not g.has_line_of_sight(g.coords.cell_to_world(threat), g.coords.cell_to_world(cell))


func test_hides_behind_a_wall_out_of_the_threats_sight() -> void:
	var g: TerrainGrid = _grid([
		"......#...",
		"......#...",
		"..........",
		"......#...",
		"......#...",
	])
	var finder: CoverFinder = CoverFinder.new()
	var threat: Vector2i = Vector2i(2, 1)
	var cell: Vector2i = finder.find(g, Vector2i(5, 2), [threat], Vector2i(5, 2))
	assert_ne(cell, CoverFinder.NONE, "there is a wall to hide behind")
	assert_true(_hidden_from(g, cell, threat), "the threat can't see the chosen cell")
	assert_gte(Vector2(cell - threat).length(), finder.min_threat_gap_cells, "not right next to the threat")
	assert_eq(finder.last_path[0], Vector2i(5, 2), "route starts at the survivor")
	assert_eq(finder.last_path[-1], cell, "and ends in the cover")
	assert_lte(finder.last_path.size() - 1, finder.max_steps)


func test_open_ground_has_no_cover() -> void:
	var g: TerrainGrid = _grid([
		"..........",
		"..........",
		"..........",
	])
	var finder: CoverFinder = CoverFinder.new()
	assert_eq(finder.find(g, Vector2i(5, 1), [Vector2i(1, 1)], Vector2i(5, 1)), CoverFinder.NONE)
	assert_eq(finder.last_path, [] as Array[Vector2i])


func test_cover_the_threat_would_reach_first_is_rejected() -> void:
	# Two grass tufts. Threat at (6,1): the far tuft (0,0) is 5 steps for the survivor but the
	# threat is nearly as close -> it would get there first; the near tuft (8,2) is next to it.
	var g: TerrainGrid = _grid([
		"*.........",
		"..........",
		"........*.",
	])
	var finder: CoverFinder = CoverFinder.new()
	assert_eq(finder.find(g, Vector2i(4, 1), [Vector2i(6, 1)], Vector2i(4, 1)), CoverFinder.NONE,
			"no cover the survivor can reach in time")
	# Threat further right: the far tuft is now safe to reach; the near one is too close to it.
	assert_eq(finder.find(g, Vector2i(4, 1), [Vector2i(9, 1)], Vector2i(4, 1)), Vector2i(0, 0))


func test_tall_grass_only_counts_when_allowed() -> void:
	var g: TerrainGrid = _grid([
		"*.........",
		"..........",
	])
	var finder: CoverFinder = CoverFinder.new()
	assert_eq(finder.find(g, Vector2i(3, 1), [Vector2i(9, 1)], Vector2i(3, 1)), Vector2i(0, 0), "grass conceals")
	finder.grass_counts = false
	assert_eq(finder.find(g, Vector2i(3, 1), [Vector2i(9, 1)], Vector2i(3, 1)), CoverFinder.NONE,
			"without grass there is nothing to hide behind")


func test_threats_on_both_sides_pick_a_cell_hidden_from_both() -> void:
	var g: TerrainGrid = _grid([
		"...........",
		"....###....",
		"....#.#....",
		"....#.#....",
		"...........",
	])
	var finder: CoverFinder = CoverFinder.new()
	var left: Vector2i = Vector2i(0, 2)
	var right: Vector2i = Vector2i(10, 2)
	var cell: Vector2i = finder.find(g, Vector2i(5, 4), [left, right], Vector2i(5, 4))
	assert_ne(cell, CoverFinder.NONE)
	assert_true(_hidden_from(g, cell, left), "hidden from the left threat")
	assert_true(_hidden_from(g, cell, right), "and from the right one")


func test_prefers_cover_near_the_player() -> void:
	# Two equally good grass tufts, left and right; the player stands on the right.
	var g: TerrainGrid = _grid([
		"*.......*",
		".........",
		".........",
		".........",
		".........",
	])
	var finder: CoverFinder = CoverFinder.new()
	var threat: Array[Vector2i] = [Vector2i(4, 4)]
	assert_eq(finder.find(g, Vector2i(4, 0), threat, Vector2i(8, 1)), Vector2i(8, 0))
	assert_eq(finder.find(g, Vector2i(4, 0), threat, Vector2i(0, 1)), Vector2i(0, 0))


func test_same_input_same_cover() -> void:
	var g: TerrainGrid = _grid([
		"......#...",
		"......#...",
		"..........",
		"......#...",
		"......#...",
	])
	var a: Vector2i = CoverFinder.new().find(g, Vector2i(5, 2), [Vector2i(2, 2)], Vector2i(5, 2))
	var b: Vector2i = CoverFinder.new().find(g, Vector2i(5, 2), [Vector2i(2, 2)], Vector2i(5, 2))
	assert_eq(a, b)

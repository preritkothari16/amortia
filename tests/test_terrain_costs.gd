extends GutTest
## Tests for TerrainCosts (the data rules) and data/terrain_costs.tres.


func test_unknown_terrain_is_impassable() -> void:
	var rules: TerrainCosts = TerrainCosts.new()
	rules.costs = {"road": 1.0}
	assert_eq(rules.cost_of("road"), 1.0)
	assert_eq(rules.cost_of("lava_typo"), INF)


func test_impassable_wins_over_cost() -> void:
	var rules: TerrainCosts = TerrainCosts.new()
	rules.costs = {"wall": 1.0}
	rules.impassable = PackedStringArray(["wall"])
	assert_eq(rules.cost_of("wall"), INF)


func test_terrain_names_cover_every_source_and_are_sorted() -> void:
	var rules: TerrainCosts = TerrainCosts.new()
	rules.costs = {"road": 1.0, "fence": 6.0}
	rules.impassable = PackedStringArray(["wall"])
	rules.adaptations = {"crawler": {"vent": 1.0}}
	assert_eq(rules.get_terrain_names(), PackedStringArray(["fence", "road", "vent", "wall"]))


func test_data_file_matches_design_doc() -> void:
	var data: TerrainCosts = load("res://data/terrain_costs.tres")
	# GDD 4.2, "Move cost (enemy path)" column.
	var expected: Dictionary = {
		"road": 1.0, "grass": 1.0, "tall_grass": 2.0, "mud": 3.0, "shallow_water": 3.0,
		"fence": 6.0, "barricade": 5.0, "door": 2.0, "bridge": 1.0, "fog": 1.0,
		"toxic_pool": 8.0, "fire": 20.0,
		"wall": INF, "house": INF, "deep_water": INF, "vent": INF,
	}
	for terrain: String in expected:
		assert_eq(data.cost_of(terrain), expected[terrain], terrain)


func test_data_file_adaptations_match_design_doc() -> void:
	var data: TerrainCosts = load("res://data/terrain_costs.tres")
	assert_eq(data.adaptations["climber"]["fence"], 2.0)
	assert_eq(data.adaptations["swimmer"]["shallow_water"], 1.0)
	assert_eq(data.adaptations["swimmer"]["deep_water"], 2.0)
	assert_eq(data.adaptations["crawler"]["vent"], 1.0)
	assert_eq(data.adaptations["toxin_resistance"]["toxic_pool"], 2.0)


func test_every_maple_hollow_terrain_is_known() -> void:
	var data: TerrainCosts = load("res://data/terrain_costs.tres")
	var names: PackedStringArray = data.get_terrain_names()
	for terrain: String in ["road", "grass", "tall_grass", "fence", "wall", "house"]:
		assert_true(names.has(terrain), terrain)

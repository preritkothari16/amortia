extends GutTest
## Tests for TerrainCostProfile: how terrain genes turn into per-terrain costs.

var _rules: TerrainCosts


func before_each() -> void:
	_rules = TerrainCosts.new()
	_rules.costs = {"road": 1.0, "fence": 6.0, "shallow_water": 3.0}
	_rules.impassable = PackedStringArray(["wall", "deep_water", "vent"])
	_rules.adaptations = {
		"climber": {"fence": 2.0},
		"swimmer": {"shallow_water": 1.0, "deep_water": 2.0},
		"crawler": {"vent": 1.0},
	}
	_rules.unlock_threshold = 0.5


func test_base_profile_equals_rules() -> void:
	var p: TerrainCostProfile = TerrainCostProfile.create(_rules)
	assert_eq(p.label, "base")
	for terrain: String in _rules.get_terrain_names():
		assert_eq(p.cost_of(terrain), _rules.cost_of(terrain), terrain)


func test_gene_lerps_passable_cost() -> void:
	# fence: base 6, fully adapted 2. gene 0.5 -> halfway = 4.
	assert_eq(TerrainCostProfile.create(_rules, {"climber": 0.0}).cost_of("fence"), 6.0)
	assert_eq(TerrainCostProfile.create(_rules, {"climber": 0.5}).cost_of("fence"), 4.0)
	assert_eq(TerrainCostProfile.create(_rules, {"climber": 1.0}).cost_of("fence"), 2.0)


func test_gene_only_touches_its_own_terrain() -> void:
	var p: TerrainCostProfile = TerrainCostProfile.create(_rules, {"climber": 1.0})
	assert_eq(p.cost_of("road"), 1.0)
	assert_eq(p.cost_of("shallow_water"), 3.0)
	assert_eq(p.cost_of("wall"), INF, "no gene ever opens walls")


func test_impassable_terrain_needs_threshold() -> void:
	assert_eq(TerrainCostProfile.create(_rules, {"swimmer": 0.49}).cost_of("deep_water"), INF)
	assert_eq(TerrainCostProfile.create(_rules, {"swimmer": 0.5}).cost_of("deep_water"), 2.0)
	assert_eq(TerrainCostProfile.create(_rules, {"crawler": 0.9}).cost_of("vent"), 1.0)


func test_genes_are_clamped() -> void:
	assert_eq(TerrainCostProfile.create(_rules, {"climber": 3.0}).cost_of("fence"), 2.0)
	assert_eq(TerrainCostProfile.create(_rules, {"climber": -1.0}).cost_of("fence"), 6.0)


func test_unknown_trait_is_ignored() -> void:
	var p: TerrainCostProfile = TerrainCostProfile.create(_rules, {"night_sense": 1.0})
	assert_eq(p.cost_of("fence"), 6.0)


func test_cheapest_adaptation_wins() -> void:
	_rules.adaptations["swimmer"]["fence"] = 5.0
	var p: TerrainCostProfile = TerrainCostProfile.create(_rules, {"climber": 1.0, "swimmer": 1.0})
	assert_eq(p.cost_of("fence"), 2.0)


func test_min_cost() -> void:
	assert_eq(TerrainCostProfile.create(_rules).get_min_cost(), 1.0)
	_rules.costs["road"] = 2.0
	_rules.adaptations["swimmer"]["shallow_water"] = 0.5
	assert_eq(TerrainCostProfile.create(_rules).get_min_cost(), 2.0, "walls (INF) ignored")
	assert_eq(TerrainCostProfile.create(_rules, {"swimmer": 1.0}).get_min_cost(), 0.5, "adapted cost counts")


func test_unknown_ids_are_impassable() -> void:
	var p: TerrainCostProfile = TerrainCostProfile.create(_rules)
	assert_eq(p.cost_of_id(-1), INF)
	assert_eq(p.cost_of_id(999), INF)
	assert_eq(p.cost_of("lava_typo"), INF)

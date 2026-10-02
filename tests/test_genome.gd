extends GutTest
## Tests for Genome and GenomeRules.

var _rules: GenomeRules
var _rng: RandomNumberGenerator


func before_each() -> void:
	_rules = GenomeRules.new()  # defaults = GDD values (1..10, budget 15 +1/wave, max 24)
	_rng = RandomNumberGenerator.new()
	_rng.seed = 1234


func _genome(spd: float, hp: float, vis: float) -> Genome:
	var g: Genome = Genome.new()
	g.speed = spd
	g.health = hp
	g.vision = vis
	return g


# --- Rules ---------------------------------------------------------------------------

func test_budget_per_wave() -> void:
	assert_eq(_rules.budget_for_wave(1), 15)
	assert_eq(_rules.budget_for_wave(2), 16)
	assert_eq(_rules.budget_for_wave(10), 24)
	assert_eq(_rules.budget_for_wave(50), 24, "capped")
	assert_eq(_rules.budget_for_wave(0), 15, "treated as the first wave")


func test_data_file_matches_gdd() -> void:
	var r: GenomeRules = load("res://data/genome_rules.tres")
	assert_eq(r.stat_min, 1.0)
	assert_eq(r.stat_max, 10.0)
	assert_eq(r.budget_start, 15)
	assert_eq(r.budget_max, 24)
	assert_almost_eq(r.mutation_rate, 0.1, 0.0001)


# --- Random --------------------------------------------------------------------------

func test_random_genomes_are_valid_and_spend_the_budget() -> void:
	for budget: int in [15, 20, 24]:
		for i: int in 200:
			var g: Genome = Genome.random(_rng, _rules, budget)
			assert_true(g.is_valid(_rules, budget), g.describe())
			assert_almost_eq(g.stat_total(), float(budget), 0.001, "spends exactly the budget")


func test_random_respects_stat_max_with_overflow() -> void:
	# Budget 24 with one huge weight: that stat caps at 10, the rest goes to the others.
	var g: Genome = Genome.new()
	var weights: Array[float] = [100.0, 1.0, 1.0]
	g._spend_budget(weights, _rules, 24)
	assert_eq(g.speed, 10.0)
	assert_almost_eq(g.stat_total(), 24.0, 0.001)
	assert_almost_eq(g.health, g.vision, 0.001, "overflow shared by equal weights")


func test_random_is_reproducible_with_seed() -> void:
	var a: RandomNumberGenerator = RandomNumberGenerator.new()
	var b: RandomNumberGenerator = RandomNumberGenerator.new()
	a.seed = 99
	b.seed = 99
	assert_eq(Genome.random(a, _rules, 15).to_dict(), Genome.random(b, _rules, 15).to_dict())


func test_random_genomes_vary() -> void:
	var first: Dictionary = Genome.random(_rng, _rules, 15).to_dict()
	var different: bool = false
	for i: int in 10:
		if Genome.random(_rng, _rules, 15).to_dict() != first:
			different = true
	assert_true(different)


# --- Copy ----------------------------------------------------------------------------

func test_copy_is_independent() -> void:
	var a: Genome = Genome.random(_rng, _rules, 15)
	var b: Genome = a.copy()
	assert_eq(a.to_dict(), b.to_dict())
	b.speed = 1.0
	b.aggression = 0.0
	b.path_mode = Genome.PathMode.GREEDY if a.path_mode != Genome.PathMode.GREEDY else Genome.PathMode.FLOW
	assert_ne(a.to_dict(), b.to_dict(), "changing the copy left the original alone")


# --- Mutation ------------------------------------------------------------------------

func test_mutation_rate_zero_changes_nothing() -> void:
	var g: Genome = Genome.random(_rng, _rules, 15)
	var before: Dictionary = g.to_dict()
	assert_eq(g.mutate(_rng, _rules, 15, 0.0), 0)
	assert_eq(g.to_dict(), before)


func test_mutation_rate_one_changes_every_gene() -> void:
	var g: Genome = Genome.random(_rng, _rules, 15)
	var before: Genome = g.copy()
	assert_eq(g.mutate(_rng, _rules, 15, 1.0), 9, "3 stats + 5 behaviour + path_mode")
	assert_ne(g.path_mode, before.path_mode, "category re-picked to a DIFFERENT value")
	var behaviour_changed: int = 0
	for gene: StringName in Genome.BEHAVIOUR_GENES:
		if not is_equal_approx(g.get(gene), before.get(gene)):
			behaviour_changed += 1
	assert_gte(behaviour_changed, 3, "nudges (a few may clamp to the same edge)")


func test_default_rate_mutates_about_ten_percent() -> void:
	var total: int = 0
	for i: int in 500:
		total += Genome.random(_rng, _rules, 15).mutate(_rng, _rules, 15)
	var per_gene: float = total / (500.0 * 9.0)
	assert_between(per_gene, 0.07, 0.13, "observed rate %.3f" % per_gene)


func test_mutated_genomes_stay_valid() -> void:
	var g: Genome = Genome.random(_rng, _rules, 15)
	for i: int in 1000:
		g.mutate(_rng, _rules, 15, 0.5)
		assert_true(g.is_valid(_rules, 15), g.describe())


func test_behaviour_nudge_is_small() -> void:
	var g: Genome = Genome.new()
	var max_jump: float = 0.0
	for i: int in 300:
		var before: float = g.aggression
		g.mutate(_rng, _rules, 15, 1.0)
		max_jump = maxf(max_jump, absf(g.aggression - before))
		g.aggression = 0.5
	assert_lt(max_jump, 0.5, "sigma 0.1: nudges, not re-rolls")


# --- Repair / budget -----------------------------------------------------------------

func test_repair_clamps_ranges() -> void:
	var g: Genome = _genome(-3.0, 4.0, 4.0)
	g.aggression = 1.7
	g.patience = -0.2
	g.repair(_rules, 24)
	assert_eq(g.speed, 1.0)
	assert_eq(g.aggression, 1.0)
	assert_eq(g.patience, 0.0)


func test_repair_scales_over_budget_keeping_ratios() -> void:
	# 10 + 7 + 4 = 21 > 15. Points above the minimum: 9, 6, 3 (sum 18) must shrink to 12.
	var g: Genome = _genome(10.0, 7.0, 4.0)
	g.repair(_rules, 15)
	assert_almost_eq(g.stat_total(), 15.0, 0.001)
	assert_almost_eq(g.speed, 7.0, 0.001)
	assert_almost_eq(g.health, 5.0, 0.001)
	assert_almost_eq(g.vision, 3.0, 0.001)


func test_repair_leaves_under_budget_alone() -> void:
	var g: Genome = _genome(3.0, 3.0, 3.0)
	g.repair(_rules, 15)
	assert_eq(g.stat_total(), 9.0, "spending less than the budget is allowed")


func test_is_valid() -> void:
	assert_true(_genome(5, 5, 5).is_valid(_rules, 15))
	assert_false(_genome(6, 5, 5).is_valid(_rules, 15), "over budget")
	assert_false(_genome(0.5, 5, 5).is_valid(_rules, 15), "below stat_min")
	var g: Genome = _genome(5, 5, 5)
	g.cohesion = 1.5
	assert_false(g.is_valid(_rules, 15), "behaviour out of range")


# --- Gene -> enemy values ------------------------------------------------------------

func test_neutral_gene_gives_base_value() -> void:
	var g: Genome = _genome(5, 5, 5)
	assert_almost_eq(g.move_speed(70.0, _rules), 70.0, 0.001)
	assert_almost_eq(g.max_health(30.0, _rules), 30.0, 0.001)
	assert_almost_eq(g.sight_range(160.0, _rules), 160.0, 0.001)


func test_stat_mapping_ranges() -> void:
	assert_almost_eq(_genome(1, 5, 5).move_speed(70.0, _rules), 42.0, 0.001, "speed 1: -40 %")
	assert_almost_eq(_genome(10, 5, 5).move_speed(70.0, _rules), 105.0, 0.001, "speed 10: +50 %")
	assert_almost_eq(_genome(5, 1, 5).max_health(30.0, _rules), 12.0, 0.001)
	assert_almost_eq(_genome(5, 10, 5).max_health(30.0, _rules), 52.5, 0.001)
	assert_almost_eq(_genome(5, 5, 10).sight_range(160.0, _rules), 240.0, 0.001)


func test_behaviour_weights_copied() -> void:
	var g: Genome = Genome.random(_rng, _rules, 15)
	var w: BehaviourWeights = g.to_behaviour_weights()
	for gene: StringName in Genome.BEHAVIOUR_GENES:
		assert_eq(w.get(gene), g.get(gene), String(gene))


# --- Serialization -------------------------------------------------------------------

func test_dict_round_trip() -> void:
	var g: Genome = Genome.random(_rng, _rules, 18)
	var back: Genome = Genome.from_dict(g.to_dict())
	assert_eq(back.to_dict(), g.to_dict())
	assert_eq(g.to_dict()["path_mode"], Genome.PathMode.keys()[g.path_mode], "readable category name")


func test_json_round_trip() -> void:
	var g: Genome = Genome.random(_rng, _rules, 18)
	var text: String = JSON.stringify(g.to_dict())
	var back: Genome = Genome.from_dict(JSON.parse_string(text))
	for gene: StringName in Genome.STAT_GENES + Genome.BEHAVIOUR_GENES:
		assert_almost_eq(back.get(gene), g.get(gene), 0.000001, String(gene))
	assert_eq(back.path_mode, g.path_mode)


func test_resource_save_and_load() -> void:
	var g: Genome = Genome.random(_rng, _rules, 18)
	var path: String = "user://test_genome_roundtrip.tres"
	assert_eq(ResourceSaver.save(g, path), OK)
	var back: Genome = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as Genome
	assert_not_null(back)
	# .tres stores floats as text, which may round the last digits: compare with a tolerance.
	for gene: StringName in Genome.STAT_GENES + Genome.BEHAVIOUR_GENES:
		assert_almost_eq(back.get(gene), g.get(gene), 0.000001, String(gene))
	assert_eq(back.path_mode, g.path_mode)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_describe_is_readable() -> void:
	var g: Genome = _genome(6.24, 4.1, 4.66)
	g.path_mode = Genome.PathMode.ASTAR
	var text: String = g.describe()
	assert_string_contains(text, "spd 6.2")
	assert_string_contains(text, "hp 4.1")
	assert_string_contains(text, "ASTAR")
	assert_string_contains(str(g), "Genome(")

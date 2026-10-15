extends GutTest
## Tests for Genome and GenomeRules (four budgeted stats: speed, health, vision, ferocity).

var _rules: GenomeRules
var _rng: RandomNumberGenerator


func before_each() -> void:
	_rules = GenomeRules.new()  # defaults = data/genome_rules.tres (1..10, budget 20 +1/wave, max 32)
	_rng = RandomNumberGenerator.new()
	_rng.seed = 1234


func _genome(spd: float, hp: float, vis: float, fer: float = 5.0) -> Genome:
	var g: Genome = Genome.new()
	g.speed = spd
	g.health = hp
	g.vision = vis
	g.ferocity = fer
	return g


# --- Rules ---------------------------------------------------------------------------

func test_budget_per_wave() -> void:
	assert_eq(_rules.budget_for_wave(1), 20)
	assert_eq(_rules.budget_for_wave(2), 21)
	assert_eq(_rules.budget_for_wave(13), 32)
	assert_eq(_rules.budget_for_wave(50), 32, "capped")
	assert_eq(_rules.budget_for_wave(0), 20, "treated as the first wave")


func test_budget_starts_at_four_neutral_stats() -> void:
	assert_eq(_rules.budget_start, int(_rules.stat_neutral) * Genome.STAT_GENES.size(),
			"an average enemy = the archetype's base values")
	assert_eq(Genome.STAT_GENES.size(), 4)


func test_data_file_matches_rules() -> void:
	var r: GenomeRules = load("res://data/genome_rules.tres")
	assert_eq(r.stat_min, 1.0)
	assert_eq(r.stat_max, 10.0)
	assert_eq(r.budget_start, 20)
	assert_eq(r.budget_max, 32)
	assert_eq(r.budget_per_wave, 1)
	assert_almost_eq(r.mutation_rate, 0.1, 0.0001)
	assert_almost_eq(r.ferocity_damage_per_point, 0.08, 0.0001)
	assert_almost_eq(r.ferocity_cooldown_per_point, 0.04, 0.0001)
	assert_almost_eq(r.attack_cooldown_min, 0.5, 0.0001)


func test_removed_genes_are_gone() -> void:
	var names: Array[String] = []
	for p: Dictionary in Genome.new().get_property_list():
		names.append(p["name"])
	assert_false(names.has("caution"))
	assert_false(names.has("path_mode"))
	assert_false(Genome.BEHAVIOUR_GENES.has(&"caution"))
	assert_true(Genome.STAT_GENES.has(&"ferocity"))


# --- Random --------------------------------------------------------------------------

func test_random_genomes_are_valid_and_spend_the_budget() -> void:
	for budget: int in [20, 26, 32]:
		for i: int in 200:
			var g: Genome = Genome.random(_rng, _rules, budget)
			assert_true(g.is_valid(_rules, budget), g.describe())
			assert_almost_eq(g.stat_total(), float(budget), 0.001, "spends exactly the budget")


func test_random_respects_stat_max_with_overflow() -> void:
	# Budget 32 with one huge weight: that stat caps at 10, the rest goes to the others.
	var g: Genome = Genome.new()
	var weights: Array[float] = [100.0, 1.0, 1.0, 1.0]
	g._spend_budget(weights, _rules, 32)
	assert_eq(g.speed, 10.0)
	assert_almost_eq(g.stat_total(), 32.0, 0.001)
	assert_almost_eq(g.health, g.vision, 0.001, "overflow shared by equal weights")
	assert_almost_eq(g.health, g.ferocity, 0.001)


func test_random_is_reproducible_with_seed() -> void:
	var a: RandomNumberGenerator = RandomNumberGenerator.new()
	var b: RandomNumberGenerator = RandomNumberGenerator.new()
	a.seed = 99
	b.seed = 99
	assert_eq(Genome.random(a, _rules, 20).to_dict(), Genome.random(b, _rules, 20).to_dict())


func test_random_genomes_vary() -> void:
	var first: Dictionary = Genome.random(_rng, _rules, 20).to_dict()
	var different: bool = false
	for i: int in 10:
		if Genome.random(_rng, _rules, 20).to_dict() != first:
			different = true
	assert_true(different)


func test_random_ferocity_is_spread_over_its_range() -> void:
	var low: int = 0
	var high: int = 0
	for i: int in 300:
		var f: float = Genome.random(_rng, _rules, 20).ferocity
		low += 1 if f < 4.0 else 0
		high += 1 if f > 6.0 else 0
	assert_gt(low, 20, "some random enemies are gentle")
	assert_gt(high, 20, "some random enemies are savage")


# --- Copy ----------------------------------------------------------------------------

func test_copy_is_independent() -> void:
	var a: Genome = Genome.random(_rng, _rules, 20)
	var b: Genome = a.copy()
	assert_eq(a.to_dict(), b.to_dict())
	b.speed = 1.0
	b.aggression = 0.0
	b.ferocity = 9.0 if a.ferocity < 9.0 else 2.0
	assert_ne(a.to_dict(), b.to_dict(), "changing the copy left the original alone")


# --- Mutation ------------------------------------------------------------------------

func test_mutation_rate_zero_changes_nothing() -> void:
	var g: Genome = Genome.random(_rng, _rules, 20)
	var before: Dictionary = g.to_dict()
	assert_eq(g.mutate(_rng, _rules, 20, 0.0), 0)
	assert_eq(g.to_dict(), before)


func test_mutation_rate_one_changes_every_gene() -> void:
	var g: Genome = Genome.random(_rng, _rules, 20)
	var before: Genome = g.copy()
	assert_eq(g.mutate(_rng, _rules, 20, 1.0), 13, "4 stats + 4 behaviour + 5 terrain")
	var behaviour_changed: int = 0
	for gene: StringName in Genome.BEHAVIOUR_GENES:
		if not is_equal_approx(g.get(gene), before.get(gene)):
			behaviour_changed += 1
	assert_gte(behaviour_changed, 2, "nudges (a few may clamp to the same edge)")


func test_default_rate_mutates_about_ten_percent() -> void:
	var total: int = 0
	for i: int in 500:
		total += Genome.random(_rng, _rules, 20).mutate(_rng, _rules, 20)
	var per_gene: float = total / (500.0 * 13.0)  # 4 stats + 4 behaviour + 5 terrain
	assert_between(per_gene, 0.07, 0.13, "observed rate %.3f" % per_gene)


func test_mutated_genomes_stay_valid() -> void:
	var g: Genome = Genome.random(_rng, _rules, 20)
	for i: int in 1000:
		g.mutate(_rng, _rules, 20, 0.5)
		assert_true(g.is_valid(_rules, 20), g.describe())
		assert_true(g.spends_budget(_rules, 20), "mutation repairs to exactly the budget")


func test_behaviour_nudge_is_small() -> void:
	var g: Genome = Genome.new()
	var max_jump: float = 0.0
	for i: int in 300:
		var before: float = g.aggression
		g.mutate(_rng, _rules, 20, 1.0)
		max_jump = maxf(max_jump, absf(g.aggression - before))
		g.aggression = 0.5
	assert_lt(max_jump, 0.5, "sigma 0.1: nudges, not re-rolls")


# --- Repair / budget -----------------------------------------------------------------

func test_repair_clamps_ranges() -> void:
	var g: Genome = _genome(-3.0, 4.0, 4.0, 4.0)
	g.aggression = 1.7
	g.patience = -0.2
	g.repair(_rules, 13)  # 1 + 4 + 4 + 4 after clamping = exactly the budget
	assert_eq(g.speed, 1.0)
	assert_eq(g.aggression, 1.0)
	assert_eq(g.patience, 0.0)


func test_repair_scales_over_budget_keeping_ratios() -> void:
	# 10 + 7 + 4 + 4 = 25 > 20. Points above the minimum: 9, 6, 3, 3 (sum 21) must shrink to 16.
	var g: Genome = _genome(10.0, 7.0, 4.0, 4.0)
	g.repair(_rules, 20)
	assert_almost_eq(g.stat_total(), 20.0, 0.001)
	assert_almost_eq(g.speed - 1.0, 9.0 * 16.0 / 21.0, 0.001)
	assert_almost_eq(g.health - 1.0, 6.0 * 16.0 / 21.0, 0.001)
	assert_almost_eq(g.vision - 1.0, 3.0 * 16.0 / 21.0, 0.001)
	assert_almost_eq(g.ferocity - 1.0, 3.0 * 16.0 / 21.0, 0.001)


func test_repair_tops_up_under_budget_keeping_ratios() -> void:
	# 3 + 5 + 2 + 2 = 12 < 21. Shares above the minimum 2, 4, 1, 1 (sum 8) must grow to 17.
	var g: Genome = _genome(3.0, 5.0, 2.0, 2.0)
	g.repair(_rules, 21)
	assert_almost_eq(g.stat_total(), 21.0, 0.001, "the budget must be spent")
	assert_almost_eq(g.speed - 1.0, 2.0 * 17.0 / 8.0, 0.001)
	assert_almost_eq(g.health - 1.0, 4.0 * 17.0 / 8.0, 0.001)
	assert_almost_eq(g.ferocity - 1.0, 1.0 * 17.0 / 8.0, 0.001)
	assert_true(g.spends_budget(_rules, 21))


func test_top_up_spreads_points_not_one_stat() -> void:
	var g: Genome = _genome(6.0, 5.0, 4.0, 5.0)  # 20 = wave 1 budget
	g.repair(_rules, 32)
	for gene: StringName in Genome.STAT_GENES:
		assert_gt(g.get(gene), _genome(6.0, 5.0, 4.0, 5.0).get(gene), "%s got some of the 12 new points" % gene)
	assert_almost_eq(g.stat_total(), 32.0, 0.001)


func test_top_up_caps_at_stat_max_and_passes_overflow_on() -> void:
	var g: Genome = _genome(9.0, 2.0, 1.0, 1.0)  # shares 8, 1, 0, 0
	g.repair(_rules, 32)
	assert_eq(g.speed, 10.0)
	assert_almost_eq(g.stat_total(), 32.0, 0.001)
	assert_true(g.is_valid(_rules, 32))


func test_top_up_overflow_to_zero_share_stats() -> void:
	# speed and health fill to 10; the rest must go to vision and ferocity (shares 0).
	var g: Genome = _genome(9.0, 9.0, 1.0, 1.0)
	g.repair(_rules, 30)
	assert_eq(g.speed, 10.0)
	assert_eq(g.health, 10.0)
	assert_almost_eq(g.vision, 5.0, 0.001)
	assert_almost_eq(g.ferocity, 5.0, 0.001)


func test_all_at_minimum_split_evenly() -> void:
	var g: Genome = _genome(1.0, 1.0, 1.0, 1.0)
	g.repair(_rules, 20)
	for gene: StringName in Genome.STAT_GENES:
		assert_almost_eq(g.get(gene), 5.0, 0.001, String(gene))


func test_exact_genome_left_bit_identical() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 3
	var g: Genome = Genome.random(rng, _rules, 22)
	var before: Dictionary = g.to_dict()
	g.repair(_rules, 22)
	assert_eq(g.to_dict(), before)


func test_spends_budget() -> void:
	assert_true(_genome(5.0, 5.0, 5.0, 5.0).spends_budget(_rules, 20))
	assert_false(_genome(4.0, 5.0, 5.0, 5.0).spends_budget(_rules, 20))
	assert_true(_genome(10.0, 10.0, 10.0, 10.0).spends_budget(_rules, 99), "budget above 40 -> 40 is the most possible")


func test_is_valid() -> void:
	assert_true(_genome(5, 5, 5, 5).is_valid(_rules, 20))
	assert_false(_genome(6, 5, 5, 5).is_valid(_rules, 20), "over budget")
	assert_false(_genome(0.5, 5, 5, 5).is_valid(_rules, 20), "below stat_min")
	assert_false(_genome(5, 5, 5, 11).is_valid(_rules, 99), "ferocity above stat_max")
	var g: Genome = _genome(5, 5, 5, 5)
	g.cohesion = 1.5
	assert_false(g.is_valid(_rules, 20), "behaviour out of range")


# --- Gene -> enemy values ------------------------------------------------------------

func test_neutral_gene_gives_base_value() -> void:
	var g: Genome = _genome(5, 5, 5, 5)
	assert_almost_eq(g.move_speed(70.0, _rules), 70.0, 0.001)
	assert_almost_eq(g.max_health(30.0, _rules), 30.0, 0.001)
	assert_almost_eq(g.sight_range(160.0, _rules), 160.0, 0.001)
	assert_almost_eq(g.attack_damage(8.0, _rules), 8.0, 0.001)
	assert_almost_eq(g.attack_cooldown(1.2, _rules), 1.2, 0.001)
	assert_almost_eq(g.melee_dps_factor(_rules), 1.0, 0.001)


func test_stat_mapping_ranges() -> void:
	assert_almost_eq(_genome(1, 5, 5).move_speed(70.0, _rules), 42.0, 0.001, "speed 1: -40 %")
	assert_almost_eq(_genome(10, 5, 5).move_speed(70.0, _rules), 105.0, 0.001, "speed 10: +50 %")
	assert_almost_eq(_genome(5, 1, 5).max_health(30.0, _rules), 12.0, 0.001)
	assert_almost_eq(_genome(5, 10, 5).max_health(30.0, _rules), 52.5, 0.001)
	assert_almost_eq(_genome(5, 5, 10).sight_range(160.0, _rules), 240.0, 0.001)


func test_ferocity_mapping_values() -> void:
	var top: Genome = _genome(5, 5, 5, 10.0)
	assert_almost_eq(top.attack_damage(8.0, _rules), 11.2, 0.001, "gene 10: x1.40")
	assert_almost_eq(top.attack_cooldown(1.2, _rules), 0.96, 0.001, "gene 10: x0.80")
	var bottom: Genome = _genome(5, 5, 5, 1.0)
	assert_almost_eq(bottom.attack_damage(8.0, _rules), 8.0 * 0.68, 0.001, "gene 1: x0.68")
	assert_almost_eq(bottom.attack_cooldown(1.2, _rules), 1.2 * 1.16, 0.001, "gene 1: x1.16")


func test_ferocity_trade_off_is_no_cheaper_than_health() -> void:
	# +5 points of ferocity gives the same damage-per-second gain as +5 points of health gives hit points.
	var fierce: float = _genome(5, 5, 5, 10.0).melee_dps_factor(_rules)
	var tough: float = _genome(5, 10, 5, 5.0).max_health(1.0, _rules)
	assert_almost_eq(fierce, 1.75, 0.001)
	assert_almost_eq(tough, 1.75, 0.001)
	assert_lte(fierce, tough + 0.0001, "ferocity is never a free upgrade over health")


func test_attack_cooldown_never_below_the_floor() -> void:
	_rules.attack_cooldown_min = 1.0
	assert_almost_eq(_genome(5, 5, 5, 10.0).attack_cooldown(1.2, _rules), 1.0, 0.0001)


func test_ferocity_is_paid_for_by_the_other_stats() -> void:
	# Raising ferocity under a fixed budget must lower something else.
	var g: Genome = _genome(5, 5, 5, 5)
	g.ferocity = 9.0
	g.repair(_rules, 20)
	assert_almost_eq(g.stat_total(), 20.0, 0.001)
	assert_lt(g.speed + g.health + g.vision, 15.0, "the points came out of speed / health / vision")


func test_behaviour_weights_copied() -> void:
	var g: Genome = Genome.random(_rng, _rules, 20)
	var w: BehaviourWeights = g.to_behaviour_weights()
	for gene: StringName in Genome.BEHAVIOUR_GENES:
		assert_eq(w.get(gene), g.get(gene), String(gene))


# --- Serialization -------------------------------------------------------------------

func test_dict_round_trip() -> void:
	var g: Genome = Genome.random(_rng, _rules, 23)
	var back: Genome = Genome.from_dict(g.to_dict())
	assert_eq(back.to_dict(), g.to_dict())
	assert_false(g.to_dict().has("path_mode"))
	assert_false(g.to_dict().has("caution"))
	assert_true(g.to_dict().has("ferocity"))


func test_old_dict_with_removed_genes_and_no_ferocity_loads() -> void:
	var old: Dictionary = {"speed": 6.0, "health": 5.0, "vision": 4.0, "aggression": 0.7, "caution": 0.9,
		"flanking": 0.3, "cohesion": 0.4, "patience": 0.2, "path_mode": "ASTAR"}
	var g: Genome = Genome.from_dict(old)
	assert_eq(g.speed, 6.0)
	assert_eq(g.health, 5.0)
	assert_eq(g.vision, 4.0)
	assert_eq(g.ferocity, 5.0, "missing ferocity = neutral")
	assert_eq(g.aggression, 0.7)
	assert_almost_eq(g.stat_total(), 20.0, 0.0001, "old wave-1 total 15 + neutral 5 = the new wave-1 budget")
	assert_eq(g.swimmer, 0.0)


func test_json_round_trip() -> void:
	var g: Genome = Genome.random(_rng, _rules, 24)
	var text: String = JSON.stringify(g.to_dict())
	var back: Genome = Genome.from_dict(JSON.parse_string(text))
	for gene: StringName in Genome.STAT_GENES + Genome.BEHAVIOUR_GENES:
		assert_almost_eq(back.get(gene), g.get(gene), 0.000001, String(gene))


func test_resource_save_and_load() -> void:
	var g: Genome = Genome.random(_rng, _rules, 24)
	var path: String = "user://test_genome_roundtrip.tres"
	assert_eq(ResourceSaver.save(g, path), OK)
	var back: Genome = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as Genome
	assert_not_null(back)
	# .tres stores floats as text, which may round the last digits: compare with a tolerance.
	for gene: StringName in Genome.STAT_GENES + Genome.BEHAVIOUR_GENES:
		assert_almost_eq(back.get(gene), g.get(gene), 0.000001, String(gene))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_describe_is_readable() -> void:
	var g: Genome = _genome(6.24, 4.1, 4.66, 3.2)
	var text: String = g.describe()
	assert_string_contains(text, "spd 6.2")
	assert_string_contains(text, "hp 4.1")
	assert_string_contains(text, "fer 3.2")
	assert_string_contains(str(g), "Genome(")

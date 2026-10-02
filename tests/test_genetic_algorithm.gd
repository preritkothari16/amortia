extends GutTest
## Tests for GeneticAlgorithm: size, elitism, ranges, budget, crossover, mutation, selection
## pressure, diversity guard, determinism, and that evolution actually improves fitness.

const BUDGET: int = 15

var _rules: GenomeRules
var _settings: GASettings


func before_each() -> void:
	_rules = GenomeRules.new()
	_settings = GASettings.new()  # GDD defaults: 20, k=3, elitism 2, crossover 0.9, mutation 0.1


func _ga(seed_value: int = 42) -> GeneticAlgorithm:
	return GeneticAlgorithm.new(_settings, _rules, seed_value)


## `n` random valid genomes (seeded) for `budget`.
func _population(n: int, seed_value: int = 7, budget: int = BUDGET) -> Array[Genome]:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var pop: Array[Genome] = []
	for i: int in n:
		pop.append(Genome.random(rng, _rules, budget))
	return pop


## Fitness 0, 1, 2, ... n-1 shuffled by a fixed pattern, so the best are not just at the end.
func _fitness(n: int) -> Array[float]:
	var f: Array[float] = []
	for i: int in n:
		f.append(float((i * 7) % n))
	return f


func _dicts(pop: Array[Genome]) -> Array:
	return pop.map(func(g: Genome) -> Dictionary: return g.to_dict())


# --- Population size -----------------------------------------------------------------

func test_next_generation_has_population_size() -> void:
	for input_size: int in [20, 5, 1, 30]:
		var next: Array[Genome] = _ga().next_generation(_population(input_size), _fitness(input_size), BUDGET)
		assert_eq(next.size(), 20, "input of %d" % input_size)


func test_population_size_is_configurable() -> void:
	_settings.population_size = 8
	assert_eq(_ga().next_generation(_population(20), _fitness(20), BUDGET).size(), 8)


func test_children_are_new_objects() -> void:
	var pop: Array[Genome] = _population(20)
	var next: Array[Genome] = _ga().next_generation(pop, _fitness(20), BUDGET)
	for g: Genome in next:
		assert_false(pop.has(g), "no genome object is shared with the old generation")


# --- Elitism -------------------------------------------------------------------------

func test_top_two_preserved_unchanged() -> void:
	var pop: Array[Genome] = _population(20)
	var fit: Array[float] = _fitness(20)
	var order: Array[int] = GeneticAlgorithm.rank(fit)
	var next: Array[Genome] = _ga().next_generation(pop, fit, BUDGET)
	assert_eq(next[0].to_dict(), pop[order[0]].to_dict(), "best genome first, unchanged")
	assert_eq(next[1].to_dict(), pop[order[1]].to_dict(), "second best, unchanged")
	assert_eq(fit[order[0]], 19.0)
	assert_eq(fit[order[1]], 18.0)


func test_elites_survive_even_with_maximum_mutation() -> void:
	_settings.mutation_rate = 1.0
	var pop: Array[Genome] = _population(20)
	var fit: Array[float] = _fitness(20)
	var best: Dictionary = pop[GeneticAlgorithm.rank(fit)[0]].to_dict()
	var next: Array[Genome] = _ga().next_generation(pop, fit, BUDGET)
	assert_eq(next[0].to_dict(), best)


func test_elite_copies_do_not_alias_parents() -> void:
	var pop: Array[Genome] = _population(20)
	var fit: Array[float] = _fitness(20)
	var next: Array[Genome] = _ga().next_generation(pop, fit, BUDGET)
	var best_index: int = GeneticAlgorithm.rank(fit)[0]
	var before: Dictionary = next[0].to_dict()
	pop[best_index].aggression = 0.0
	pop[best_index].speed = 1.0
	assert_eq(next[0].to_dict(), before, "changing the old genome does not change the elite")


func test_elitism_count_is_configurable() -> void:
	_settings.elitism = 5
	var pop: Array[Genome] = _population(20)
	var fit: Array[float] = _fitness(20)
	var order: Array[int] = GeneticAlgorithm.rank(fit)
	var next: Array[Genome] = _ga().next_generation(pop, fit, BUDGET)
	for i: int in 5:
		assert_eq(next[i].to_dict(), pop[order[i]].to_dict(), "elite %d" % i)
	var ga: GeneticAlgorithm = _ga()
	ga.next_generation(pop, fit, BUDGET)
	assert_eq(ga.last_stats["elite_indices"], order.slice(0, 5))


func test_rank_breaks_ties_by_index() -> void:
	var f: Array[float] = [1.0, 3.0, 3.0, 0.0, 3.0]
	assert_eq(GeneticAlgorithm.rank(f), [1, 2, 4, 0, 3])


func test_best_fitness_never_lost_over_generations() -> void:
	# With elitism, the best genome of generation g is still present in generation g+1.
	var ga: GeneticAlgorithm = _ga()
	var pop: Array[Genome] = _population(20)
	for gen: int in 10:
		var fit: Array[float] = []
		for g: Genome in pop:
			fit.append(g.aggression)
		var best: Dictionary = pop[GeneticAlgorithm.rank(fit)[0]].to_dict()
		pop = ga.next_generation(pop, fit, BUDGET)
		assert_true(_dicts(pop).has(best), "generation %d kept its best" % gen)


# --- Valid ranges and budget ---------------------------------------------------------

func test_all_genes_stay_in_range_over_many_generations() -> void:
	_settings.mutation_rate = 0.5  # harsh, to stress repair
	var ga: GeneticAlgorithm = _ga()
	var pop: Array[Genome] = _population(20)
	var fit_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	fit_rng.seed = 3
	for gen: int in 50:
		var fit: Array[float] = []
		for g: Genome in pop:
			fit.append(fit_rng.randf())
		pop = ga.next_generation(pop, fit, BUDGET)
		for g: Genome in pop:
			assert_true(g.is_valid(_rules, BUDGET), "gen %d: %s" % [gen, g.describe()])
			assert_true(g.path_mode in [Genome.PathMode.FLOW, Genome.PathMode.ASTAR, Genome.PathMode.GREEDY])


func test_budget_enforced_when_budget_shrinks() -> void:
	# Parents bred for budget 24 (late zone), children must fit budget 15 (new zone).
	var pop: Array[Genome] = _population(20, 7, 24)
	var next: Array[Genome] = _ga().next_generation(pop, _fitness(20), 15)
	for g: Genome in next:
		assert_lte(g.stat_total(), 15.0 + 0.0001, g.describe())
		assert_true(g.is_valid(_rules, 15))


func test_crossover_child_over_budget_is_repaired() -> void:
	# Two parents that each fit 15 but put their points in different stats.
	var a: Genome = Genome.new()
	a.speed = 10.0
	a.health = 2.5
	a.vision = 2.5
	var b: Genome = Genome.new()
	b.speed = 2.5
	b.health = 10.0
	b.vision = 2.5
	_settings.crossover_rate = 1.0
	_settings.mutation_rate = 0.0
	_settings.elitism = 0
	var pop: Array[Genome] = [a, b]
	var next: Array[Genome] = _ga().next_generation(pop, [1.0, 1.0] as Array[float], 15)
	var saw_repair: bool = false
	for g: Genome in next:
		assert_lte(g.stat_total(), 15.0 + 0.0001)
		if g.speed > 2.5 and g.health > 2.5:
			saw_repair = true  # got the big stat from both parents, then was shrunk to fit
	assert_true(saw_repair, "at least one child mixed both strong stats and was repaired")


func test_budget_grows_between_waves() -> void:
	# A larger budget is allowed but not forced: valid parents stay valid.
	var next: Array[Genome] = _ga().next_generation(_population(20), _fitness(20), 16)
	for g: Genome in next:
		assert_true(g.is_valid(_rules, 16))


# --- Crossover -----------------------------------------------------------------------

func test_uniform_crossover_takes_each_gene_from_a_parent() -> void:
	var pop: Array[Genome] = _population(2, 11)
	var a: Genome = pop[0]
	var b: Genome = pop[1]
	var ga: GeneticAlgorithm = _ga()
	var from_a: int = 0
	var from_b: int = 0
	for trial: int in 400:
		var child: Genome = ga.uniform_crossover(a, b)
		for gene: StringName in Genome.STAT_GENES + Genome.BEHAVIOUR_GENES:
			var v: float = child.get(gene)
			assert_true(v == a.get(gene) or v == b.get(gene), "gene %s from a parent" % gene)
			if v == a.get(gene):
				from_a += 1
			else:
				from_b += 1
		assert_true(child.path_mode == a.path_mode or child.path_mode == b.path_mode)
	var share: float = float(from_a) / (from_a + from_b)
	assert_between(share, 0.45, 0.55, "about half the genes from each parent (%.3f)" % share)


func test_crossover_rate_zero_means_copies_of_parents() -> void:
	_settings.crossover_rate = 0.0
	_settings.mutation_rate = 0.0
	var pop: Array[Genome] = _population(20)
	var ga: GeneticAlgorithm = _ga()
	var next: Array[Genome] = ga.next_generation(pop, _fitness(20), BUDGET)
	var parents: Array = _dicts(pop)
	for g: Genome in next:
		assert_true(parents.has(g.to_dict()), "every child is an exact parent copy")
	assert_eq(ga.last_stats["crossovers"], 0)


func test_crossover_rate_about_ninety_percent() -> void:
	var ga: GeneticAlgorithm = _ga()
	var made: int = 0
	var crossed: int = 0
	var pop: Array[Genome] = _population(20)
	for i: int in 50:
		ga.next_generation(pop, _fitness(20), BUDGET)
		made += 18
		crossed += ga.last_stats["crossovers"]
	assert_between(float(crossed) / made, 0.85, 0.95)


# --- Mutation ------------------------------------------------------------------------

func test_mutation_rate_about_ten_percent_per_gene() -> void:
	# Identical parents and no crossover: every difference in a child is a mutation.
	_settings.crossover_rate = 0.0
	var parent: Genome = _population(1)[0]
	var pop: Array[Genome] = []
	var fit: Array[float] = []
	for i: int in 20:
		pop.append(parent.copy())
		fit.append(1.0)
	parent.path_mode = Genome.PathMode.FLOW
	for g: Genome in pop:
		g.path_mode = Genome.PathMode.FLOW
	# Mixed path modes would trigger the guard; keep it off for this measurement.
	_settings.diversity_threshold = 1.0
	var ga: GeneticAlgorithm = _ga()
	var mutated: int = 0
	var genes: int = 0
	for generation: int in 100:
		ga.next_generation(pop, fit, BUDGET)
		mutated += ga.last_stats["genes_mutated"]
		genes += 18 * 9
	var rate: float = float(mutated) / genes
	assert_between(rate, 0.08, 0.12, "measured %.3f" % rate)


func test_mutation_changes_genes_but_keeps_them_valid() -> void:
	_settings.crossover_rate = 0.0
	_settings.mutation_rate = 1.0
	_settings.elitism = 0
	var parent: Genome = Genome.new()  # all neutral: 5 / 5 / 5, behaviour 0.5, FLOW
	var pop: Array[Genome] = [parent]
	var next: Array[Genome] = _ga().next_generation(pop, [1.0] as Array[float], BUDGET)
	for child: Genome in next:
		assert_ne(child.to_dict(), parent.to_dict(), "rate 1: something changed")
		assert_ne(child.path_mode, parent.path_mode, "category re-picked to a different value")
		assert_true(child.is_valid(_rules, BUDGET))


func test_no_mutation_no_crossover_selects_only() -> void:
	_settings.crossover_rate = 0.0
	_settings.mutation_rate = 0.0
	_settings.diversity_threshold = 1.0
	var ga: GeneticAlgorithm = _ga()
	ga.next_generation(_population(20), _fitness(20), BUDGET)
	assert_eq(ga.last_stats["genes_mutated"], 0)


# --- Selection -----------------------------------------------------------------------

func test_tournament_prefers_fitter_genomes() -> void:
	var ga: GeneticAlgorithm = _ga()
	var fit: Array[float] = []
	for i: int in 20:
		fit.append(float(i))  # index 19 is best, 0 is worst
	var counts: Array[int] = []
	counts.resize(20)
	counts.fill(0)
	for i: int in 20000:
		counts[ga.tournament_select(fit)] += 1
	assert_gt(counts[19], counts[10], "best picked more than average")
	assert_gt(counts[10], counts[0], "average picked more than worst")
	# P(worst wins a 3-tournament) = (1/20)^3 = 0.000125 -> about 2-3 times in 20000.
	assert_lt(counts[0], 20)
	# P(best wins) = 1 - (19/20)^3 = 0.142625 -> about 2853 times.
	assert_between(counts[19], 2600, 3100)


func test_tournament_size_one_is_uniform() -> void:
	_settings.tournament_size = 1
	var ga: GeneticAlgorithm = _ga()
	var fit: Array[float] = [0.0, 100.0]
	var picked_worst: int = 0
	for i: int in 2000:
		if ga.tournament_select(fit) == 0:
			picked_worst += 1
	assert_between(picked_worst, 900, 1100, "no selection pressure at k = 1")


func test_evolution_improves_fitness() -> void:
	# Toy fitness: aggression. Starting mean is about 0.5; selection should push it up.
	var ga: GeneticAlgorithm = _ga()
	var pop: Array[Genome] = _population(20)
	var start_mean: float = 0.0
	for g: Genome in pop:
		start_mean += g.aggression / 20.0
	for gen: int in 30:
		var fit: Array[float] = []
		for g: Genome in pop:
			fit.append(g.aggression)
		pop = ga.next_generation(pop, fit, BUDGET)
	var end_mean: float = 0.0
	for g: Genome in pop:
		end_mean += g.aggression / 20.0
	assert_gt(end_mean, start_mean + 0.2, "mean aggression %.2f -> %.2f" % [start_mean, end_mean])
	assert_gt(end_mean, 0.8)


# --- Diversity guard -----------------------------------------------------------------

func test_dominant_path_share() -> void:
	var pop: Array[Genome] = _population(10)
	for i: int in 10:
		pop[i].path_mode = Genome.PathMode.ASTAR if i < 9 else Genome.PathMode.FLOW
	assert_almost_eq(GeneticAlgorithm.dominant_path_share(pop), 0.9, 0.0001)


func test_diversity_guard_doubles_mutation_when_dominated() -> void:
	var pop: Array[Genome] = _population(20)
	for g: Genome in pop:
		g.path_mode = Genome.PathMode.FLOW
	pop[0].path_mode = Genome.PathMode.GREEDY  # 95 % FLOW
	var ga: GeneticAlgorithm = _ga()
	ga.next_generation(pop, _fitness(20), BUDGET)
	assert_true(ga.last_stats["diversity_guard"])
	assert_almost_eq(ga.last_stats["mutation_rate"], 0.2, 0.0001)


func test_diversity_guard_off_when_mixed() -> void:
	var pop: Array[Genome] = _population(20)
	for i: int in 20:
		pop[i].path_mode = (i % 3) as Genome.PathMode
	var ga: GeneticAlgorithm = _ga()
	ga.next_generation(pop, _fitness(20), BUDGET)
	assert_false(ga.last_stats["diversity_guard"])
	assert_almost_eq(ga.last_stats["mutation_rate"], 0.1, 0.0001)


func test_diversity_guard_threshold_is_strictly_greater() -> void:
	var pop: Array[Genome] = _population(10)
	for i: int in 10:
		pop[i].path_mode = Genome.PathMode.FLOW if i < 8 else Genome.PathMode.ASTAR  # exactly 80 %
	var ga: GeneticAlgorithm = _ga()
	ga.next_generation(pop, _fitness(10), BUDGET)
	assert_false(ga.last_stats["diversity_guard"], "GDD: MORE than 80 %")


# --- Determinism ---------------------------------------------------------------------

func test_same_seed_same_next_generation() -> void:
	var a: Array[Genome] = _ga(123).next_generation(_population(20), _fitness(20), BUDGET)
	var b: Array[Genome] = _ga(123).next_generation(_population(20), _fitness(20), BUDGET)
	assert_eq(_dicts(a), _dicts(b))


func test_same_seed_same_ten_generation_run() -> void:
	var runs: Array = []
	for r: int in 2:
		var ga: GeneticAlgorithm = _ga(9)
		var pop: Array[Genome] = _population(20)
		for gen: int in 10:
			var fit: Array[float] = []
			for g: Genome in pop:
				fit.append(g.aggression + g.speed * 0.1)
			pop = ga.next_generation(pop, fit, BUDGET)
		runs.append(_dicts(pop))
	assert_eq(runs[0], runs[1])


func test_different_seed_different_result() -> void:
	var a: Array[Genome] = _ga(1).next_generation(_population(20), _fitness(20), BUDGET)
	var b: Array[Genome] = _ga(2).next_generation(_population(20), _fitness(20), BUDGET)
	assert_ne(_dicts(a), _dicts(b))


func test_global_randomness_does_not_leak_in() -> void:
	seed(1)
	var a: Array[Genome] = _ga(55).next_generation(_population(20), _fitness(20), BUDGET)
	seed(999)
	randf()
	var b: Array[Genome] = _ga(55).next_generation(_population(20), _fitness(20), BUDGET)
	assert_eq(_dicts(a), _dicts(b), "only the GA's own seeded RNG is used")


# --- Input handling ------------------------------------------------------------------

func test_from_wave_results() -> void:
	var pop: Array[Genome] = _population(20)
	var results: Array[Dictionary] = []
	for i: int in 20:
		results.append({"genome": pop[i], "fitness": float(i)})
	results.append({"genome": null, "fitness": 99.0})  # enemy without a genome: skipped
	var next: Array[Genome] = _ga().next_generation_from_results(results, BUDGET)
	assert_eq(next.size(), 20)
	assert_eq(next[0].to_dict(), pop[19].to_dict(), "fitness 19 is the top elite")


func test_stats_reported() -> void:
	var ga: GeneticAlgorithm = _ga()
	ga.next_generation(_population(20), _fitness(20), BUDGET)
	assert_eq(ga.last_stats["best_fitness"], 19.0)
	assert_almost_eq(ga.last_stats["mean_fitness"], 9.5, 0.0001)


func test_data_file_matches_gdd() -> void:
	var s: GASettings = load("res://data/ga.tres")
	assert_eq(s.population_size, 20)
	assert_eq(s.tournament_size, 3)
	assert_eq(s.elitism, 2)
	assert_almost_eq(s.crossover_rate, 0.9, 0.0001)
	assert_almost_eq(s.mutation_rate, 0.1, 0.0001)
	assert_almost_eq(s.diversity_threshold, 0.8, 0.0001)
	assert_almost_eq(s.diversity_mutation_multiplier, 2.0, 0.0001)

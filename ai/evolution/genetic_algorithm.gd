class_name GeneticAlgorithm
extends RefCounted
## Hand-written Genetic Algorithm (GDD 5.4). Pure logic: takes evaluated genomes and their
## fitness, returns the next generation. Does not touch the game.
##
##   next = copies of the `elitism` fittest genomes (unchanged)
##   until next has population_size genomes:
##       parents A, B = tournament selection (size tournament_size)
##       child = uniform crossover of A and B (chance crossover_rate), else a copy of A
##       child.mutate(rate)   - Gaussian nudge for numbers, re-pick for path_mode
##       child.repair(budget) - clamp ranges, spend exactly the stat budget
##   rate = mutation_rate, doubled for this generation if > diversity_threshold of the
##   population share one path_mode (diversity guard)
##
## All randomness comes from `rng`, seeded in the constructor: same seed + same input =
## exactly the same next generation (needed for repeatable experiments).

var settings: GASettings
var rules: GenomeRules
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

## What happened in the last next_generation() call, for logs and tests:
## best_fitness, mean_fitness, elite_indices, mutation_rate, diversity_guard,
## dominant_path_share, crossovers, genes_mutated.
var last_stats: Dictionary = {}


func _init(ga_settings: GASettings, genome_rules: GenomeRules, seed_value: int) -> void:
	settings = ga_settings
	rules = genome_rules
	rng.seed = seed_value


## Builds the next generation. `fitness[i]` belongs to `population[i]`; higher is better.
## `budget` = stat budget of the wave the new generation will play.
## Returns [] (and reports an error) if the input is unusable.
func next_generation(population: Array[Genome], fitness: Array[float], budget: int) -> Array[Genome]:
	if population.is_empty() or population.size() != fitness.size():
		push_error("GeneticAlgorithm: need one fitness value per genome (got %d genomes, %d values)" % [population.size(), fitness.size()])
		return []

	# Diversity guard: a population dominated by one path_mode mutates twice as much.
	var share: float = dominant_path_share(population)
	var guard: bool = share > settings.diversity_threshold
	var rate: float = settings.mutation_rate * (settings.diversity_mutation_multiplier if guard else 1.0)

	# Elitism: the fittest genomes pass on with their genes' proportions unchanged; repair only
	# rescales their stats to this wave's budget (unchanged if the budget is the same).
	var order: Array[int] = rank(fitness)
	var next: Array[Genome] = []
	var elite_count: int = mini(settings.elitism, mini(population.size(), settings.population_size))
	for i: int in elite_count:
		var elite: Genome = population[order[i]].copy()
		elite.repair(rules, budget)
		next.append(elite)

	# Offspring: select, cross over, mutate, repair.
	var crossovers: int = 0
	var genes_mutated: int = 0
	while next.size() < settings.population_size:
		var parent_a: Genome = population[tournament_select(fitness)]
		var parent_b: Genome = population[tournament_select(fitness)]
		var child: Genome
		if rng.randf() < settings.crossover_rate:
			child = uniform_crossover(parent_a, parent_b)
			crossovers += 1
		else:
			child = parent_a.copy()
		genes_mutated += child.mutate(rng, rules, budget, rate)  # mutate() also repairs
		child.repair(rules, budget)  # explicit: crossover alone can break the budget
		next.append(child)

	var total: float = 0.0
	for f: float in fitness:
		total += f
	last_stats = {
		"best_fitness": fitness[order[0]], "mean_fitness": total / fitness.size(),
		"elite_indices": order.slice(0, elite_count), "mutation_rate": rate, "diversity_guard": guard,
		"dominant_path_share": share, "crossovers": crossovers, "genes_mutated": genes_mutated,
	}
	return next


## Convenience: build the next generation straight from WaveManager.last_wave_results
## (entries with "genome" and "fitness"). Entries without a genome are skipped.
func next_generation_from_results(results: Array[Dictionary], budget: int) -> Array[Genome]:
	var population: Array[Genome] = []
	var fitness: Array[float] = []
	for r: Dictionary in results:
		if r.get("genome") != null:
			population.append(r["genome"])
			fitness.append(r["fitness"])
	return next_generation(population, fitness, budget)


## Tournament selection: draw `tournament_size` random indices (with replacement) and return
## the one with the highest fitness. A tie keeps the earlier draw.
func tournament_select(fitness: Array[float]) -> int:
	var best: int = rng.randi_range(0, fitness.size() - 1)
	for i: int in settings.tournament_size - 1:
		var challenger: int = rng.randi_range(0, fitness.size() - 1)
		if fitness[challenger] > fitness[best]:
			best = challenger
	return best


## Uniform crossover: every gene independently comes from parent A or parent B (50/50).
## The child may break the stat budget - the caller repairs it.
func uniform_crossover(a: Genome, b: Genome) -> Genome:
	var child: Genome = Genome.new()
	for gene: StringName in Genome.STAT_GENES + Genome.BEHAVIOUR_GENES:
		child.set(gene, a.get(gene) if rng.randf() < 0.5 else b.get(gene))
	child.path_mode = a.path_mode if rng.randf() < 0.5 else b.path_mode
	return child


## Indices sorted by fitness, best first. Equal fitness keeps the lower index first,
## so the ranking (and so elitism) is deterministic.
static func rank(fitness: Array[float]) -> Array[int]:
	var order: Array[int] = []
	for i: int in fitness.size():
		order.append(i)
	order.sort_custom(func(x: int, y: int) -> bool:
		return fitness[x] > fitness[y] or (fitness[x] == fitness[y] and x < y))
	return order


## Share (0..1) of the population using the most common path_mode.
static func dominant_path_share(population: Array[Genome]) -> float:
	if population.is_empty():
		return 0.0
	var counts: Dictionary = {}
	for g: Genome in population:
		counts[g.path_mode] = counts.get(g.path_mode, 0) + 1
	var most: int = 0
	for mode: Variant in counts:
		most = maxi(most, counts[mode])
	return float(most) / population.size()

extends GutTest
## Expansion phase 2: terrain genes (swimmer, climber, crawler, toxin_resistance, night_sense),
## the separate adaptation budget, and navigation per terrain-profile bucket (FlowFieldSet,
## profile-aware PathQueue, Enemy nav_profile).

var _rules: GenomeRules
var _rng: RandomNumberGenerator
var _terrain: TerrainCosts


func before_each() -> void:
	_rules = load("res://data/genome_rules.tres")
	_rng = RandomNumberGenerator.new()
	_rng.seed = 77
	_terrain = load("res://data/terrain_costs.tres")


func _assert_adaptations_legal(g: Genome, msg: String = "") -> void:
	for gene: StringName in Genome.TERRAIN_GENES:
		assert_between(g.get(gene), 0.0, 1.0, "%s %s" % [msg, gene])
	assert_lte(g.adaptation_total(), _rules.adaptation_budget + 0.0001, msg)


# --- Genome --------------------------------------------------------------------------

func test_data_defaults() -> void:
	assert_eq(_rules.adaptation_budget, 1.5, "GDD 5.3")
	assert_eq(Genome.TERRAIN_GENES.size(), 5)
	for gene: StringName in [&"swimmer", &"climber", &"crawler", &"toxin_resistance"]:
		assert_true(_terrain.adaptations.has(String(gene)), "%s adapts some terrain" % gene)


func test_random_genomes_respect_both_budgets_and_vary() -> void:
	var totals: Array[float] = []
	for i: int in 300:
		var g: Genome = Genome.random(_rng, _rules, 20)
		_assert_adaptations_legal(g, "genome %d" % i)
		assert_true(g.spends_budget(_rules, 20))
		assert_true(g.is_valid(_rules, 20))
		totals.append(g.adaptation_total())
	totals.sort()
	assert_lt(totals[0], 0.1, "some genomes barely adapt")
	assert_gt(totals[-1], 1.3, "some use most of the budget")


func test_random_is_reproducible_and_old_genes_unchanged_by_order() -> void:
	var a: RandomNumberGenerator = RandomNumberGenerator.new()
	var b: RandomNumberGenerator = RandomNumberGenerator.new()
	a.seed = 5
	b.seed = 5
	for i: int in 20:
		assert_eq(Genome.random(a, _rules, 18).to_dict(), Genome.random(b, _rules, 18).to_dict())


func test_repair_scales_over_budget_adaptations_keeping_ratios() -> void:
	var g: Genome = Genome.random(_rng, _rules, 20)
	g.swimmer = 1.0
	g.climber = 1.0
	g.crawler = 0.5
	g.toxin_resistance = 0.5
	g.night_sense = 0.0
	g.repair(_rules, 20)
	assert_almost_eq(g.adaptation_total(), 1.5, 0.0001)
	assert_almost_eq(g.swimmer / g.crawler, 2.0, 0.0001, "ratios kept")
	assert_eq(g.night_sense, 0.0)


func test_repair_clamps_and_never_tops_up() -> void:
	var g: Genome = Genome.random(_rng, _rules, 20)
	for gene: StringName in Genome.TERRAIN_GENES:
		g.set(gene, 0.0)
	g.climber = 1.7
	g.swimmer = -0.3
	g.repair(_rules, 20)
	assert_eq(g.climber, 1.0)
	assert_eq(g.swimmer, 0.0)
	assert_almost_eq(g.adaptation_total(), 1.0, 0.0001, "under budget stays under")


func test_is_valid_checks_the_adaptation_budget() -> void:
	var g: Genome = Genome.random(_rng, _rules, 20)
	for gene: StringName in Genome.TERRAIN_GENES:
		g.set(gene, 0.4)  # 2.0 > 1.5
	assert_false(g.is_valid(_rules, 20))
	g.repair(_rules, 20)
	assert_true(g.is_valid(_rules, 20))


func test_mutation_moves_terrain_genes_and_stays_legal() -> void:
	var moved: int = 0
	for i: int in 200:
		var g: Genome = Genome.random(_rng, _rules, 20)
		var before: Dictionary = g.to_dict()
		g.mutate(_rng, _rules, 20, 0.5)
		_assert_adaptations_legal(g)
		for gene: StringName in Genome.TERRAIN_GENES:
			if not is_equal_approx(before[String(gene)], g.get(gene)):
				moved += 1
	assert_gt(moved, 200, "terrain genes do mutate")


func test_dict_round_trip_and_old_dicts_load_with_no_adaptations() -> void:
	var g: Genome = Genome.random(_rng, _rules, 20)
	var back: Genome = Genome.from_dict(g.to_dict())
	for gene: StringName in Genome.TERRAIN_GENES:
		assert_almost_eq(back.get(gene), g.get(gene), 0.000001)
	var old: Dictionary = g.to_dict()
	for gene: StringName in Genome.TERRAIN_GENES:
		old.erase(String(gene))
	var legacy: Genome = Genome.from_dict(old)
	assert_eq(legacy.adaptation_total(), 0.0)
	assert_true(legacy.is_valid(_rules, 20))
	assert_string_contains(g.describe(), "cli ")


func test_old_save_without_terrain_genes_validates() -> void:
	var population: Array = []
	for i: int in 4:
		var d: Dictionary = Genome.random(_rng, _rules, 16).to_dict()
		for gene: StringName in Genome.TERRAIN_GENES:
			d.erase(String(gene))
		population.append(d)
	var data: Dictionary = {
		"version": 1,
		"player": {"level": 1, "xp": 0, "total_xp": 0, "skill_points": 0, "unlocked": []},
		"evolution": {"next_wave": 2, "generation": 1, "population": population, "history": []},
	}
	var result: Dictionary = SaveGame.validate(data, _rules)
	assert_true(result["ok"], str(result.get("error", "")))


func test_profile_from_genes_uses_the_rulebook() -> void:
	var g: Genome = Genome.new()
	g.climber = 1.0
	g.swimmer = 0.5
	var profile: TerrainCostProfile = TerrainCostProfile.create(_terrain, g.terrain_genes())
	assert_eq(profile.cost_of("fence"), 2.0)
	assert_eq(profile.cost_of("deep_water"), 2.0, "unlocked at the 0.5 threshold")
	assert_eq(profile.cost_of("shallow_water"), 2.0, "lerp(3, 1, 0.5)")
	assert_eq(profile.cost_of("vent"), INF)
	g.night_sense = 1.0
	assert_eq(TerrainCostProfile.create(_terrain, g.terrain_genes()).cost_of("road"), 1.0, "night sense changes no cost")


# --- GA ------------------------------------------------------------------------------

func _ga(seed_value: int) -> GeneticAlgorithm:
	var settings: GASettings = (load("res://data/ga.tres") as GASettings).duplicate()
	return GeneticAlgorithm.new(settings, _rules, seed_value)


func test_crossover_takes_terrain_genes_from_a_parent() -> void:
	var ga: GeneticAlgorithm = _ga(3)
	var a: Genome = Genome.random(_rng, _rules, 20)
	var b: Genome = Genome.random(_rng, _rules, 20)
	for i: int in 50:
		var child: Genome = ga.uniform_crossover(a, b)
		for gene: StringName in Genome.TERRAIN_GENES:
			assert_true(child.get(gene) == a.get(gene) or child.get(gene) == b.get(gene))


func test_ga_children_respect_both_budgets_over_many_generations() -> void:
	var ga: GeneticAlgorithm = _ga(9)
	var pop: Array[Genome] = []
	for i: int in 20:
		pop.append(Genome.random(_rng, _rules, 20))
	for generation: int in 40:
		var fit: Array[float] = []
		for g: Genome in pop:
			fit.append(g.adaptation_total())  # pushes towards the ceiling
		pop = ga.next_generation(pop, fit, _rules.budget_for_wave(generation + 2))
		for g: Genome in pop:
			_assert_adaptations_legal(g, "gen %d" % generation)
			assert_true(g.spends_budget(_rules, _rules.budget_for_wave(generation + 2)))


func test_selection_can_evolve_a_terrain_gene() -> void:
	var ga: GeneticAlgorithm = _ga(21)
	var pop: Array[Genome] = []
	for i: int in 20:
		pop.append(Genome.random(_rng, _rules, 20))
	var start: float = WaveManager.gene_means(pop)["climber"]
	for generation: int in 30:
		var fit: Array[float] = []
		for g: Genome in pop:
			fit.append(g.climber)
		pop = ga.next_generation(pop, fit, 20)
	var end: float = WaveManager.gene_means(pop)["climber"]
	assert_gt(end, start + 0.3, "climber %.2f -> %.2f" % [start, end])


func test_same_seed_same_terrain_evolution() -> void:
	var runs: Array[String] = []
	for run: int in 2:
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = 13
		var ga: GeneticAlgorithm = _ga(13)
		var pop: Array[Genome] = []
		for i: int in 20:
			pop.append(Genome.random(rng, _rules, 20))
		for generation: int in 10:
			var fit: Array[float] = []
			for g: Genome in pop:
				fit.append(g.swimmer + g.speed * 0.01)
			pop = ga.next_generation(pop, fit, 20)
		var text: PackedStringArray = PackedStringArray()
		for g: Genome in pop:
			text.append(g.describe())
		runs.append("\n".join(text))
	assert_eq(runs[0], runs[1])


# --- Navigation per profile ------------------------------------------------------------

func _grid(lines: Array[String]) -> TerrainGrid:
	var legend: Dictionary = {".": "road", "F": "fence", "#": "wall", "~": "deep_water", "s": "shallow_water"}
	var rows: Array[PackedStringArray] = []
	for line: String in lines:
		var row: PackedStringArray = PackedStringArray()
		for c: String in line:
			row.append(legend[c])
		rows.append(row)
	return TerrainGrid.from_rows(rows, _terrain)


const FENCE_MAP: Array[String] = [
	"..........",
	"####F#####",
	"..........",
]


func test_buckets_only_split_on_terrain_present_on_the_map() -> void:
	var g: TerrainGrid = _grid(FENCE_MAP)
	var set: FlowFieldSet = FlowFieldSet.new(g)
	set.set_target(Vector2i(4, 2))
	var swimmer: TerrainCostProfile = set.canonical_profile(g.make_profile({"swimmer": 1.0}))
	assert_eq(set.field_for(swimmer), set.base_field, "no water here: swimmers share the base field")
	var climber: TerrainCostProfile = set.canonical_profile(g.make_profile({"climber": 1.0}))
	assert_ne(set.field_for(climber), set.base_field)
	assert_eq(set.field_count(), 2)
	var same_bucket: TerrainCostProfile = set.canonical_profile(g.make_profile({"climber": 0.95, "swimmer": 0.4}))
	assert_eq(same_bucket, climber, "fence 2.2 rounds to the climber bucket")


func test_bucket_field_matches_astar_with_the_representative_profile() -> void:
	var g: TerrainGrid = _grid([
		"...s~~....",
		"###F##.##.",
		"..~~...F..",
		"....s.....",
	])
	var set: FlowFieldSet = FlowFieldSet.new(g)
	var target: Vector2i = Vector2i(0, 3)
	set.set_target(target)
	var astar: AStar = AStar.new(g)
	for raw: Dictionary in [{"climber": 0.8}, {"swimmer": 0.7}, {"swimmer": 1.0, "climber": 0.5}]:
		var genes: Dictionary[String, float] = {}
		genes.assign(raw)
		var p: TerrainCostProfile = set.canonical_profile(g.make_profile(genes))
		var field: FlowField = set.field_for(p)
		for y: int in g.height:
			for x: int in g.width:
				var cell: Vector2i = Vector2i(x, y)
				astar.find_path(cell, target, p)
				if astar.last_cost == INF:
					assert_false(field.is_reachable(cell), "%s %s" % [genes, cell])
				else:
					assert_almost_eq(field.get_cost(cell), astar.last_cost, 0.0001, "%s %s" % [genes, cell])


func test_swimmers_get_a_route_through_deep_water() -> void:
	var g: TerrainGrid = _grid([
		"....~....",
		"....~....",
		"....~....",
	])
	var set: FlowFieldSet = FlowFieldSet.new(g)
	set.set_target(Vector2i(8, 1))
	assert_false(set.base_field.is_reachable(Vector2i(0, 1)), "walkers can't cross")
	var swimmer: TerrainCostProfile = set.canonical_profile(g.make_profile({"swimmer": 0.6}))
	assert_true(set.field_for(swimmer).is_reachable(Vector2i(0, 1)))
	assert_eq(g.enemy_traversal(Vector2i(4, 1)), TerrainDefinition.Traversal.SWIM)


func test_other_buckets_rebuild_one_per_process_call() -> void:
	var g: TerrainGrid = _grid(["....~.F...", "....~.F...", ".........."])
	var set: FlowFieldSet = FlowFieldSet.new(g)
	set.set_target(Vector2i(0, 0))
	var climber: TerrainCostProfile = set.canonical_profile(g.make_profile({"climber": 1.0}))
	var swimmer: TerrainCostProfile = set.canonical_profile(g.make_profile({"swimmer": 1.0}))
	assert_eq(set.field_for(climber).target, Vector2i(0, 0), "built on first use")
	set.set_target(Vector2i(9, 2))
	assert_eq(set.base_field.target, Vector2i(9, 2), "base at once")
	assert_eq(set.stale_count(), 2)
	set.process()
	assert_eq(set.stale_count(), 1)
	set.process()
	assert_eq(set.field_for(climber).target, Vector2i(9, 2))
	assert_eq(set.field_for(swimmer).target, Vector2i(9, 2))


func test_too_many_buckets_fall_back_to_base() -> void:
	var g: TerrainGrid = _grid(FENCE_MAP)
	var set: FlowFieldSet = FlowFieldSet.new(g)
	set.max_fields = 2
	set.set_target(Vector2i(0, 0))
	set.canonical_profile(g.make_profile({"climber": 1.0}))
	assert_eq(set.canonical_profile(g.make_profile({"climber": 0.5})), g.base_profile)


func test_path_queue_keeps_profiles_apart() -> void:
	# Walkers pay 6 to climb the fence (total 9) and take the gap at x = 3 instead (8);
	# a full climber pays 2 (total 5) and goes over.
	var g: TerrainGrid = _grid([
		"..........",
		"#F#.######",
		"..........",
	])
	var set: FlowFieldSet = FlowFieldSet.new(g)
	set.set_target(Vector2i(0, 0))
	var climber: TerrainCostProfile = set.canonical_profile(g.make_profile({"climber": 1.0}))
	var queue: PathQueue = PathQueue.new(AStar.new(g))
	queue.request(1, Vector2i(0, 2), Vector2i(0, 0))
	queue.request(2, Vector2i(0, 2), Vector2i(0, 0), climber)
	queue.process()
	var walker: Array[Vector2i] = queue.take_result(1)
	var climbing: Array[Vector2i] = queue.take_result(2)
	assert_false(climbing.is_empty())
	assert_true(climbing.has(Vector2i(1, 1)), "the climber goes over the fence")
	assert_false(walker.has(Vector2i(1, 1)), "the walker takes the gap")
	queue.request(3, Vector2i(0, 2), Vector2i(0, 0))
	assert_eq(queue.take_result(3), walker, "cache hit for the walker, not the climber's path")


func test_in_level_enemies_navigate_with_their_own_profile() -> void:
	var main: Node = load("res://world/main.tscn").instantiate()
	main.autosave = false
	var wm: WaveManager = main.get_node("WaveManager")
	wm.spawn_seed = 31
	wm.log_waves = false
	wm.auto_start = false
	add_child_autofree(main)
	await wait_physics_frames(2)
	var climber: Genome = Genome.random(_rng, _rules, 20)
	for gene: StringName in Genome.TERRAIN_GENES:
		climber.set(gene, 0.0)
	climber.climber = 1.0
	var plain: Genome = climber.copy()
	plain.climber = 0.0
	var spawn: Vector2 = main.get_node("MapleHollow").get_enemy_spawns()[0]
	var e1: Enemy = wm.spawn_enemy(spawn, climber)
	var e2: Enemy = wm.spawn_enemy(spawn, plain)
	await wait_physics_frames(2)
	assert_eq(e1.nav_profile.cost_of("fence"), 2.0)
	assert_eq(e2.nav_profile, main.terrain_grid.base_profile)
	assert_ne(main.flow_fields.field_for(e1.nav_profile), main.flow_field)
	assert_eq(main.flow_fields.field_for(e2.nav_profile), main.flow_field)

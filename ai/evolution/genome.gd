class_name Genome
extends Resource
## One enemy's genes (GDD 5.3). Pure data + the operations the GA needs on a single genome:
## random creation, copying, mutation and repair. Breeding and selection live elsewhere.
##
##   Stats (budgeted, stat_min..stat_max): speed, health, vision  -> move_speed, max_health, sight_range
##   Behaviour (0..1): aggression, caution, flanking, cohesion, patience -> utility AI weights
##   Strategy: path_mode (FLOW / ASTAR / GREEDY)
## A Resource, so a genome can be saved as .tres or shown in the Inspector; to_dict() /
## from_dict() give a plain, JSON-safe form for logs and experiments.

enum PathMode { FLOW, ASTAR, GREEDY }

const STAT_GENES: Array[StringName] = [&"speed", &"health", &"vision"]
const BEHAVIOUR_GENES: Array[StringName] = [&"aggression", &"caution", &"flanking", &"cohesion", &"patience"]

@export_group("Stats")
@export var speed: float = 5.0
@export var health: float = 5.0
@export var vision: float = 5.0

@export_group("Behaviour")
@export_range(0.0, 1.0) var aggression: float = 0.5
@export_range(0.0, 1.0) var caution: float = 0.5
@export_range(0.0, 1.0) var flanking: float = 0.5
@export_range(0.0, 1.0) var cohesion: float = 0.5
@export_range(0.0, 1.0) var patience: float = 0.5

@export_group("Strategy")
@export var path_mode: PathMode = PathMode.FLOW


# --- Creating and copying ------------------------------------------------------------

## A random genome that spends exactly `budget` stat points (never more than stat_max each).
static func random(rng: RandomNumberGenerator, rules: GenomeRules, budget: int) -> Genome:
	var g: Genome = Genome.new()
	for gene: StringName in BEHAVIOUR_GENES:
		g.set(gene, rng.randf())
	g.path_mode = rng.randi_range(0, PathMode.size() - 1) as PathMode
	# Random share of the budget for each stat, then hand the points out.
	var weights: Array[float] = []
	for gene: StringName in STAT_GENES:
		weights.append(rng.randf_range(0.05, 1.0))
	g._spend_budget(weights, rules, budget)
	return g


## An independent copy (changing the copy never changes the original).
func copy() -> Genome:
	return duplicate() as Genome


# --- Mutation and repair -------------------------------------------------------------

## Mutates each gene with probability `rate` (default: rules.mutation_rate), then repairs.
## Numbers get a Gaussian nudge, the category gene is re-picked to a different value.
## Returns how many genes changed.
func mutate(rng: RandomNumberGenerator, rules: GenomeRules, budget: int, rate: float = -1.0) -> int:
	if rate < 0.0:
		rate = rules.mutation_rate
	var changed: int = 0
	for gene: StringName in STAT_GENES:
		if rng.randf() < rate:
			set(gene, get(gene) + rng.randfn(0.0, rules.stat_sigma))
			changed += 1
	for gene: StringName in BEHAVIOUR_GENES:
		if rng.randf() < rate:
			set(gene, get(gene) + rng.randfn(0.0, rules.behaviour_sigma))
			changed += 1
	if rng.randf() < rate:
		# Pick one of the OTHER modes: offset 1..size-1 from the current one.
		var offset: int = rng.randi_range(1, PathMode.size() - 1)
		path_mode = ((path_mode + offset) % PathMode.size()) as PathMode
		changed += 1
	repair(rules, budget)
	return changed


## Makes the genome legal again (GDD "Repair: clamp to ranges, then enforce both budgets").
## The stat budget is points that MUST be spent, not just a ceiling (later waves get stronger):
##   1. clamp every gene to its range
##   2. the genome's allocation = each stat's points above stat_min (its "share")
##   3. re-spend exactly `budget` in those proportions: over budget -> every share shrinks by
##      the same factor, under budget -> every share grows by it. A stat that would pass
##      stat_max is capped and its overflow goes to the others (water-filling).
## So extra points follow the ratios evolution chose (via crossover and mutation), instead of
## all going to one stat. All stats at stat_min (no allocation yet) -> split evenly.
func repair(rules: GenomeRules, budget: int) -> void:
	for gene: StringName in STAT_GENES:
		set(gene, clampf(get(gene), rules.stat_min, rules.stat_max))
	for gene: StringName in BEHAVIOUR_GENES:
		set(gene, clampf(get(gene), 0.0, 1.0))
	if spends_budget(rules, budget):
		return  # already exact: leave the numbers untouched (elites stay bit-identical)
	var shares: Array[float] = []
	var share_sum: float = 0.0
	for gene: StringName in STAT_GENES:
		var share: float = get(gene) - rules.stat_min
		shares.append(share)
		share_sum += share
	if share_sum <= 0.0:
		shares = [1.0, 1.0, 1.0]
	_spend_budget(shares, rules, budget)  # clamps the budget to what 3 stats can hold


func stat_total() -> float:
	return speed + health + vision


## True if the stats add up to exactly `budget` (or as close as the 1..10 ranges allow).
## Every genome the GA or Genome.random produces does; is_valid only checks the ceiling.
func spends_budget(rules: GenomeRules, budget: int) -> bool:
	var n: float = STAT_GENES.size()
	var target: float = clampf(float(budget), rules.stat_min * n, rules.stat_max * n)
	return absf(stat_total() - target) <= 0.0001


## True if every gene is in range and the stats don't exceed the budget (a legal genome).
func is_valid(rules: GenomeRules, budget: int) -> bool:
	for gene: StringName in STAT_GENES:
		var v: float = get(gene)
		if v < rules.stat_min - 0.0001 or v > rules.stat_max + 0.0001:
			return false
	for gene: StringName in BEHAVIOUR_GENES:
		var b: float = get(gene)
		if b < 0.0 or b > 1.0:
			return false
	return stat_total() <= budget + 0.0001


# --- Gene -> enemy values ------------------------------------------------------------

## Multiplier for an archetype's base value: 1.0 at stat_neutral, +/- per_point per point.
static func stat_multiplier(gene_value: float, per_point: float, rules: GenomeRules) -> float:
	return 1.0 + (gene_value - rules.stat_neutral) * per_point


func move_speed(base: float, rules: GenomeRules) -> float:
	return base * stat_multiplier(speed, rules.speed_per_point, rules)


func max_health(base: float, rules: GenomeRules) -> float:
	return base * stat_multiplier(health, rules.health_per_point, rules)


func sight_range(base: float, rules: GenomeRules) -> float:
	return base * stat_multiplier(vision, rules.vision_per_point, rules)


## The behaviour genes as utility AI weights.
func to_behaviour_weights() -> BehaviourWeights:
	var w: BehaviourWeights = BehaviourWeights.new()
	for gene: StringName in BEHAVIOUR_GENES:
		w.set(gene, get(gene))
	return w


# --- Serialization / debug -----------------------------------------------------------

## Plain dictionary (JSON-safe): gene name -> value, path_mode as its name.
func to_dict() -> Dictionary:
	var d: Dictionary = {}
	for gene: StringName in STAT_GENES + BEHAVIOUR_GENES:
		d[String(gene)] = get(gene)
	d["path_mode"] = PathMode.keys()[path_mode]
	return d


static func from_dict(d: Dictionary) -> Genome:
	var g: Genome = Genome.new()
	for gene: StringName in STAT_GENES + BEHAVIOUR_GENES:
		if d.has(String(gene)):
			g.set(gene, float(d[String(gene)]))
	if d.has("path_mode"):
		g.path_mode = PathMode.keys().find(d["path_mode"]) as PathMode
	return g


## One-line summary, e.g. "spd 6.2 hp 4.1 vis 4.7 | agg .80 cau .12 fla .55 coh .30 pat .91 | FLOW"
func describe() -> String:
	return "spd %.1f hp %.1f vis %.1f | agg %.2f cau %.2f fla %.2f coh %.2f pat %.2f | %s" % [
		speed, health, vision, aggression, caution, flanking, cohesion, patience, PathMode.keys()[path_mode]]


func _to_string() -> String:
	return "Genome(%s)" % describe()


## Sets the stats to stat_min plus a share of the remaining budget proportional to `weights`,
## capping each at stat_max and passing any overflow on to the stats that still have room.
func _spend_budget(weights: Array[float], rules: GenomeRules, budget: int) -> void:
	var n: int = STAT_GENES.size()
	var values: Array[float] = []
	values.resize(n)
	values.fill(rules.stat_min)
	var left: float = clampf(float(budget) - rules.stat_min * n, 0.0, (rules.stat_max - rules.stat_min) * n)
	var open: Array[int] = [0, 1, 2]  # stats that can still take points
	while left > 0.0001 and not open.is_empty():
		var weight_sum: float = 0.0
		for i: int in open:
			weight_sum += weights[i]
		var overflow: float = 0.0
		for i: int in open.duplicate():
			# Only zero-weight stats left open (the others hit stat_max): split evenly.
			var part: float = weights[i] / weight_sum if weight_sum > 0.0 else 1.0 / open.size()
			values[i] += left * part
			if values[i] >= rules.stat_max:
				overflow += values[i] - rules.stat_max
				values[i] = rules.stat_max
				open.erase(i)
		left = overflow
	for i: int in n:
		set(STAT_GENES[i], values[i])

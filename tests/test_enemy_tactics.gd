extends GutTest
## Enemy tactics added in the behaviour step: cohesion (pack leads, regroup), ferocity (melee damage
## and cooldown), Escort survivor hunting, and the fairness of the new stat in evolution.
## Scenarios run in the real level (prototype map, no wave), in real time (Engine.time_scale would
## also scale the physics delta, so it is not used).

const AREA: String = "res://world/zones/maple_hollow/areas/area_1.tscn"

var _rules: GenomeRules
var _settings: UtilitySettings


func before_each() -> void:
	_rules = load("res://data/genome_rules.tres")
	_settings = load("res://data/utility_ai.tres")


func after_each() -> void:
	get_tree().paused = false


# --- Helpers ---------------------------------------------------------------------------------

func _arena() -> Dictionary:
	var main: Node = load("res://world/main.tscn").instantiate()
	main.autosave = false
	main.deterministic_ai = true
	var wm: WaveManager = main.get_node("WaveManager")
	wm.auto_start = false
	wm.alert_on_spawn = false
	wm.spawn_seed = 7
	wm.log_waves = false
	add_child_autofree(main)
	await wait_physics_frames(3)
	var player: Player = main.get_node("Player")
	player.health = 1.0e9
	return {"main": main, "wm": wm, "player": player}


## A direction from `origin` along which every distance in `dists` is walkable with a clear line.
func _open_direction(main: Node, origin: Vector2, dists: Array) -> Vector2:
	var grid: TerrainGrid = main.terrain_grid
	for k: int in 72:
		var dir: Vector2 = Vector2.from_angle(TAU * k / 72.0)
		var ok: bool = true
		for d: float in dists:
			var p: Vector2 = origin + dir * d
			if not grid.is_walkable(grid.coords.world_to_cell(p)) or not grid.has_line_of_sight(p, origin):
				ok = false
				break
		if ok:
			return dir
	return Vector2.ZERO


func _spawn(wm: WaveManager, at: Vector2, cohesion: float, vision: float = 5.0, ferocity: float = 5.0,
		record: FitnessRecord = null) -> Enemy:
	var g: Genome = Genome.new()
	g.aggression = 0.8
	g.flanking = 0.0
	g.patience = 0.1
	g.cohesion = cohesion
	g.vision = vision
	g.ferocity = ferocity
	var e: Enemy = wm.spawn_enemy(at, g, record)
	e.global_position = at
	_face(e, wm._context.target.global_position)
	return e


## Turns an enemy to look at `point` (its view cone covers it; whether it sees it is up to range,
## line of sight and suspicion).
func _face(e: Enemy, point: Vector2) -> void:
	e.velocity = Vector2.ZERO
	e.rest_facing = e.global_position.direction_to(point)
	e.facing = e.rest_facing


## One pack scenario: A (sees the player, 90 px away) and B, C, D further back (do not see it).
## A is close because it now needs a moment of suspicion (and walks towards the glimpse) before
## it is sure and calls its pack; B must still be within pack_radius of it by then.
## Returns {arrival: {index: seconds}, state: [awareness state per enemy], spent: A's regroup time}.
## B is within pack_radius of A, C and D are not. The level is freed afterwards (one at a time).
func _pack_run(cohesions: Array, seconds: float) -> Dictionary:
	var arena: Dictionary = await _arena()
	var main: Node = arena["main"]
	var wm: WaveManager = arena["wm"]
	var player: Player = arena["player"]
	var dists: Array = [90.0, 175.0, 250.0, 265.0]
	var dir: Vector2 = _open_direction(main, player.global_position, dists)
	assert_ne(dir, Vector2.ZERO, "a straight open line exists next to the spawn")
	var enemies: Array[Enemy] = []
	for i: int in dists.size():
		enemies.append(_spawn(wm, player.global_position + dir * dists[i], cohesions[i], 5.0 if i == 0 else 1.0))
	var arrival: Dictionary = {}
	var frames: int = int(seconds * 60.0)
	for f: int in frames:
		await wait_physics_frames(1)
		for i: int in enemies.size():
			if not arrival.has(i) and enemies[i].global_position.distance_to(player.global_position) <= 40.0:
				arrival[i] = f / 60.0
	var states: Array[int] = []
	for e: Enemy in enemies:
		states.append(e.awareness.state)
	var result: Dictionary = {"arrival": arrival, "state": states, "spent": enemies[0]._regroup_budget.spent}
	main.free()
	await wait_physics_frames(2)
	return result


# --- Cohesion: pure rules --------------------------------------------------------------------

func test_share_strength_needs_both_cohesions() -> void:
	assert_almost_eq(PackCoordination.share_strength(1.0, 1.0, _settings), 0.8, 0.0001)
	assert_almost_eq(PackCoordination.share_strength(0.5, 1.0, _settings), 0.4, 0.0001, "the weaker one decides")
	assert_eq(PackCoordination.share_strength(0.0, 1.0, _settings), 0.0, "a loner sender calls nobody")
	assert_eq(PackCoordination.share_strength(1.0, 0.0, _settings), 0.0, "a loner receiver ignores the call")


func test_count_and_anchor() -> void:
	var mates: PackedVector2Array = PackedVector2Array([Vector2(10, 0), Vector2(0, 20), Vector2(300, 0)])
	assert_eq(PackCoordination.count_within(Vector2.ZERO, mates, 128.0), 2)
	assert_eq(PackCoordination.anchor(Vector2.ZERO, mates, 192.0), Vector2(5, 10), "centroid of the two near ones")
	assert_eq(PackCoordination.anchor(Vector2.ZERO, PackedVector2Array([Vector2(500, 0)]), 192.0), Vector2.INF,
			"nobody to wait for")


func test_regroup_budget_runs_out_and_flicker_does_not_restart_it() -> void:
	var b: PackCoordination.RegroupBudget = PackCoordination.RegroupBudget.new()
	for i: int in 30:
		b.tick(0.1, true, true, _settings)  # 3 s regrouping
	assert_false(b.expired(_settings))
	for i: int in 12:
		b.tick(0.1, true, true, _settings)  # 4.2 s in total
	assert_true(b.expired(_settings), "after regroup_timeout it is spent")
	# The player drops out of sight and comes back within the reset time, again and again.
	for round: int in 10:
		for i: int in 50:
			b.tick(0.1, false, false, _settings)  # 5 s unseen: under regroup_reset_seconds
		b.tick(0.1, true, true, _settings)
	assert_true(b.expired(_settings), "flickering sight never gives the time back")
	for i: int in 70:
		b.tick(0.1, false, false, _settings)  # 7 s unseen: a new chase
	assert_false(b.expired(_settings), "forgiven only after a long time unseen")


func test_regroup_budget_only_counts_regrouping_time() -> void:
	var b: PackCoordination.RegroupBudget = PackCoordination.RegroupBudget.new()
	for i: int in 200:
		b.tick(0.1, false, true, _settings)  # chasing normally, not regrouping
	assert_eq(b.spent, 0.0)


func _visible(distance: float = 120.0, pack: int = 0) -> DecisionInputs:
	var i: DecisionInputs = DecisionInputs.new()
	i.player_visible = true
	i.distance_to_player = distance
	i.regroup_available = true
	i.pack_size = pack
	return i


func test_regroup_action_scores_only_while_the_pack_is_incomplete() -> void:
	var genes: BehaviourWeights = BehaviourWeights.new()
	genes.cohesion = 1.0
	var a: RegroupAction = RegroupAction.new()
	assert_almost_eq(a.score(_visible(), genes, _settings), 0.7, 0.0001)
	assert_eq(a.score(_visible(120.0, 2), genes, _settings), 0.0, "self + 2 = pack of 3: go")
	assert_eq(a.score(_visible(40.0), genes, _settings), 0.0, "already close: fight")
	var expired: DecisionInputs = _visible()
	expired.regroup_expired = true
	assert_eq(a.score(expired, genes, _settings), 0.0, "time is up: go")
	var alone: DecisionInputs = _visible()
	alone.regroup_available = false
	assert_eq(a.score(alone, genes, _settings), 0.0, "nobody to wait for")
	var unseen: DecisionInputs = _visible()
	unseen.player_visible = false
	assert_eq(a.score(unseen, genes, _settings), 0.0)


func test_low_cohesion_never_regroups() -> void:
	var genes: BehaviourWeights = BehaviourWeights.new()
	genes.cohesion = 0.1
	assert_lt(RegroupAction.new().score(_visible(), genes, _settings), _settings.idle_score)


func test_cohesion_never_raises_chase() -> void:
	var loner: BehaviourWeights = BehaviourWeights.new()
	loner.cohesion = 0.0
	var pack: BehaviourWeights = BehaviourWeights.new()
	pack.cohesion = 1.0
	for pack_size: int in [0, 1, 5]:
		var inputs: DecisionInputs = _visible(100.0, pack_size)
		assert_eq(ChaseAction.new().score(inputs, loner, _settings), ChaseAction.new().score(inputs, pack, _settings),
				"Chase ignores cohesion (pack size %d)" % pack_size)


func test_brain_regroups_when_lonely_and_charges_when_the_pack_is_complete() -> void:
	var genes: BehaviourWeights = BehaviourWeights.new()
	genes.aggression = 0.6
	genes.cohesion = 1.0
	var brain: UtilityAI = UtilityAI.new(_settings, genes, 0.0)
	brain.decide(_visible(100.0, 0))
	assert_eq(brain.current, UtilityAction.Type.REGROUP)
	brain.decide(_visible(100.0, 2))
	assert_eq(brain.current, UtilityAction.Type.CHASE, "everyone switches once the pack is together")
	var timid_loner: UtilityAI = UtilityAI.new(_settings, BehaviourWeights.new(), 0.0)
	var low: BehaviourWeights = BehaviourWeights.new()
	low.cohesion = 0.0
	timid_loner.genes = low
	timid_loner.decide(_visible(100.0, 0))
	assert_eq(timid_loner.current, UtilityAction.Type.CHASE, "a loner just charges")


func test_wave_pressure_beats_regroup() -> void:
	var genes: BehaviourWeights = BehaviourWeights.new()
	genes.aggression = 0.1
	genes.cohesion = 1.0
	var brain: UtilityAI = UtilityAI.new(_settings, genes, 0.0)
	var inputs: DecisionInputs = _visible(60.0 + 10.0, 0)
	brain.decide(inputs)
	assert_eq(brain.current, UtilityAction.Type.REGROUP)
	inputs.wave_pressure = 1.0
	brain.decide(inputs)
	assert_eq(brain.current, UtilityAction.Type.CHASE, "a wave that drags on ends the waiting")


# --- Cohesion in the level -------------------------------------------------------------------

func test_cohesive_pack_shares_waits_a_bounded_time_and_arrives_together() -> void:
	var run: Dictionary = await _pack_run([1.0, 1.0, 1.0, 1.0], 9.5)
	var arrival: Dictionary = run["arrival"]
	assert_true(arrival.has(0) and arrival.has(1), "A and the packmate B both reached the player: %s" % str(arrival))
	assert_lt(absf(arrival[0] - arrival[1]), 0.8, "they arrive together")
	assert_gt(arrival[0], 2.0, "A waited for its pack instead of charging alone")
	assert_lt(arrival[0], 9.0, "...but not forever")
	assert_lte(run["spent"], _settings.regroup_timeout + 0.3, "regroup time stays within the budget")
	assert_false(arrival.has(2), "C and D were out of the pack's earshot")


func test_loners_charge_alone_and_call_nobody() -> void:
	var run: Dictionary = await _pack_run([0.0, 0.0, 0.0, 0.0], 4.5)
	var arrival: Dictionary = run["arrival"]
	assert_true(arrival.has(0))
	assert_lt(arrival[0], 2.5, "no waiting without cohesion")
	assert_false(arrival.has(1), "B never heard about the player")
	assert_eq(run["state"][1], Awareness.State.IDLE)


func test_leads_are_shared_only_when_both_are_cohesive() -> void:
	for pair: Array in [[0.0, 1.0], [1.0, 0.0]]:
		var run: Dictionary = await _pack_run([pair[0], pair[1], 1.0, 1.0], 1.5)
		assert_eq(run["state"][1], Awareness.State.IDLE,
				"sender %.0f / receiver %.0f: no call" % [pair[0], pair[1]])
	var run2: Dictionary = await _pack_run([1.0, 1.0, 1.0, 1.0], 1.5)
	assert_ne(run2["state"][1], Awareness.State.IDLE, "both cohesive: B is alerted")


func test_cohesion_changes_no_combat_numbers_and_the_ring_still_has_three_tokens() -> void:
	var a: Genome = Genome.new()
	var b: Genome = Genome.new()
	a.cohesion = 0.0
	b.cohesion = 1.0
	assert_eq(a.move_speed(70.0, _rules), b.move_speed(70.0, _rules))
	assert_eq(a.max_health(30.0, _rules), b.max_health(30.0, _rules))
	assert_eq(a.attack_damage(8.0, _rules), b.attack_damage(8.0, _rules))
	assert_eq(a.attack_cooldown(1.2, _rules), b.attack_cooldown(1.2, _rules))
	var ring: AttackRingSettings = load("res://data/attack_ring.tres")
	assert_eq(ring.max_attackers, 3, "the attack ring is untouched")


func test_a_big_cohesive_pack_never_has_more_than_three_attackers() -> void:
	var arena: Dictionary = await _arena()
	var main: Node = arena["main"]
	var wm: WaveManager = arena["wm"]
	var player: Player = arena["player"]
	var dir: Vector2 = _open_direction(main, player.global_position, [40.0, 60.0, 80.0, 100.0])
	for i: int in 10:
		_spawn(wm, player.global_position + dir * (40.0 + 6.0 * i), 1.0)
	var most: int = 0
	for f: int in 300:
		await wait_physics_frames(1)
		var attackers: int = 0
		for e: Enemy in wm.alive:
			if main.attack_ring.get_role(e.get_instance_id()) == AttackRing.Role.ATTACKING:
				attackers += 1
		most = maxi(most, attackers)
	assert_lte(most, 3, "regrouped packs still queue for the three tokens")
	assert_gt(most, 0, "and they do attack")
	main.free()
	await wait_physics_frames(2)


# --- Ferocity --------------------------------------------------------------------------------

func _duel(ferocity: float) -> Dictionary:
	var arena: Dictionary = await _arena()
	var main: Node = arena["main"]
	var wm: WaveManager = arena["wm"]
	var player: Player = arena["player"]
	var dir: Vector2 = _open_direction(main, player.global_position, [60.0])
	var record: FitnessRecord = FitnessRecord.new()
	var e: Enemy = _spawn(wm, player.global_position + dir * 60.0, 0.0, 5.0, ferocity, record)
	var hits: Array[float] = []
	var before: float = player.health
	var last: float = before
	for f: int in 360:
		await wait_physics_frames(1)
		if player.health < last - 0.001:
			hits.append(last - player.health)
		last = player.health
	var result: Dictionary = {"damage": before - player.health, "hits": hits, "record": record}
	main.free()  # one level at a time: the next duel must not share the tree with this one
	await wait_physics_frames(2)
	return result


func test_ferocity_changes_damage_per_hit_and_hits_per_second_in_a_real_fight() -> void:
	var fierce: Dictionary = await _duel(10.0)
	var gentle: Dictionary = await _duel(1.0)
	var fierce_hits: Array = fierce["hits"]
	var gentle_hits: Array = gentle["hits"]
	assert_gt(fierce_hits.size(), 0, "the savage enemy hits")
	assert_gt(gentle_hits.size(), 0, "the gentle enemy hits")
	assert_almost_eq(fierce_hits[0], 11.2, 0.01, "gene 10: 8 x 1.40 per hit")
	assert_almost_eq(gentle_hits[0], 5.44, 0.01, "gene 1: 8 x 0.68 per hit")
	assert_gt(fierce_hits.size(), gentle_hits.size(), "and swings more often (shorter cooldown)")
	assert_gt(fierce["damage"], gentle["damage"] * 2.2, "clearly more damage over 6 s: %.0f vs %.0f" % [
			fierce["damage"], gentle["damage"]])
	assert_almost_eq(fierce["record"].damage_dealt, fierce["damage"], 0.01, "the fitness record matches what the player lost")


func test_ferocity_sets_the_enemys_attack_stats_and_leaves_the_shared_resource_alone() -> void:
	var arena: Dictionary = await _arena()
	var wm: WaveManager = arena["wm"]
	var e: Enemy = _spawn(wm, (arena["player"] as Player).global_position + Vector2(60, 0), 0.5, 5.0, 10.0)
	assert_almost_eq(e.stats.attack_damage, 11.2, 0.001)
	assert_almost_eq(e.stats.attack_cooldown, 0.96, 0.001)
	assert_almost_eq(e.attack_scale, 1.4, 0.001)
	var base: EnemyStats = load("res://data/runner.tres")
	assert_eq(base.attack_damage, 8.0)
	assert_eq(base.attack_cooldown, 1.2)


# --- Ferocity in evolution -------------------------------------------------------------------

func _random_population(n: int, seed_value: int, budget: int) -> Array[Genome]:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var pop: Array[Genome] = []
	for i: int in n:
		pop.append(Genome.random(rng, _rules, budget))
	return pop


func _evolve(pop: Array[Genome], generations: int, seed_value: int, fitness_of: Callable, budget: int) -> Array[Genome]:
	var ga: GeneticAlgorithm = GeneticAlgorithm.new(load("res://data/ga.tres"), _rules, seed_value)
	for g: int in generations:
		var fit: Array[float] = []
		for genome: Genome in pop:
			fit.append(fitness_of.call(genome))
		pop = ga.next_generation(pop, fit, budget)
		for genome: Genome in pop:
			assert_true(genome.spends_budget(_rules, budget), "gen %d: exactly the budget" % g)
			assert_true(genome.is_valid(_rules, budget))
	return pop


func _mean(pop: Array[Genome], gene: StringName) -> float:
	var total: float = 0.0
	for g: Genome in pop:
		total += g.get(gene)
	return total / pop.size()


func test_random_enemies_are_not_stronger_on_average_than_the_neutral_one() -> void:
	var pop: Array[Genome] = _random_population(400, 5, 20)
	var dps: float = 0.0
	for g: Genome in pop:
		dps += g.melee_dps_factor(_rules)
		assert_almost_eq(g.stat_total(), 20.0, 0.001, "no free points")
	dps /= pop.size()
	assert_between(dps, 0.95, 1.20, "average random melee DPS factor %.3f (neutral = 1)" % dps)


func test_selection_blind_to_ferocity_does_not_drift_it() -> void:
	# Fitness is a pseudo-random number that ignores every gene. One small population drifts by
	# chance, so average many runs: no stat, ferocity included, may favour itself.
	var sums: Dictionary = {&"speed": 0.0, &"health": 0.0, &"vision": 0.0, &"ferocity": 0.0}
	var runs: int = 40
	for seed_value: int in runs:
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = seed_value * 31 + 1
		var pop: Array[Genome] = _evolve(_random_population(20, seed_value + 100, 20), 15, seed_value,
				func(_g: Genome) -> float: return rng.randf(), 20)
		for gene: StringName in sums:
			sums[gene] += _mean(pop, gene) / runs
	for gene: StringName in sums:
		assert_between(sums[gene], 4.55, 5.45, "mean %s over %d seeds = %.2f (neutral 5)" % [gene, runs, sums[gene]])


func test_selection_that_rewards_ferocity_pays_for_it_with_the_other_stats() -> void:
	var pop: Array[Genome] = _evolve(_random_population(20, 9, 20), 30, 9,
			func(g: Genome) -> float: return g.ferocity, 20)
	var fer: float = _mean(pop, &"ferocity")
	var rest: float = _mean(pop, &"speed") + _mean(pop, &"health") + _mean(pop, &"vision")
	assert_gt(fer, 6.0, "evolution CAN pick ferocity when it pays (%.2f)" % fer)
	assert_almost_eq(fer + rest, 20.0, 0.001, "but every point came out of speed / health / vision")
	assert_lt(rest, 14.0)


func test_seeded_evolution_with_ferocity_is_reproducible() -> void:
	var f: Callable = func(g: Genome) -> float: return g.aggression + g.ferocity * 0.1
	var a: Array[Genome] = _evolve(_random_population(20, 4, 20), 10, 77, f, 22)
	var b: Array[Genome] = _evolve(_random_population(20, 4, 20), 10, 77, f, 22)
	assert_eq(a.map(func(g: Genome) -> Dictionary: return g.to_dict()), b.map(func(g: Genome) -> Dictionary: return g.to_dict()))


func test_budget_stays_exact_through_the_whole_ramp() -> void:
	var pop: Array[Genome] = _random_population(20, 12, 20)
	var ga: GeneticAlgorithm = GeneticAlgorithm.new(load("res://data/ga.tres"), _rules, 12)
	for wave: int in range(2, 40):
		var budget: int = _rules.budget_for_wave(wave)
		var fit: Array[float] = []
		for g: Genome in pop:
			fit.append(g.aggression)
		pop = ga.next_generation(pop, fit, budget)
		for g: Genome in pop:
			assert_true(g.spends_budget(_rules, budget), "wave %d budget %d: %s" % [wave, budget, g.describe()])


# --- Escort survivor hunting -----------------------------------------------------------------

func _escort_level() -> Dictionary:
	var c: LevelConfig = LevelConfig.new()
	c.id = "test_escort_hunt"
	c.areas = [load(AREA)]
	c.waves = 1
	c.spawn_delay_seconds = 0.1
	c.objective = ObjectiveConfig.new()
	c.objective.type = ObjectiveConfig.Type.ESCORT
	var main: Node = load("res://world/main.tscn").instantiate()
	main.autosave = false
	main.level_config = c
	main.deterministic_ai = true
	var wm: WaveManager = main.get_node("WaveManager")
	wm.spawn_seed = 11
	wm.log_waves = false
	add_child_autofree(main)
	await wait_physics_frames(12)
	var player: Player = main.get_node("Player")
	player.health = 1.0e9
	for e: Enemy in wm.alive:
		e.set_physics_process(false)  # the wave stays frozen; the test enemy is switched on by hand
	return {"main": main, "wm": wm, "player": player, "escort": main.objective}


func test_hunt_survivor_scores_by_distance_and_needs_sight() -> void:
	var genes: BehaviourWeights = BehaviourWeights.new()
	genes.aggression = 0.8
	var near: DecisionInputs = DecisionInputs.new()
	near.survivor_visible = true
	near.survivor_distance = 30.0
	var far: DecisionInputs = DecisionInputs.new()
	far.survivor_visible = true
	far.survivor_distance = 150.0
	var action: HuntSurvivorAction = HuntSurvivorAction.new()
	assert_gt(action.score(near, genes, _settings), action.score(far, genes, _settings), "nearer survivor, higher score")
	assert_gt(action.score(far, genes, _settings), _settings.idle_score)
	near.survivor_visible = false
	assert_eq(action.score(near, genes, _settings), 0.0, "never without perceiving it")


func test_closer_target_wins_between_player_and_survivor() -> void:
	var genes: BehaviourWeights = BehaviourWeights.new()
	genes.aggression = 0.9
	genes.flanking = 0.0
	var brain: UtilityAI = UtilityAI.new(_settings, genes, 0.0)
	var i: DecisionInputs = DecisionInputs.new()
	i.player_visible = true
	i.distance_to_player = 140.0
	i.survivor_visible = true
	i.survivor_distance = 30.0
	brain.decide(i)
	assert_eq(brain.current, UtilityAction.Type.HUNT_SURVIVOR)
	i.distance_to_player = 20.0
	i.survivor_distance = 140.0
	brain = UtilityAI.new(_settings, genes, 0.0)
	brain.decide(i)
	assert_eq(brain.current, UtilityAction.Type.CHASE)


func test_survivor_is_perceived_by_the_players_sight_rules() -> void:
	var lvl: Dictionary = await _escort_level()
	var main: Node = lvl["main"]
	var wm: WaveManager = lvl["wm"]
	var escort: EscortObjective = lvl["escort"]
	var grid: TerrainGrid = main.terrain_grid
	var e: Enemy = wm.alive[0]
	var seen_at: Vector2 = Vector2.INF
	var hidden_at: Vector2 = Vector2.INF
	for k: int in 72:
		var p: Vector2 = escort.survivor + Vector2.from_angle(TAU * k / 72.0) * 90.0
		if not grid.is_walkable(grid.coords.world_to_cell(p)):
			continue
		if grid.has_line_of_sight(p, escort.survivor):
			seen_at = p if seen_at == Vector2.INF else seen_at
		else:
			hidden_at = p if hidden_at == Vector2.INF else hidden_at
	assert_ne(seen_at, Vector2.INF, "a spot with a clear line exists")
	e.global_position = seen_at
	_face(e, escort.survivor)
	e._can_perceive_player()
	e._update_survivor_sight()
	assert_true(e.survivor_visible, "clear line within sight range")
	e.facing = -e.facing
	e._update_survivor_sight()
	assert_false(e.survivor_visible, "looking the other way (outside the view cone) it is not seen")
	if hidden_at != Vector2.INF:
		e.global_position = hidden_at
		_face(e, escort.survivor)
		e._can_perceive_player()
		e._update_survivor_sight()
		assert_false(e.survivor_visible, "a wall in between hides it")
	e.global_position = seen_at
	_face(e, escort.survivor)
	e._can_perceive_player()
	escort.survivor_health = 0.0
	e._update_survivor_sight()
	assert_false(e.survivor_visible, "a dead survivor is no target")


func test_enemy_hunts_hits_and_is_credited_for_the_survivor_while_the_player_is_far_away() -> void:
	var lvl: Dictionary = await _escort_level()
	var main: Node = lvl["main"]
	var wm: WaveManager = lvl["wm"]
	var player: Player = lvl["player"]
	var escort: EscortObjective = lvl["escort"]
	var grid: TerrainGrid = main.terrain_grid
	var e: Enemy = wm.alive[0]
	var spot: Vector2 = Vector2.INF
	for k: int in 72:
		var p: Vector2 = escort.survivor + Vector2.from_angle(TAU * k / 72.0) * 90.0
		if grid.is_walkable(grid.coords.world_to_cell(p)) and grid.has_line_of_sight(p, escort.survivor):
			spot = p
			break
	e.global_position = spot
	_face(e, escort.survivor)
	e.set_physics_process(true)
	player.global_position = main.current_map().get_exit()  # far away: the survivor doesn't follow
	var hp: float = escort.survivor_health
	var moved_calm: bool = false
	for f: int in 240:
		var before: Vector2 = escort.survivor
		await wait_physics_frames(1)
		if escort.survivor != before and not escort.scared:
			moved_calm = true
	assert_false(moved_calm, "the survivor never followed the far-away player (it only backed off the enemy)")
	assert_lt(e.global_position.distance_to(escort.survivor), 20.0, "the enemy walked up to the survivor")
	assert_lt(escort.survivor_health, hp, "and hurt it")
	assert_gt(e.fitness_record.objective_score, 0.0, "O is credited to that enemy")
	assert_true(e.brain.current == UtilityAction.Type.HUNT_SURVIVOR, "by hunting, not by luck")


func test_at_most_three_enemies_hit_the_survivor_and_ferocity_scales_the_hit() -> void:
	var lvl: Dictionary = await _escort_level()
	var wm: WaveManager = lvl["wm"]
	var escort: EscortObjective = lvl["escort"]
	var crowd: Array[Enemy] = []
	for i: int in 6:
		var e: Enemy = wm.alive[i]
		e.global_position = escort.survivor + Vector2(float(i), 0.0)
		crowd.append(e)
	var attackers: Array[Enemy] = escort.nearest_attackers()
	assert_eq(attackers.size(), 3, "capped at escort_max_attackers")
	assert_true(attackers.has(crowd[0]) and attackers.has(crowd[1]) and attackers.has(crowd[2]), "the nearest ones")
	var hp: float = escort.survivor_health
	escort.tick(0.016)
	var lost: float = hp - escort.survivor_health
	var most: float = 0.0
	for e: Enemy in attackers:
		most += escort.config.escort_hit_damage * e.attack_scale
	assert_almost_eq(lost, most, 0.001, "exactly the three nearest hit, each scaled by its own ferocity")
	crowd[0].attack_scale = 1.4
	assert_gt(escort.config.escort_hit_damage * crowd[0].attack_scale, escort.config.escort_hit_damage)

extends GutTest
## Tests for the three prototype action scorers and the data files they read.

var _s: UtilitySettings
var _g: BehaviourWeights


func before_each() -> void:
	_s = UtilitySettings.new()  # defaults match data/utility_ai.tres
	_g = BehaviourWeights.new()
	_g.aggression = 1.0
	_g.flanking = 1.0
	_g.patience = 1.0


func _visible(distance: float, facing_dot: float = 1.0, allies: int = 0, flank_ok: bool = true) -> DecisionInputs:
	var i: DecisionInputs = DecisionInputs.new()
	i.player_visible = true
	i.distance_to_player = distance
	i.player_facing_dot = facing_dot
	i.allies_chasing = allies
	i.flank_point_available = flank_ok
	return i


func _lead(age: float) -> DecisionInputs:
	var i: DecisionInputs = DecisionInputs.new()
	i.has_lead = true
	i.lead_age = age
	return i


# --- Chase ---------------------------------------------------------------------------

func test_chase_zero_when_not_visible() -> void:
	assert_eq(ChaseAction.new().score(_lead(0.0), _g, _s), 0.0)


func test_chase_higher_when_closer() -> void:
	var chase: ChaseAction = ChaseAction.new()
	assert_almost_eq(chase.score(_visible(0.0), _g, _s), 1.0, 0.001, "touching: full score")
	assert_almost_eq(chase.score(_visible(80.0), _g, _s), 0.75, 0.001, "half range")
	assert_almost_eq(chase.score(_visible(500.0), _g, _s), 0.5, 0.001, "out of range: base only")


func test_chase_scaled_by_aggression() -> void:
	_g.aggression = 0.5
	assert_almost_eq(ChaseAction.new().score(_visible(0.0), _g, _s), 0.5, 0.001)


# --- Flank ---------------------------------------------------------------------------

func test_flank_needs_visible_allies_and_point() -> void:
	var flank: FlankAction = FlankAction.new()
	assert_eq(flank.score(_lead(0.0), _g, _s), 0.0, "not visible")
	assert_eq(flank.score(_visible(100.0, -1.0, 0), _g, _s), 0.0, "no allies chasing")
	assert_eq(flank.score(_visible(100.0, -1.0, 2, false), _g, _s), 0.0, "no flank point")
	assert_gt(flank.score(_visible(100.0, -1.0, 2), _g, _s), 0.0)


func test_flank_best_when_player_looks_away() -> void:
	var flank: FlankAction = FlankAction.new()
	var back_turned: float = flank.score(_visible(100.0, -1.0, 2), _g, _s)
	var looking_at_us: float = flank.score(_visible(100.0, 1.0, 2), _g, _s)
	assert_almost_eq(back_turned, 1.0, 0.001)
	assert_almost_eq(looking_at_us, 0.4, 0.001, "facing base only")


func test_flank_needs_distance() -> void:
	var flank: FlankAction = FlankAction.new()
	assert_eq(flank.score(_visible(20.0, -1.0, 2), _g, _s), 0.0, "too close: just attack")
	assert_almost_eq(flank.score(_visible(56.0, -1.0, 2), _g, _s), 0.5, 0.001, "half way up the ramp")


func test_flank_more_allies_more_score() -> void:
	var flank: FlankAction = FlankAction.new()
	assert_almost_eq(flank.score(_visible(100.0, -1.0, 1), _g, _s), 0.5, 0.001)
	assert_almost_eq(flank.score(_visible(100.0, -1.0, 5), _g, _s), 1.0, 0.001, "clamped")


# --- Investigate ---------------------------------------------------------------------

func test_investigate_needs_lead_and_no_sight() -> void:
	var inv: InvestigateAction = InvestigateAction.new()
	assert_eq(inv.score(DecisionInputs.new(), _g, _s), 0.0, "no lead")
	var seen: DecisionInputs = _visible(50.0)
	seen.has_lead = true
	assert_eq(inv.score(seen, _g, _s), 0.0, "player visible: chase instead")
	assert_almost_eq(inv.score(_lead(0.0), _g, _s), 1.0, 0.001)


func test_investigate_decays_with_age() -> void:
	var inv: InvestigateAction = InvestigateAction.new()
	assert_almost_eq(inv.score(_lead(4.0), _g, _s), 0.7, 0.001, "half memory_time")
	assert_almost_eq(inv.score(_lead(100.0), _g, _s), 0.4, 0.001, "stale: base only")


func test_investigate_scaled_by_patience() -> void:
	_g.patience = 0.2
	assert_almost_eq(InvestigateAction.new().score(_lead(100.0), _g, _s), 0.08, 0.001,
		"impatient + stale lead scores below idle (0.1)")


# --- Data files ----------------------------------------------------------------------

func test_data_files() -> void:
	var s: UtilitySettings = load("res://data/utility_ai.tres")
	assert_almost_eq(s.decision_interval, 0.2, 0.0001, "5 Hz")
	assert_gt(s.momentum_bonus, 0.0)
	var g: BehaviourWeights = load("res://data/runner_behaviour.tres")
	for gene: float in [g.aggression, g.flanking, g.patience]:
		assert_between(gene, 0.0, 1.0)
	var runner: EnemyStats = load("res://data/runner.tres")
	assert_eq(runner.behaviour, g)
	assert_eq(runner.utility_settings, s)
	assert_almost_eq(s.provocation_weight, 1.0, 0.0001)
	assert_between(s.lost_sight_strength, 0.0, 1.0)


# --- Provocation (lead strength) -----------------------------------------------------

func _strong_lead(age: float, strength: float) -> DecisionInputs:
	var i: DecisionInputs = _lead(age)
	i.lead_strength = strength
	return i


func test_strong_provocation_raises_lazy_drive() -> void:
	_g.patience = 0.05
	var inv: InvestigateAction = InvestigateAction.new()
	# drive = 0.05 + 0.95 * strength; fresh lead -> score = drive
	assert_almost_eq(inv.score(_strong_lead(0.0, 0.0), _g, _s), 0.05, 0.0001, "no provocation: patience only")
	assert_almost_eq(inv.score(_strong_lead(0.0, 1.0), _g, _s), 1.0, 0.0001, "point-blank: full drive")
	assert_almost_eq(inv.score(_strong_lead(0.0, 0.5), _g, _s), 0.525, 0.0001)


func test_provocation_matters_less_for_patient_enemies() -> void:
	_g.patience = 0.9
	var inv: InvestigateAction = InvestigateAction.new()
	var faint: float = inv.score(_strong_lead(0.0, 0.0), _g, _s)
	var loud: float = inv.score(_strong_lead(0.0, 1.0), _g, _s)
	assert_almost_eq(faint, 0.9, 0.0001)
	assert_almost_eq(loud - faint, 0.1, 0.0001, "already hungry: little left to add")


func test_provocation_weight_zero_restores_patience_only() -> void:
	_g.patience = 0.05
	_s.provocation_weight = 0.0
	assert_almost_eq(InvestigateAction.new().score(_strong_lead(0.0, 1.0), _g, _s), 0.05, 0.0001)


func test_provoked_lead_still_goes_stale() -> void:
	_g.patience = 0.05
	var inv: InvestigateAction = InvestigateAction.new()
	assert_almost_eq(inv.score(_strong_lead(100.0, 1.0), _g, _s), 0.4, 0.0001, "drive 1 x stale base 0.4")

extends GutTest
## Tests for UtilityAI: picking the best action, momentum, idle fallback, 5 Hz timing, and
## realistic transition sequences.

const T := UtilityAction.Type

var _s: UtilitySettings
var _g: BehaviourWeights


func before_each() -> void:
	_s = UtilitySettings.new()
	_g = BehaviourWeights.new()  # 0.6 / 0.6 / 0.6, like the Runner


func _visible(distance: float, facing_dot: float = 1.0, allies: int = 0) -> DecisionInputs:
	var i: DecisionInputs = DecisionInputs.new()
	i.player_visible = true
	i.distance_to_player = distance
	i.player_facing_dot = facing_dot
	i.allies_chasing = allies
	i.flank_point_available = true
	return i


func _lead(age: float) -> DecisionInputs:
	var i: DecisionInputs = DecisionInputs.new()
	i.has_lead = true
	i.lead_age = age
	return i


func test_starts_idle_and_stays_idle_with_nothing_to_do() -> void:
	var ai: UtilityAI = UtilityAI.new(_s, _g)
	assert_eq(ai.current, T.IDLE)
	assert_eq(ai.decide(DecisionInputs.new()), T.IDLE)
	assert_eq(ai.switches, 0)


func test_visible_player_alone_means_chase() -> void:
	var ai: UtilityAI = UtilityAI.new(_s, _g)
	assert_eq(ai.decide(_visible(60.0)), T.CHASE)


func test_allies_chasing_and_back_turned_means_flank() -> void:
	var ai: UtilityAI = UtilityAI.new(_s, _g)
	# flank 0.6 * 1 * 1 * 1 = 0.6  vs  chase 0.6 * (0.5 + 0.5 * 0.375) = 0.4125
	assert_eq(ai.decide(_visible(100.0, -1.0, 3)), T.FLANK)


func test_player_looking_at_us_means_chase_not_flank() -> void:
	var ai: UtilityAI = UtilityAI.new(_s, _g)
	# flank 0.6 * 0.4 = 0.24  vs  chase 0.4125
	assert_eq(ai.decide(_visible(100.0, 1.0, 3)), T.CHASE)


func test_lead_without_sight_means_investigate() -> void:
	var ai: UtilityAI = UtilityAI.new(_s, _g)
	assert_eq(ai.decide(_lead(0.5)), T.INVESTIGATE)


func test_impatient_enemy_ignores_old_noise() -> void:
	_g.patience = 0.25
	var ai: UtilityAI = UtilityAI.new(_s, _g)
	# Idle has momentum too: leaving idle needs more than 0.1 + 0.1.
	assert_eq(ai.decide(_lead(0.0)), T.INVESTIGATE, "fresh noise: 0.25 > idle 0.1 + momentum 0.1")
	assert_eq(ai.decide(_lead(20.0)), T.IDLE, "stale: raw 0.1 is not above idle, momentum can't save it")


func test_very_impatient_enemy_ignores_even_fresh_noise() -> void:
	_g.patience = 0.15
	var ai: UtilityAI = UtilityAI.new(_s, _g)
	assert_eq(ai.decide(_lead(0.0)), T.IDLE, "0.15 does not beat idle 0.1 + momentum 0.1")


func test_momentum_keeps_current_action_on_small_differences() -> void:
	var ai: UtilityAI = UtilityAI.new(_s, _g)
	ai.decide(_visible(100.0, 1.0, 3))
	assert_eq(ai.current, T.CHASE)
	# Player half turns away: flank 0.6 * (0.4 + 0.6 * 0.75) = 0.51 vs chase 0.4125 + 0.1 momentum = 0.5125.
	assert_eq(ai.decide(_visible(100.0, -0.5, 3)), T.CHASE, "0.51 does not beat 0.5125")
	# Back fully turned: flank 0.6 clearly wins.
	assert_eq(ai.decide(_visible(100.0, -1.0, 3)), T.FLANK)
	assert_eq(ai.switches, 2)


func test_zero_score_action_is_dropped_despite_momentum() -> void:
	var ai: UtilityAI = UtilityAI.new(_s, _g)
	ai.decide(_visible(60.0))
	assert_eq(ai.current, T.CHASE)
	assert_eq(ai.decide(DecisionInputs.new()), T.IDLE, "can't keep chasing an unseen player")


func test_scores_are_recorded() -> void:
	var ai: UtilityAI = UtilityAI.new(_s, _g)
	ai.decide(_visible(100.0, -1.0, 3))
	assert_almost_eq(ai.last_scores[T.FLANK], 0.6, 0.001)
	assert_almost_eq(ai.last_scores[T.CHASE], 0.4125, 0.001)
	assert_eq(ai.last_scores[T.INVESTIGATE], 0.0)
	assert_eq(ai.last_scores[T.IDLE], 0.1)


func test_decides_at_five_hz() -> void:
	var ai: UtilityAI = UtilityAI.new(_s, _g)
	var decisions: int = 0
	for frame: int in 60:  # one second at 60 fps
		if ai.tick(1.0 / 60.0):
			decisions += 1
	assert_eq(decisions, 5)


func test_phase_staggers_first_decision() -> void:
	var early: UtilityAI = UtilityAI.new(_s, _g, 0.0)
	var late: UtilityAI = UtilityAI.new(_s, _g, 0.5)
	assert_true(early.tick(1.0 / 60.0), "phase 0 decides on the first frame")
	var frames: int = 1
	while not late.tick(1.0 / 60.0):
		frames += 1
	assert_between(frames, 6, 7, "phase 0.5 waits half an interval (0.1 s = 6 frames, +1 for float rounding)")


func test_request_decision_forces_next_tick() -> void:
	var ai: UtilityAI = UtilityAI.new(_s, _g, 0.9)
	ai.request_decision()
	assert_true(ai.tick(1.0 / 60.0))


func test_long_frame_does_not_stack_decisions() -> void:
	var ai: UtilityAI = UtilityAI.new(_s, _g)
	assert_true(ai.tick(1.0))
	assert_false(ai.tick(1.0 / 60.0), "one decision, not five catch-up decisions")


func test_full_encounter_sequence() -> void:
	# Hear a shot -> investigate -> see the player -> allies engage, player turns away -> flank
	# -> player turns round -> chase -> player hides, lead goes stale -> idle.
	var ai: UtilityAI = UtilityAI.new(_s, _g)
	var seq: Array = []
	seq.append(ai.decide(_lead(0.0)))
	seq.append(ai.decide(_lead(1.0)))
	seq.append(ai.decide(_visible(120.0, 1.0, 0)))
	seq.append(ai.decide(_visible(100.0, -1.0, 3)))
	seq.append(ai.decide(_visible(90.0, 1.0, 3)))
	seq.append(ai.decide(_lead(0.0)))
	var no_lead: DecisionInputs = DecisionInputs.new()
	seq.append(ai.decide(no_lead))
	assert_eq(seq, [T.INVESTIGATE, T.INVESTIGATE, T.CHASE, T.FLANK, T.CHASE, T.INVESTIGATE, T.IDLE])

extends GutTest
## Wave pressure (the Bloom's hunger ramp) and the kill-all wave deadline: a wave that drags on
## pulls lazy enemies towards the lead they hold, and is closed after wave_deadline_seconds.

var _s: UtilitySettings
var _g: BehaviourWeights


func before_each() -> void:
	_s = UtilitySettings.new()
	_g = BehaviourWeights.new()
	_g.patience = 0.05  # the laziest kind


func _stale_lead(pressure: float) -> DecisionInputs:
	var i: DecisionInputs = DecisionInputs.new()
	i.has_lead = true
	i.lead_age = 100.0  # completely stale
	i.lead_strength = 0.0
	i.wave_pressure = pressure
	return i


# --- The pure ramp ---------------------------------------------------------------------

func test_pressure_is_zero_then_ramps_then_stays_at_one() -> void:
	assert_eq(_s.wave_pressure(0.0), 0.0)
	assert_eq(_s.wave_pressure(30.0), 0.0, "ramp starts at 30 s")
	assert_almost_eq(_s.wave_pressure(45.0), 0.5, 0.0001)
	assert_eq(_s.wave_pressure(60.0), 1.0)
	assert_eq(_s.wave_pressure(1000.0), 1.0)


func test_zero_length_ramp_steps_instead_of_dividing_by_zero() -> void:
	_s.pressure_ramp_seconds = 0.0
	assert_eq(_s.wave_pressure(29.0), 0.0)
	assert_eq(_s.wave_pressure(30.0), 1.0)


func test_huge_start_turns_the_ramp_off() -> void:
	_s.pressure_start_seconds = 1.0e9
	assert_eq(_s.wave_pressure(5000.0), 0.0)


func test_data_file_values() -> void:
	var data: UtilitySettings = load("res://data/utility_ai.tres")
	assert_eq(data.pressure_start_seconds, 30.0)
	assert_eq(data.pressure_ramp_seconds, 30.0)


# --- The score -------------------------------------------------------------------------

func test_lazy_enemy_ignores_a_stale_lead_without_pressure() -> void:
	var score: float = InvestigateAction.new().score(_stale_lead(0.0), _g, _s)
	assert_lt(score, _s.idle_score, "below idle: it stays put (the stall)")


func test_full_pressure_sends_even_the_laziest_enemy() -> void:
	var score: float = InvestigateAction.new().score(_stale_lead(1.0), _g, _s)
	assert_almost_eq(score, _s.investigate_base, 0.0001)
	assert_gt(score, _s.idle_score + _s.momentum_bonus * 0.0, "above idle")


func test_pressure_never_creates_a_lead_or_overrides_sight() -> void:
	var none: DecisionInputs = DecisionInputs.new()
	none.wave_pressure = 1.0
	assert_eq(InvestigateAction.new().score(none, _g, _s), 0.0, "no lead, nothing to investigate")
	var seen: DecisionInputs = _stale_lead(1.0)
	seen.player_visible = true
	assert_eq(InvestigateAction.new().score(seen, _g, _s), 0.0, "seeing the player is Chase's business")


func test_pressure_does_not_change_a_patient_enemys_score() -> void:
	_g.patience = 1.0
	var calm: float = InvestigateAction.new().score(_stale_lead(0.0), _g, _s)
	var hungry: float = InvestigateAction.new().score(_stale_lead(1.0), _g, _s)
	assert_eq(calm, hungry, "max(drive, pressure) = drive when already at 1")


func test_pressure_sends_a_timid_enemy_that_is_watching_the_player() -> void:
	_g.aggression = 0.1
	var seen: DecisionInputs = DecisionInputs.new()
	seen.player_visible = true
	seen.distance_to_player = 130.0
	assert_lt(ChaseAction.new().score(seen, _g, _s), _s.idle_score, "timid: it just watches")
	seen.wave_pressure = 1.0
	assert_gt(ChaseAction.new().score(seen, _g, _s), _s.idle_score, "hunger: it comes")
	var unseen: DecisionInputs = DecisionInputs.new()
	unseen.wave_pressure = 1.0
	assert_eq(ChaseAction.new().score(unseen, _g, _s), 0.0, "still needs to see the player")


func test_brain_picks_investigate_under_pressure() -> void:
	var brain: UtilityAI = UtilityAI.new(_s, _g, 0.0)
	brain.decide(_stale_lead(0.0))
	assert_eq(brain.current, UtilityAction.Type.IDLE)
	brain.decide(_stale_lead(1.0))
	assert_eq(brain.current, UtilityAction.Type.INVESTIGATE)


# --- In the level ----------------------------------------------------------------------

func _level() -> Dictionary:
	var main: Node = load("res://world/main.tscn").instantiate()
	main.autosave = false
	var wm: WaveManager = main.get_node("WaveManager")
	wm.log_waves = false
	wm.spawn_seed = 7
	wm.pause_between_waves = false
	add_child_autofree(main)
	await wait_physics_frames(2)
	main.get_node("Player").health = 100000.0
	return {"main": main, "wm": wm}


func test_enemies_read_the_wave_clock() -> void:
	var lvl: Dictionary = await _level()
	var wm: WaveManager = lvl["wm"]
	wm.wave_deadline_seconds = 0.0  # this test pokes the clock past the deadline
	wm._context.wave_seconds = 0.0
	var e: Enemy = wm.alive[0]
	e._gather_inputs()
	assert_eq(e._inputs.wave_pressure, 0.0)
	wm.wave_seconds = 100.0
	await wait_physics_frames(1)
	e._gather_inputs()
	assert_eq(e._inputs.wave_pressure, 1.0, "WaveManager publishes its clock to the enemies")


func test_deadline_ends_a_kill_all_wave_and_scores_survivors() -> void:
	var lvl: Dictionary = await _level()
	var wm: WaveManager = lvl["wm"]
	wm.wave_deadline_seconds = 1.0
	watch_signals(wm)
	await wait_physics_frames(75)
	assert_signal_emitted(wm, "wave_ended")
	assert_signal_emitted(wm, "generation_bred")
	assert_false(wm.is_wave_running())
	var survived: int = 0
	for r: Dictionary in wm.last_wave_results:
		survived += 0 if (r["record"] as FitnessRecord).died else 1
	assert_gt(survived, 0, "survivors are scored as survivors")


func test_deadline_is_off_when_zero_and_for_objective_waves() -> void:
	var lvl: Dictionary = await _level()
	var wm: WaveManager = lvl["wm"]
	wm.wave_deadline_seconds = 0.0
	await wait_physics_frames(75)
	assert_true(wm.is_wave_running(), "0 = no deadline")
	wm.wave_deadline_seconds = 0.5
	wm.auto_end_when_all_dead = false  # Hold / Escort / Purge / Extract / Stealth / Apex
	await wait_physics_frames(10)
	assert_true(wm.is_wave_running(), "objective waves end by their goal")

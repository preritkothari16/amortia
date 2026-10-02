extends GutTest
## Tests for FitnessRecord (raw facts), FitnessSettings and Fitness (normalise + weight).

const DT: float = 1.0 / 60.0

var _s: FitnessSettings


func before_each() -> void:
	_s = FitnessSettings.new()  # GDD defaults


func _record(damage: float, pressure: float, alive: float, objective: float = 0.0) -> FitnessRecord:
	var r: FitnessRecord = FitnessRecord.new()
	r.damage_dealt = damage
	r.pressure_seconds = pressure
	r.alive_seconds = alive
	r.objective_score = objective
	return r


# --- FitnessRecord -------------------------------------------------------------------

func test_tick_counts_alive_and_pressure() -> void:
	var r: FitnessRecord = FitnessRecord.new()
	for i: int in 60:
		r.tick(DT, 100.0, 64.0)  # 1 s far away
	for i: int in 30:
		r.tick(DT, 40.0, 64.0)   # 0.5 s close
	assert_almost_eq(r.alive_seconds, 1.5, 0.0001)
	assert_almost_eq(r.pressure_seconds, 0.5, 0.0001)


func test_pressure_radius_is_inclusive() -> void:
	var r: FitnessRecord = FitnessRecord.new()
	r.tick(1.0, 64.0, 64.0)
	assert_eq(r.pressure_seconds, 1.0)


func test_death_freezes_record() -> void:
	var r: FitnessRecord = FitnessRecord.new()
	r.tick(2.0, 10.0, 64.0)
	r.mark_dead()
	r.tick(5.0, 10.0, 64.0)
	r.add_damage(10.0)
	r.add_objective(1.0)
	assert_true(r.died)
	assert_eq(r.alive_seconds, 2.0)
	assert_eq(r.pressure_seconds, 2.0)
	assert_eq(r.damage_dealt, 0.0)
	assert_eq(r.objective_score, 0.0)


func test_freeze_marks_survivor() -> void:
	var r: FitnessRecord = FitnessRecord.new()
	r.tick(3.0, 999.0, 64.0)
	r.freeze()
	r.mark_dead()  # e.g. killed after the wave was scored: does not change the result
	assert_false(r.died)
	assert_true(r.frozen)
	r.tick(1.0, 0.0, 64.0)
	assert_eq(r.alive_seconds, 3.0)


func test_damage_and_objective_accumulate() -> void:
	var r: FitnessRecord = FitnessRecord.new()
	r.add_damage(10.0)
	r.add_damage(5.0)
	r.add_damage(-3.0)  # ignored
	r.add_objective(0.5)
	assert_eq(r.damage_dealt, 15.0)
	assert_eq(r.objective_score, 0.5)


func test_new_record_is_all_zero() -> void:
	var d: Dictionary = FitnessRecord.new().to_dict()
	assert_eq(d["damage_dealt"], 0.0)
	assert_eq(d["pressure_seconds"], 0.0)
	assert_eq(d["alive_seconds"], 0.0)
	assert_eq(d["objective_score"], 0.0)
	assert_false(d["died"])


# --- Normalisation -------------------------------------------------------------------

func test_normalise_clamps_and_handles_zero_cap() -> void:
	assert_eq(Fitness.normalise(25.0, 50.0), 0.5)
	assert_eq(Fitness.normalise(80.0, 50.0), 1.0)
	assert_eq(Fitness.normalise(-5.0, 50.0), 0.0)
	assert_eq(Fitness.normalise(5.0, 0.0), 0.0)


func test_components_use_wave_duration_by_default() -> void:
	var f: Fitness = Fitness.new(_s)
	var c: Dictionary[StringName, float] = f.components(_record(25.0, 10.0, 20.0), 40.0)
	assert_almost_eq(c[Fitness.D], 0.5, 0.0001, "25 / 50 damage cap")
	assert_almost_eq(c[Fitness.P], 0.25, 0.0001, "10 s of a 40 s wave")
	assert_almost_eq(c[Fitness.S], 0.5, 0.0001, "20 s of a 40 s wave")
	assert_eq(c[Fitness.O], 0.0)


func test_fixed_caps_override_wave_duration() -> void:
	_s.pressure_cap_seconds = 20.0
	_s.survival_cap_seconds = 30.0
	var c: Dictionary[StringName, float] = Fitness.new(_s).components(_record(0.0, 10.0, 15.0), 99.0)
	assert_almost_eq(c[Fitness.P], 0.5, 0.0001)
	assert_almost_eq(c[Fitness.S], 0.5, 0.0001)


func test_zero_length_wave_gives_zero_not_nan() -> void:
	var c: Dictionary[StringName, float] = Fitness.new(_s).components(_record(0.0, 0.0, 0.0), 0.0)
	assert_eq(c[Fitness.P], 0.0)
	assert_eq(c[Fitness.S], 0.0)


# --- Weighted score ------------------------------------------------------------------

func test_gdd_formula() -> void:
	# D 0.5, P 0.25, S 0.5, O 1.0 -> 0.4*0.5 + 0.25*0.25 + 0.15*0.5 + 0.2*1.0 = 0.5375
	var f: Fitness = Fitness.new(_s)
	assert_almost_eq(f.score(_record(25.0, 10.0, 20.0, 1.0), 40.0), 0.5375, 0.0001)


func test_perfect_and_empty() -> void:
	var f: Fitness = Fitness.new(_s)
	assert_almost_eq(f.score(_record(999.0, 999.0, 999.0, 999.0), 10.0), 1.0, 0.0001, "weights sum to 1")
	assert_eq(f.score(FitnessRecord.new(), 10.0), 0.0)


func test_objective_stays_zero_without_objectives() -> void:
	var f: Fitness = Fitness.new(_s)
	var survivor: FitnessRecord = _record(0.0, 40.0, 40.0)
	assert_eq(f.components(survivor, 40.0)[Fitness.O], 0.0)
	assert_almost_eq(f.score(survivor, 40.0), 0.25 + 0.15, 0.0001, "max without damage or objectives")


func test_weights_are_configurable() -> void:
	_s.weight_damage = 0.0
	_s.weight_pressure = 1.0
	_s.weight_survival = 0.0
	_s.weight_objective = 0.0
	assert_almost_eq(Fitness.new(_s).score(_record(50.0, 10.0, 40.0), 40.0), 0.25, 0.0001)


func test_more_pressure_scores_higher() -> void:
	var f: Fitness = Fitness.new(_s)
	assert_gt(f.score(_record(0.0, 20.0, 30.0), 30.0), f.score(_record(0.0, 5.0, 30.0), 30.0))


func test_describe() -> void:
	var text: String = Fitness.new(_s).describe(_record(25.0, 10.0, 20.0), 40.0)
	assert_string_contains(text, "D 0.50")
	assert_string_contains(text, "P 0.25")
	assert_string_contains(text, "F 0.338")


func test_data_file_matches_gdd() -> void:
	var s: FitnessSettings = load("res://data/fitness.tres")
	assert_almost_eq(s.weight_damage, 0.4, 0.0001)
	assert_almost_eq(s.weight_pressure, 0.25, 0.0001)
	assert_almost_eq(s.weight_survival, 0.15, 0.0001)
	assert_almost_eq(s.weight_objective, 0.2, 0.0001)
	assert_almost_eq(s.weight_damage + s.weight_pressure + s.weight_survival + s.weight_objective, 1.0, 0.0001)
	assert_eq(s.pressure_radius, 64.0, "4 tiles")

extends GutTest
## Tests for ProgressionSettings and PlayerProgression (XP, levels, skill points).

var _settings: ProgressionSettings
var _p: PlayerProgression


func before_each() -> void:
	_settings = ProgressionSettings.new()  # defaults: cap 30, 40 XP then +20 per level, 10 XP per kill
	_p = PlayerProgression.new(_settings)


func test_starts_at_level_one_with_nothing() -> void:
	assert_eq(_p.level, 1)
	assert_eq(_p.xp, 0)
	assert_eq(_p.skill_points, 0)
	assert_eq(_p.progress(), 0.0)


func test_curve_is_linear_and_zero_at_cap() -> void:
	assert_eq(_settings.xp_to_next(1), 40)
	assert_eq(_settings.xp_to_next(2), 60)
	assert_eq(_settings.xp_to_next(29), 40 + 20 * 28)
	assert_eq(_settings.xp_to_next(30), 0)


func test_xp_below_threshold_does_not_level() -> void:
	assert_eq(_p.add_xp(39), 0)
	assert_eq(_p.level, 1)
	assert_eq(_p.xp, 39)
	assert_almost_eq(_p.progress(), 39.0 / 40.0, 0.0001)


func test_exact_threshold_levels_and_grants_one_point() -> void:
	watch_signals(_p)
	assert_eq(_p.add_xp(40), 1)
	assert_eq(_p.level, 2)
	assert_eq(_p.xp, 0)
	assert_eq(_p.skill_points, 1)
	assert_signal_emitted_with_parameters(_p, "leveled_up", [2])


func test_remainder_carries_over() -> void:
	_p.add_xp(55)
	assert_eq(_p.level, 2)
	assert_eq(_p.xp, 15)


func test_big_gain_skips_several_levels() -> void:
	watch_signals(_p)
	assert_eq(_p.add_xp(40 + 60 + 80 + 5), 3)
	assert_eq(_p.level, 4)
	assert_eq(_p.xp, 5)
	assert_eq(_p.skill_points, 3)
	assert_signal_emit_count(_p, "leveled_up", 3)
	assert_eq(_p.total_xp, 185)


func test_one_skill_point_per_level_up_to_the_cap() -> void:
	_p.add_xp(1000000)
	assert_eq(_p.level, 30)
	assert_eq(_p.skill_points, 29)
	assert_true(_p.is_max_level())
	assert_eq(_p.xp, 0)
	assert_eq(_p.progress(), 1.0)


func test_no_xp_after_cap() -> void:
	_p.add_xp(1000000)
	var total: int = _p.total_xp
	assert_eq(_p.add_xp(50), 0)
	assert_eq(_p.total_xp, total)
	assert_eq(_p.level, 30)


func test_cap_is_data_driven() -> void:
	_settings.level_cap = 5
	_p.add_xp(1000000)
	assert_eq(_p.level, 5)
	assert_eq(_p.skill_points, 4)


func test_zero_or_negative_xp_ignored() -> void:
	assert_eq(_p.add_xp(0), 0)
	assert_eq(_p.add_xp(-10), 0)
	assert_eq(_p.xp, 0)
	assert_eq(_p.total_xp, 0)


func test_spend_skill_point() -> void:
	assert_false(_p.spend_skill_point())
	_p.add_xp(40)
	assert_true(_p.spend_skill_point())
	assert_eq(_p.skill_points, 0)


func test_enemy_xp_base_for_first_wave_enemy() -> void:
	assert_eq(_settings.enemy_xp(15.0), 10)


func test_enemy_xp_grows_slightly_with_stat_total() -> void:
	assert_eq(_settings.enemy_xp(20.0), 13)   # 10 x 1.25 = 12.5 -> 13
	assert_eq(_settings.enemy_xp(24.0), 15)   # budget cap: 10 x 1.45 = 14.5 -> 15
	assert_true(_settings.enemy_xp(24.0) > _settings.enemy_xp(15.0))


func test_enemy_xp_never_below_base() -> void:
	assert_eq(_settings.enemy_xp(3.0), 10)


func test_data_file_matches_defaults() -> void:
	var data: ProgressionSettings = load("res://data/progression.tres") as ProgressionSettings
	assert_not_null(data)
	assert_eq(data.level_cap, 30)
	assert_eq(data.skill_points_per_level, 1)

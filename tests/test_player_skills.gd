extends GutTest
## Tests for SkillNode, SkillTree and PlayerSkills (buying rules and stat effects).

var _tree: SkillTree
var _progression: PlayerProgression
var _skills: PlayerSkills


func before_each() -> void:
	_tree = load("res://data/skill_tree.tres") as SkillTree
	_progression = PlayerProgression.new(ProgressionSettings.new())
	_skills = PlayerSkills.new(_tree, _progression)


func _give_points(n: int) -> void:
	_progression.skill_points += n


func test_data_has_two_nodes_per_branch() -> void:
	assert_eq(_tree.nodes.size(), 6)
	for branch: int in 3:
		var nodes: Array[SkillNode] = _tree.branch_nodes(branch as SkillNode.Branch)
		assert_eq(nodes.size(), 2, "branch %d" % branch)
		assert_eq(nodes[0].tier, 0)
		assert_eq(nodes[1].requires, [nodes[0].id] as Array[StringName], "tier 2 needs tier 1")


func test_every_effect_targets_a_real_property() -> void:
	var player_stats: PlayerStats = PlayerStats.new()
	var weapon: WeaponStats = WeaponStats.new()
	for node: SkillNode in _tree.nodes:
		var res: Resource = player_stats if node.target == SkillNode.Target.PLAYER else weapon
		assert_true(res.get(node.property) is float, "%s -> %s" % [node.id, node.property])


func test_cannot_buy_without_points() -> void:
	assert_eq(_skills.check(&"rapid_fire"), PlayerSkills.Status.NOT_ENOUGH_POINTS)
	assert_false(_skills.unlock(&"rapid_fire"))
	assert_false(_skills.is_unlocked(&"rapid_fire"))


func test_buy_spends_points_and_unlocks() -> void:
	_give_points(1)
	watch_signals(_skills)
	assert_eq(_skills.check(&"rapid_fire"), PlayerSkills.Status.OK)
	assert_true(_skills.unlock(&"rapid_fire"))
	assert_true(_skills.is_unlocked(&"rapid_fire"))
	assert_eq(_progression.skill_points, 0)
	assert_signal_emitted(_skills, "changed")


func test_cannot_buy_twice() -> void:
	_give_points(3)
	_skills.unlock(&"rapid_fire")
	assert_eq(_skills.check(&"rapid_fire"), PlayerSkills.Status.OWNED)
	assert_false(_skills.unlock(&"rapid_fire"))
	assert_eq(_progression.skill_points, 2)


func test_prerequisite_checked_before_points() -> void:
	_give_points(5)
	assert_eq(_skills.check(&"hollow_points"), PlayerSkills.Status.MISSING_PREREQUISITE)
	assert_false(_skills.unlock(&"hollow_points"))
	assert_eq(_progression.skill_points, 5, "failed buy spends nothing")


func test_tier_two_needs_its_full_cost() -> void:
	_give_points(2)
	_skills.unlock(&"rapid_fire")  # 1 left, hollow points costs 2
	assert_eq(_skills.check(&"hollow_points"), PlayerSkills.Status.NOT_ENOUGH_POINTS)
	_give_points(1)
	assert_true(_skills.unlock(&"hollow_points"))
	assert_eq(_progression.skill_points, 0)


func test_unknown_id() -> void:
	_give_points(1)
	assert_eq(_skills.check(&"nope"), PlayerSkills.Status.UNKNOWN)
	assert_false(_skills.unlock(&"nope"))


func test_apply_never_touches_base() -> void:
	var base: WeaponStats = WeaponStats.new()
	_give_points(3)
	_skills.unlock(&"rapid_fire")
	_skills.unlock(&"hollow_points")
	var w: WeaponStats = _skills.apply(base, SkillNode.Target.WEAPON) as WeaponStats
	assert_almost_eq(w.fire_cooldown, 0.25 * 0.8, 0.0001)
	assert_almost_eq(w.damage, 10.0 * 1.25, 0.0001)
	assert_almost_eq(base.fire_cooldown, 0.25, 0.0001)
	assert_almost_eq(base.damage, 10.0, 0.0001)


func test_apply_only_hits_matching_target() -> void:
	_give_points(1)
	_skills.unlock(&"light_step")
	var w: WeaponStats = _skills.apply(WeaponStats.new(), SkillNode.Target.WEAPON) as WeaponStats
	var s: PlayerStats = _skills.apply(PlayerStats.new(), SkillNode.Target.PLAYER) as PlayerStats
	assert_almost_eq(w.damage, 10.0, 0.0001)
	assert_almost_eq(s.move_speed, 90.0 * 1.1, 0.0001)


func test_all_six_effects() -> void:
	_give_points(9)
	for id: StringName in [&"rapid_fire", &"hollow_points", &"thick_skin", &"safe_roll", &"light_step", &"quick_recovery"]:
		assert_true(_skills.unlock(id), String(id))
	var s: PlayerStats = _skills.apply(PlayerStats.new(), SkillNode.Target.PLAYER) as PlayerStats
	assert_almost_eq(s.max_health, 125.0, 0.0001)
	assert_almost_eq(s.dodge_invulnerable_time, 0.5, 0.0001)
	assert_almost_eq(s.move_speed, 99.0, 0.0001)
	assert_almost_eq(s.dodge_cooldown, 0.9, 0.0001)
	assert_eq(_progression.skill_points, 0)


func test_add_mode() -> void:
	var node: SkillNode = SkillNode.new()
	node.mode = SkillNode.Mode.ADD
	node.amount = 0.2
	assert_almost_eq(node.apply_to(0.3), 0.5, 0.0001)
	node.mode = SkillNode.Mode.MULTIPLY
	node.amount = 0.8
	assert_almost_eq(node.apply_to(0.25), 0.2, 0.0001)

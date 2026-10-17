extends GutTest
## Player progression redesign, phase 2: modifier layers, weapons and the shotgun, loadout,
## research, resources, blueprints, saves, Safehouse screens. Permanent research, weapon equipment
## and temporary effects are separate layers. The real user://campaign.json is backed up and restored.

const AREA: String = "res://world/zones/maple_hollow/areas/area_1.tscn"

var _backup: String = ""
var _had_save: bool = false


func before_all() -> void:
	_had_save = FileAccess.file_exists(SaveSystem.CAMPAIGN_PATH)
	if _had_save:
		_backup = FileAccess.get_file_as_string(SaveSystem.CAMPAIGN_PATH)


func after_all() -> void:
	if _had_save:
		var f: FileAccess = FileAccess.open(SaveSystem.CAMPAIGN_PATH, FileAccess.WRITE)
		f.store_string(_backup)
		f.close()
	else:
		SaveSystem.delete_save(SaveSystem.CAMPAIGN_PATH)


func after_each() -> void:
	GameState.test_mode = false
	GameState.start_new_campaign()
	GameState.campaign_active = false
	GameState.current_zone = 1
	GameState.scrap = 0
	GameState.samples = 0
	get_tree().paused = false


func _hp(v: float) -> StatModifier:
	return StatModifier.make(StatModifier.Target.PLAYER, &"max_health", StatModifier.Mode.ADD, v)


func _haste() -> Array[StatModifier]:
	return [StatModifier.make(StatModifier.Target.PLAYER, &"move_speed", StatModifier.Mode.MULTIPLY, 1.25)] as Array[StatModifier]


func _player_in(holder: Node) -> Player:
	var p: Player = load("res://entities/player/player.tscn").instantiate()
	holder.add_child(p)
	return p


func _shotgun_loadout() -> PlayerLoadout:
	var l: PlayerLoadout = PlayerLoadout.new()
	l.owned = [&"pistol", &"shotgun"]
	l.equipped = [&"shotgun", &""]
	return l


# --- Modifier layers -------------------------------------------------------------------------

func test_modifiers_work_on_copies_and_never_touch_the_base() -> void:
	var base: PlayerStats = load("res://data/player_stats.tres")
	var m: PlayerModifiers = PlayerModifiers.new()
	m.set_research([_hp(10.0)] as Array[StatModifier])
	var out: PlayerStats = m.apply(base, StatModifier.Target.PLAYER) as PlayerStats
	assert_eq(out.max_health, 110.0)
	assert_eq(base.max_health, 100.0, "the base resource is untouched")
	assert_ne(out, base)


func test_temporary_effects_are_a_separate_layer_that_ends_cleanly() -> void:
	var base: PlayerStats = load("res://data/player_stats.tres")
	var m: PlayerModifiers = PlayerModifiers.new()
	m.set_research([_hp(10.0)] as Array[StatModifier])
	m.add_temporary(&"haste", _haste(), 5.0)
	var fast: PlayerStats = m.apply(base, StatModifier.Target.PLAYER) as PlayerStats
	assert_almost_eq(fast.move_speed, 112.5, 0.001)
	assert_eq(fast.max_health, 110.0, "research still applies underneath")
	m.tick(5.1)
	var back: PlayerStats = m.apply(base, StatModifier.Target.PLAYER) as PlayerStats
	assert_eq(back.move_speed, 90.0, "back to exactly the permanent value")
	assert_eq(back.max_health, 110.0)
	assert_eq(m.research.size(), 1, "the research layer was never involved")
	assert_false(m.has_temporary(&"haste"))


func test_same_effect_refreshes_instead_of_stacking() -> void:
	var base: PlayerStats = load("res://data/player_stats.tres")
	var m: PlayerModifiers = PlayerModifiers.new()
	m.add_temporary(&"haste", _haste(), 5.0)
	m.tick(3.0)
	m.add_temporary(&"haste", _haste(), 5.0)
	assert_almost_eq(m.time_left(&"haste"), 5.0, 0.001, "time refreshed")
	assert_almost_eq((m.apply(base, StatModifier.Target.PLAYER) as PlayerStats).move_speed, 112.5, 0.001, "still x1.25, not x1.56")
	assert_eq(m.temporary_ids().size(), 1)


func test_player_applies_research_and_power_up_layers_without_changing_base_stats() -> void:
	var holder: Node2D = Node2D.new()
	add_child_autofree(holder)
	var p: Player = _player_in(holder)
	await wait_physics_frames(1)
	var base_hp: float = p._base_stats.max_health
	p.set_research([_hp(10.0)] as Array[StatModifier])
	assert_eq(p.stats.max_health, 110.0)
	assert_eq(p.health, 110.0, "extra max HP is added to current HP")
	p.modifiers.add_temporary(&"haste", _haste(), 0.2)
	assert_almost_eq(p.walk_speed(), 112.5, 0.01)
	await wait_physics_frames(20)
	assert_eq(p.walk_speed(), 90.0, "the boost ran out")
	assert_eq(p._base_stats.max_health, base_hp, "base stats never changed")
	assert_eq((load("res://data/player_stats.tres") as PlayerStats).max_health, 100.0)


## Every exported number of the player's stats and weapon (what kills used to raise through XP and skills).
func _stat_values(p: Player) -> Dictionary:
	var out: Dictionary = {}
	for res: Resource in [p.stats, p.weapon]:
		for prop: Dictionary in res.get_property_list():
			if prop["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE and prop["type"] in [TYPE_FLOAT, TYPE_INT, TYPE_BOOL]:
				out["%s.%s" % [res.get_script().get_global_name(), prop["name"]]] = res.get(prop["name"])
	return out


func test_kills_never_raise_permanent_player_stats() -> void:
	var c: LevelConfig = LevelConfig.new()
	c.id = "test_no_xp"
	c.areas = [load(AREA)]
	c.waves = 1
	c.spawn_delay_seconds = 0.1
	c.objective = ObjectiveConfig.new()
	var main: Node = load("res://world/main.tscn").instantiate()
	main.autosave = false
	main.level_config = c
	var wm: WaveManager = main.get_node("WaveManager")
	wm.log_waves = false
	wm.spawn_seed = 21
	add_child_autofree(main)
	await wait_physics_frames(12)
	var p: Player = main.get_node("Player")
	var before: Dictionary = _stat_values(p)
	var research_before: Array = GameState.research().to_array()
	assert_gt(before.size(), 10, "the snapshot covers the stats and the weapon")
	assert_false("progression" in p, "no XP / level object on the player")
	assert_false("skills" in p, "no skill tree on the player")
	var victims: Array = wm.alive.slice(0, 5)
	assert_eq(victims.size(), 5)
	for e: Enemy in victims:
		e.take_damage(10000.0)
	await wait_physics_frames(3)
	assert_eq(wm.alive.size(), 15, "five Bloomed died (enemy_killed was emitted)")
	assert_eq(_stat_values(p), before, "kills change no permanent stat")
	assert_eq(p.stats.max_health, 100.0)
	assert_eq(GameState.research().to_array(), research_before, "kills unlock no research")


# --- Shotgun and weapons ---------------------------------------------------------------------

func test_shotgun_data_and_the_trade_offs() -> void:
	var gun: WeaponStats = WeaponLibrary.get_weapon(&"shotgun")
	var pistol: WeaponStats = WeaponLibrary.get_weapon(&"pistol")
	assert_eq(gun.pellets, 8)
	assert_eq(gun.damage, 6.0)
	assert_eq(pistol.pellets, 1, "the pistol is unchanged")
	assert_eq(pistol.damage, 10.0)
	assert_eq(pistol.fire_cooldown, 0.25)
	assert_gt(gun.fire_cooldown, pistol.fire_cooldown * 3.0, "slow to fire")
	assert_gt(gun.noise_radius, pistol.noise_radius, "louder")
	assert_gt(gun.draw_time, 0.0, "slow to draw")
	var gun_range: float = gun.projectile_speed * gun.projectile_lifetime
	var pistol_range: float = pistol.projectile_speed * pistol.projectile_lifetime
	assert_lt(gun_range, pistol_range * 0.4, "short range: %.0f px vs %.0f px" % [gun_range, pistol_range])
	var point_blank: float = gun.pellets * gun.damage / gun.fire_cooldown
	var pistol_dps: float = pistol.damage / pistol.fire_cooldown
	assert_gt(point_blank, pistol_dps, "stronger at point blank (%.0f vs %.0f per second)" % [point_blank, pistol_dps])
	assert_lt(point_blank, pistol_dps * 1.6, "but not absurdly so")
	assert_eq(gun.unlock_cost_scrap, 80)


func test_pellets_stay_inside_the_spread_cone_and_are_seeded() -> void:
	var holder: Node2D = Node2D.new()
	add_child_autofree(holder)
	var p: Player = _player_in(holder)
	await wait_physics_frames(1)
	p.apply_loadout(_shotgun_loadout())
	assert_eq(p.weapon.pellets, 8)
	p.aim_direction = Vector2.RIGHT
	for i: int in 8:
		assert_lte(rad_to_deg(absf(p._pellet_direction(i).angle())), 8.0 + 0.01, "inside the 16 degree cone")
	p.spread_rng.seed = 5
	var a1: Array[float] = []
	for i: int in 8:
		a1.append(p._pellet_direction(i).angle())
	p.spread_rng.seed = 5
	var a2: Array[float] = []
	for i: int in 8:
		a2.append(p._pellet_direction(i).angle())
	assert_eq(a1, a2, "same seed, same spread")


func _count_bullets(node: Node) -> int:
	var n: int = 0
	for c: Node in node.get_children():
		if c.scene_file_path.ends_with("bullet.tscn"):
			n += 1
	return n


func test_one_trigger_pull_fires_all_pellets_but_makes_one_noise() -> void:
	var holder: Node2D = Node2D.new()
	add_child_autofree(holder)
	var p: Player = _player_in(holder)
	await wait_physics_frames(1)
	p.apply_loadout(_shotgun_loadout())
	p._cooldown_left = 0.0
	p.weapon.automatic = true  # the weapon is a per-player copy: lets this test hold the trigger
	var noises: Array[float] = []
	var listener: Callable = func(_pos: Vector2, radius: float) -> void: noises.append(radius)
	EventBus.noise_emitted.connect(listener)
	Input.action_press("shoot")
	p._shoot(0.0)
	Input.action_release("shoot")
	EventBus.noise_emitted.disconnect(listener)
	assert_eq(_count_bullets(holder), 8, "eight pellets")
	assert_eq(noises.size(), 1, "one shot, one noise")
	assert_eq(noises[0], 256.0)


func _shoot_at(distance: float) -> float:
	var holder: Node2D = Node2D.new()
	add_child(holder)
	var p: Player = _player_in(holder)
	var target: StaticBody2D = StaticBody2D.new()
	target.set_script(load("res://tests/support/damage_dummy.gd"))
	target.collision_layer = 4
	var shape: CollisionShape2D = CollisionShape2D.new()
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = 6.0
	shape.shape = circle
	target.add_child(shape)
	holder.add_child(target)
	target.global_position = Vector2(distance, 0)
	await wait_physics_frames(2)
	p.apply_loadout(_shotgun_loadout())
	p.global_position = Vector2.ZERO
	p.aim_direction = Vector2.RIGHT
	p._cooldown_left = 0.0
	p.weapon.automatic = true
	Input.action_press("shoot")
	p._shoot(0.0)
	Input.action_release("shoot")
	await wait_physics_frames(40)
	var taken: float = target.taken
	holder.queue_free()
	await wait_physics_frames(2)
	return taken


func test_shotgun_hurts_at_close_range_and_not_far_away() -> void:
	var near: float = await _shoot_at(40.0)
	assert_gte(near, 24.0, "at least four pellets land at 40 px: %.0f damage" % near)
	var far: float = await _shoot_at(130.0)
	assert_eq(far, 0.0, "nothing arrives from 130 px")


func test_swapping_weapons_needs_the_draw_time() -> void:
	var holder: Node2D = Node2D.new()
	add_child_autofree(holder)
	var p: Player = _player_in(holder)
	await wait_physics_frames(1)
	var loadout: PlayerLoadout = PlayerLoadout.new()
	loadout.owned = [&"pistol", &"shotgun"]
	loadout.equipped = [&"pistol", &"shotgun"]
	p.apply_loadout(loadout)
	assert_eq(p.active_weapon_id(), &"pistol")
	p._cooldown_left = 0.0
	p.swap_weapon()
	assert_eq(p.active_weapon_id(), &"shotgun")
	assert_eq(p.weapon.pellets, 8)
	assert_almost_eq(p._cooldown_left, 0.4, 0.001, "cannot fire straight away")
	p.swap_weapon()
	assert_eq(p.active_weapon_id(), &"pistol")
	p.apply_loadout(PlayerLoadout.new())
	p.swap_weapon()
	assert_eq(p.active_weapon_id(), &"pistol", "nothing to swap to")


# --- Loadout ---------------------------------------------------------------------------------

func test_loadout_blueprint_build_and_equip_rules() -> void:
	var l: PlayerLoadout = PlayerLoadout.new()
	assert_true(l.is_owned(&"pistol"))
	assert_eq(l.build_problem(&"shotgun", 999), "no blueprint")
	assert_true(l.add_blueprint(&"shotgun"))
	assert_false(l.add_blueprint(&"shotgun"), "a known blueprint is not added twice")
	assert_false(l.add_blueprint(&"laser"), "unknown weapon")
	assert_eq(l.build_problem(&"shotgun", 79), "needs 80 scrap")
	assert_false(l.build(&"shotgun", 79))
	assert_true(l.build(&"shotgun", 80))
	assert_true(l.is_owned(&"shotgun"))
	assert_eq(l.build_problem(&"shotgun", 999), "already built")
	assert_false(l.add_blueprint(&"shotgun"), "already built")
	assert_true(l.equip(&"shotgun", 1))
	assert_eq(l.equipped, [&"pistol", &"shotgun"] as Array[StringName])
	assert_true(l.equip(&"shotgun", 0), "equipping the spare in hand swaps the two")
	assert_eq(l.equipped, [&"shotgun", &"pistol"] as Array[StringName])
	assert_false(l.equip(&"crossbow", 0), "cannot carry what you do not own")


func test_loadout_round_trip_and_sanitising() -> void:
	var l: PlayerLoadout = PlayerLoadout.new()
	l.add_blueprint(&"shotgun")
	l.build(&"shotgun", 80)
	l.equip(&"shotgun", 1)
	var back: PlayerLoadout = PlayerLoadout.from_dict(JSON.parse_string(JSON.stringify(l.to_dict())))
	assert_eq(back.to_dict(), l.to_dict())
	var junk: PlayerLoadout = PlayerLoadout.from_dict({"owned": ["pistol", "laser", 5, "shotgun", "shotgun"],
			"blueprints": ["shotgun", "x"], "equipped": ["laser", "shotgun"]})
	assert_eq(junk.owned, [&"pistol", &"shotgun"] as Array[StringName])
	assert_eq(junk.blueprints.size(), 0, "built weapons are not blueprints")
	assert_eq(junk.equipped[0], &"pistol", "slot 0 falls back to the pistol")
	assert_eq(junk.equipped[1], &"shotgun")
	assert_eq(PlayerLoadout.from_dict("garbage").owned, [&"pistol"] as Array[StringName])


# --- Research --------------------------------------------------------------------------------

func _tree() -> ResearchTree:
	return load("res://data/research_tree.tres")


func test_research_data_costs_gates_and_cap() -> void:
	var tree: ResearchTree = _tree()
	assert_eq(tree.nodes.size(), 3)
	assert_eq(tree.group_caps[&"health"], 30.0)
	var total: float = 0.0
	for n: ResearchNode in tree.nodes:
		total += n.group_amount()
		assert_gt(n.cost_samples, 0)
		assert_gt(n.cost_scrap, 0)
	assert_eq(total, 30.0, "the three vaccines add exactly the +30 HP cap")
	assert_eq(tree.get_node_by_id(&"vaccine_1").min_zone, 1, "the Lab works from zone 1")
	assert_eq(tree.get_node_by_id(&"vaccine_3").requires, [&"vaccine_2"] as Array[StringName])


func test_research_status_reasons() -> void:
	var r: ResearchState = ResearchState.new(_tree())
	assert_eq(r.status(&"nope", 999, 999, 4), ResearchState.Status.UNKNOWN)
	assert_eq(r.status(&"vaccine_1", 0, 0, 1), ResearchState.Status.NOT_ENOUGH_SCRAP)
	assert_eq(r.status(&"vaccine_1", 999, 0, 1), ResearchState.Status.NOT_ENOUGH_SAMPLES)
	assert_eq(r.status(&"vaccine_1", 999, 999, 1), ResearchState.Status.OK)
	assert_eq(r.status(&"vaccine_2", 999, 999, 4), ResearchState.Status.MISSING_PREREQUISITE)
	assert_true(r.unlock(&"vaccine_1", 999, 999, 1))
	assert_eq(r.status(&"vaccine_1", 999, 999, 1), ResearchState.Status.OWNED)
	assert_eq(r.status(&"vaccine_2", 999, 999, 1), ResearchState.Status.ZONE_TOO_EARLY, "progressive unlock by zone")
	assert_eq(r.status(&"vaccine_2", 999, 999, 2), ResearchState.Status.OK)


func test_research_cap_is_hard() -> void:
	var tree: ResearchTree = _tree().duplicate() as ResearchTree
	var r: ResearchState = ResearchState.new(tree)
	for id: StringName in [&"vaccine_1", &"vaccine_2", &"vaccine_3"]:
		assert_true(r.unlock(id, 999, 999, 4))
	assert_eq(r.group_total(&"health"), 30.0)
	var extra: ResearchNode = ResearchNode.new()
	extra.id = &"vaccine_4"
	extra.cap_group = &"health"
	extra.modifiers = [_hp(10.0)] as Array[StatModifier]
	tree.nodes.append(extra)
	assert_eq(r.status(&"vaccine_4", 999, 999, 4), ResearchState.Status.CAP_REACHED)
	var total_hp: float = 0.0
	for m: StatModifier in r.modifiers():
		total_hp += m.amount
	assert_eq(100.0 + total_hp, 130.0, "never above 130 HP")


func test_research_restore_drops_bad_entries() -> void:
	var r: ResearchState = ResearchState.new(_tree())
	var dropped: PackedStringArray = r.restore(["vaccine_2", "vaccine_1", "vaccine_1", "ghost", 7, "vaccine_2", "vaccine_3"])
	assert_eq(r.unlocked, [&"vaccine_1", &"vaccine_2", &"vaccine_3"] as Array[StringName])
	assert_gt(dropped.size(), 0)
	assert_eq(r.restore("junk").size(), 0)
	assert_eq(r.unlocked.size(), 0)


func test_buying_research_spends_samples_and_scrap_and_raises_max_hp() -> void:
	GameState.start_new_campaign()
	GameState.current_zone = 1
	GameState.scrap = 100
	GameState.samples = 12
	assert_true(GameState.buy_research(&"vaccine_1"))
	assert_eq(GameState.scrap, 40)
	assert_eq(GameState.samples, 2)
	assert_false(GameState.buy_research(&"vaccine_1"), "already done")
	assert_false(GameState.buy_research(&"vaccine_2"), "needs zone 2 and more resources")
	var holder: Node2D = Node2D.new()
	add_child_autofree(holder)
	var p: Player = _player_in(holder)
	await wait_physics_frames(1)
	GameState.apply_to_player(p)
	assert_eq(p.stats.max_health, 110.0)
	assert_eq(p._base_stats.max_health, 100.0)


# --- Resources, blueprints, saves ------------------------------------------------------------

func test_a_lost_attempt_gives_back_resources_and_blueprints() -> void:
	GameState.start_new_campaign()
	GameState.scrap = 50
	GameState.samples = 5
	GameState.take_resource_snapshot()
	GameState.scrap += 70
	GameState.samples += 9
	GameState.collect_blueprint(&"shotgun")
	GameState.restore_resource_snapshot()
	assert_eq(GameState.scrap, 50)
	assert_eq(GameState.samples, 5)
	assert_eq(GameState.loadout.blueprints.size(), 0)


func test_zone_one_apex_hands_over_the_shotgun_blueprint() -> void:
	GameState.start_new_campaign()
	GameState.level_index = 3
	var evo: Dictionary = {"next_wave": 6, "generation": 5, "population": [], "history": []}
	assert_eq(GameState.finish_level(evo), "safehouse")
	assert_true(GameState.loadout.blueprints.has(&"shotgun"))


func test_campaign_save_round_trips_loadout_and_research() -> void:
	GameState.start_new_campaign()
	GameState.scrap = 500
	GameState.samples = 500
	GameState.collect_blueprint(&"shotgun")
	GameState.build_weapon(&"shotgun")
	GameState.loadout.equip(&"shotgun", 1)
	GameState.buy_research(&"vaccine_1")
	assert_eq(GameState.save_campaign(), OK)
	GameState.start_new_campaign()
	assert_false(GameState.loadout.is_owned(&"shotgun"), "a new run starts with the pistol only")
	assert_true(GameState.load_campaign())
	assert_true(GameState.loadout.is_owned(&"shotgun"))
	assert_eq(GameState.loadout.equipped, [&"pistol", &"shotgun"] as Array[StringName])
	assert_true(GameState.research().is_unlocked(&"vaccine_1"))
	assert_eq(GameState.scrap, 500 - 80 - 60)


func test_new_game_plus_keeps_weapons_and_research_but_a_new_game_does_not() -> void:
	GameState.start_new_campaign()
	GameState.collect_blueprint(&"shotgun")
	GameState.scrap = 999
	GameState.build_weapon(&"shotgun")
	GameState.samples = 99
	GameState.buy_research(&"vaccine_1")
	GameState.start_new_campaign(true)
	assert_true(GameState.loadout.is_owned(&"shotgun"))
	assert_true(GameState.research().is_unlocked(&"vaccine_1"))
	GameState.start_new_campaign(false)
	assert_false(GameState.loadout.is_owned(&"shotgun"))
	assert_false(GameState.research().is_unlocked(&"vaccine_1"))


func test_old_format_1_campaign_save_still_loads() -> void:
	var old: Dictionary = {"format": 1, "active": true, "zone": 2, "level_index": 1, "zone_evolution": {},
		"zone_best": {}, "zone_elite": {}, "player": {"level": 9, "xp": 5, "total_xp": 900, "skill_points": 3, "unlocked": []},
		"samples": 14, "scrap": 77, "side_done": ["a"], "won": false}
	assert_true(GameState.from_dict(old))
	assert_eq(GameState.current_zone, 2)
	assert_eq(GameState.scrap, 77, "resources are kept")
	assert_eq(GameState.samples, 14)
	assert_eq(GameState.loadout.owned, [&"pistol"] as Array[StringName], "the starting pistol")
	assert_eq(GameState.research().unlocked.size(), 0)
	assert_true(GameState.legacy_notice.contains("no longer exist"), "the menu can tell the player once")
	assert_eq(GameState.save_campaign(), OK)
	assert_eq(GameState.legacy_notice, "", "the next save drops the notice")
	assert_false(GameState.to_dict().has("player"), "XP and skills are not written any more")
	assert_false(GameState.from_dict({"format": 3}), "a newer format is not guessed at")


func test_a_format_1_save_without_progress_gives_no_notice() -> void:
	var old: Dictionary = {"format": 1, "active": true, "zone": 1, "level_index": 0, "player": {"level": 1, "unlocked": []}}
	assert_true(GameState.from_dict(old))
	assert_eq(GameState.legacy_notice, "")
	assert_true(GameState.from_dict({"format": 1, "player": 5}))
	assert_eq(GameState.legacy_notice, "")


func test_damaged_loadout_and_research_in_a_save_are_cleaned() -> void:
	var d: Dictionary = GameState.to_dict()
	d["loadout"] = {"owned": ["pistol", "laser"], "blueprints": [3], "equipped": 12}
	d["research"] = ["vaccine_3", "ghost", "vaccine_1"]
	assert_true(GameState.from_dict(d))
	assert_eq(GameState.loadout.owned, [&"pistol"] as Array[StringName])
	assert_eq(GameState.research().unlocked, [&"vaccine_1"] as Array[StringName], "vaccine_3 without vaccine_2 is dropped")


# --- Blueprints in levels, reachable cells ---------------------------------------------------

func test_reachable_cells_are_all_reachable_safe_and_deterministic() -> void:
	var main: Node = load("res://world/main.tscn").instantiate()
	main.autosave = false
	add_child_autofree(main)
	await wait_physics_frames(2)
	var grid: TerrainGrid = main.terrain_grid
	var start: Vector2i = grid.coords.world_to_cell(main.current_map().get_entry())
	var cells: Array[Vector2i] = ReachableCells.from(grid, start)
	assert_gt(cells.size(), 200)
	assert_eq(cells, ReachableCells.from(grid, start), "same input, same list")
	assert_eq(cells[0], start, "nearest first")
	for c: Vector2i in cells:
		var def: TerrainDefinition = grid.get_definition(c)
		assert_true(def.player_passable, "%s walkable" % c)
		assert_eq(def.hazard, TerrainDefinition.Hazard.NONE)
		assert_eq(grid.get_overlay(c), "")
	var far: Array[Vector2i] = ReachableCells.farther_than(cells, start, 20.0)
	assert_gt(far.size(), 0)
	for c: Vector2i in far:
		assert_gte(Vector2(c - start).length(), 20.0)


func _blueprint_level(known: bool) -> Node:
	GameState.start_new_campaign()
	if known:
		GameState.collect_blueprint(&"shotgun")
	var c: LevelConfig = LevelConfig.new()
	c.id = "test_blueprint"
	c.areas = [load(AREA)]
	c.waves = 1
	c.spawn_delay_seconds = 0.1
	c.blueprint_weapon = &"shotgun"
	c.objective = ObjectiveConfig.new()
	var main: Node = load("res://world/main.tscn").instantiate()
	main.autosave = false
	main.level_config = c
	var wm: WaveManager = main.get_node("WaveManager")
	wm.log_waves = false
	wm.spawn_seed = 4
	add_child_autofree(main)
	await wait_physics_frames(6)
	return main


func test_level_hides_the_blueprint_on_a_far_reachable_cell_until_found() -> void:
	var main: Node = await _blueprint_level(false)
	var found: Pickup = null
	for c: Node in main.get_children():
		if c is Pickup and (c as Pickup).kind == &"blueprint":
			found = c
	assert_not_null(found, "a blueprint pickup lies in the last area")
	assert_eq(found.tag, &"shotgun")
	var grid: TerrainGrid = main.terrain_grid
	var origin: Vector2i = grid.coords.world_to_cell(main.current_map().get_entry())
	var cell: Vector2i = grid.coords.world_to_cell(found.global_position)
	assert_true(ReachableCells.from(grid, origin).has(cell), "the player can walk there")
	assert_gte(Vector2(cell - origin).length(), 20.0, "far from the entry: worth exploring")
	found._on_body_entered(main.get_node("Player"))
	assert_true(GameState.loadout.blueprints.has(&"shotgun"), "collecting it records the blueprint")


func test_no_blueprint_pickup_when_the_weapon_is_already_known() -> void:
	var main: Node = await _blueprint_level(true)
	for c: Node in main.get_children():
		assert_false(c is Pickup and (c as Pickup).kind == &"blueprint")


# --- Safehouse screens -----------------------------------------------------------------------

func test_safehouse_lab_and_workbench_work_and_fit_the_viewport() -> void:
	GameState.start_new_campaign()
	GameState.safehouse_mode = "zone"
	GameState.scrap = 300
	GameState.samples = 40
	GameState.collect_blueprint(&"shotgun")
	var screen: Control = load("res://ui/menus/safehouse.tscn").instantiate()
	add_child_autofree(screen)
	await wait_physics_frames(2)
	screen._open_panel("workbench")
	await wait_physics_frames(2)
	var texts: Array[String] = []
	for b: Node in screen.find_children("*", "Button", true, false):
		texts.append((b as Button).text)
	assert_true(texts.has("Build (80 scrap)"))
	screen._build(&"shotgun")
	await wait_physics_frames(2)
	assert_true(GameState.loadout.is_owned(&"shotgun"))
	assert_eq(GameState.scrap, 220)
	screen._open_panel("lab")
	await wait_physics_frames(2)
	for l: Node in screen.find_children("*", "Label", true, false):
		assert_lte((l as Label).get_combined_minimum_size().x, 480.0, (l as Label).text)
	screen._research_node(&"vaccine_1")
	assert_true(GameState.research().is_unlocked(&"vaccine_1"))
	assert_eq(GameState.scrap, 160)
	assert_eq(GameState.samples, 30)
	await wait_physics_frames(2)
	for b: Node in screen.find_children("*", "Button", true, false):
		if (b as Button).is_visible_in_tree():
			assert_lte((b as Button).get_global_rect().end.y, 271.0, "button inside the viewport: " + (b as Button).text)

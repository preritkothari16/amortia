extends GutTest
## Temporary power-ups (separate from permanent progression): data, weighted seeded spawning on
## reachable cells, limits, effects, and that nothing temporary ever reaches saved or base stats.

const AREA: String = "res://world/zones/maple_hollow/areas/area_1.tscn"

var _set: PowerUpSet


func before_each() -> void:
	_set = load("res://data/power_up_set.tres")


func after_each() -> void:
	get_tree().paused = false


func _level(powerups: bool = true, first_delay: float = -1.0) -> Dictionary:
	var c: LevelConfig = LevelConfig.new()
	c.id = "test_powerups"
	c.areas = [load(AREA)]
	c.waves = 1
	c.spawn_delay_seconds = 0.1
	c.powerups_enabled = powerups
	c.objective = ObjectiveConfig.new()
	var main: Node = load("res://world/main.tscn").instantiate()
	main.autosave = false
	main.level_config = c
	var wm: WaveManager = main.get_node("WaveManager")
	wm.log_waves = false
	wm.spawn_seed = 21
	add_child_autofree(main)
	await wait_physics_frames(12)
	var player: Player = main.get_node("Player")
	player.health = 50.0
	var pm: PowerUpManager = main.power_up_manager
	if pm != null and first_delay >= 0.0:
		pm.settings = pm.settings.duplicate() as PowerUpSet
		pm.settings.first_delay = first_delay
		pm._timer = first_delay
	for e: Enemy in wm.alive:
		e.set_physics_process(false)  # the wave stays still; only the power-ups are under test
	return {"main": main, "wm": wm, "player": player, "pm": pm}


func _pickups(main: Node) -> Array[PowerUpPickup]:
	var list: Array[PowerUpPickup] = []
	for c: Node in main.get_children():
		if c is PowerUpPickup and not c.is_queued_for_deletion():
			list.append(c)
	return list


# --- Data ------------------------------------------------------------------------------------

func test_the_set_has_all_five_effects_and_every_one_is_a_brief_benefit() -> void:
	var ids: Array[StringName] = []
	for t: PowerUpType in _set.types:
		ids.append(t.id)
		assert_true(t.is_beneficial(), "%s helps the player" % t.id)
		assert_gt(t.weight, 0.0)
		assert_lte(t.duration, _set.max_duration, "%s is brief" % t.id)
		if t.kind != PowerUpType.Kind.HEAL:
			assert_gt(t.duration, 0.0)
	assert_eq(ids, [&"heal", &"shield", &"haste", &"rapid", &"damage"] as Array[StringName])
	assert_lte(_set.max_duration, 12.0)
	assert_eq(_set.max_concurrent, 3)


func test_beneficial_check_catches_a_harmful_power_up() -> void:
	var bad: PowerUpType = PowerUpType.new()
	bad.modifiers = [StatModifier.make(StatModifier.Target.WEAPON, &"fire_cooldown", StatModifier.Mode.MULTIPLY, 1.5)] as Array[StatModifier]
	assert_false(bad.is_beneficial(), "a slower weapon is not a benefit")
	bad.modifiers = [StatModifier.make(StatModifier.Target.PLAYER, &"move_speed", StatModifier.Mode.MULTIPLY, 0.8)] as Array[StatModifier]
	assert_false(bad.is_beneficial())
	bad.modifiers = []
	bad.heal_amount = -5.0
	assert_false(bad.is_beneficial())


func test_weighted_pick_follows_the_weights() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 3
	var counts: Dictionary = {}
	var n: int = 12000
	for i: int in n:
		var t: PowerUpType = _set.pick(rng.randf() * _set.total_weight())
		counts[t.id] = int(counts.get(t.id, 0)) + 1
	for t: PowerUpType in _set.types:
		var expected: float = t.weight / _set.total_weight()
		assert_almost_eq(float(counts.get(t.id, 0)) / n, expected, 0.02, "%s share" % t.id)
	assert_gt(counts[&"heal"], counts[&"shield"], "the medkit is the most common")


func test_campaign_levels_have_power_ups_and_plain_levels_do_not() -> void:
	for zone: ZoneConfig in GameState.campaign().zones:
		for level: LevelConfig in zone.levels:
			assert_true(level.powerups_enabled, level.id)
	assert_false(LevelConfig.new().powerups_enabled, "off unless a level asks for it")


# --- Effects and limits ----------------------------------------------------------------------

func _player() -> Player:
	var holder: Node2D = Node2D.new()
	add_child_autofree(holder)
	var p: Player = load("res://entities/player/player.tscn").instantiate()
	holder.add_child(p)
	return p


func _manager_for(p: Player) -> PowerUpManager:
	var pm: PowerUpManager = PowerUpManager.new()
	add_child_autofree(pm)
	pm.settings = _set
	pm.player = p
	return pm


func test_heal_restores_hp_but_never_above_max() -> void:
	var p: Player = _player()
	await wait_physics_frames(1)
	var pm: PowerUpManager = _manager_for(p)
	p.health = 60.0
	pm.apply(_set.get_type(&"heal"), p)
	assert_eq(p.health, 85.0)
	pm.apply(_set.get_type(&"heal"), p)
	pm.apply(_set.get_type(&"heal"), p)
	assert_eq(p.health, 100.0, "capped at max health")
	assert_eq(p.heal(25.0), 0.0, "nothing to restore")


func test_shield_soaks_damage_first_then_fades() -> void:
	var p: Player = _player()
	await wait_physics_frames(1)
	var pm: PowerUpManager = _manager_for(p)
	pm.apply(_set.get_type(&"shield"), p)
	assert_eq(p.shield, 25.0)
	assert_eq(p.take_damage(10.0), 0.0, "fully absorbed: no damage dealt")
	assert_eq(p.health, 100.0)
	assert_eq(p.shield, 15.0)
	assert_eq(p.take_damage(20.0), 5.0, "the rest gets through")
	assert_eq(p.health, 95.0)
	assert_eq(p.shield, 0.0)
	pm.apply(_set.get_type(&"shield"), p)
	pm.apply(_set.get_type(&"shield"), p)
	assert_eq(p.shield, 25.0, "a second shield refreshes, it does not add up")
	p.shield_left = 0.05
	await wait_physics_frames(5)
	assert_eq(p.shield, 0.0, "it fades after its time")


func test_boosts_change_stats_for_a_while_and_then_stop() -> void:
	var p: Player = _player()
	await wait_physics_frames(1)
	var pm: PowerUpManager = _manager_for(p)
	pm.apply(_set.get_type(&"haste"), p)
	pm.apply(_set.get_type(&"rapid"), p)
	pm.apply(_set.get_type(&"damage"), p)
	assert_almost_eq(p.walk_speed(), 112.5, 0.01)
	assert_almost_eq(p.weapon.fire_cooldown, 0.1875, 0.0001)
	assert_almost_eq(p.weapon.damage, 13.0, 0.0001)
	p.modifiers.tick(11.0)
	assert_eq(p.walk_speed(), 90.0)
	assert_eq(p.weapon.fire_cooldown, 0.25)
	assert_eq(p.weapon.damage, 10.0)


func test_durations_are_capped_by_the_set() -> void:
	var p: Player = _player()
	await wait_physics_frames(1)
	var pm: PowerUpManager = _manager_for(p)
	var long: PowerUpType = _set.get_type(&"haste").duplicate() as PowerUpType
	long.duration = 500.0
	pm.apply(long, p)
	assert_lte(p.modifiers.time_left(&"haste"), _set.max_duration)


func test_the_same_boost_refreshes_and_never_stacks() -> void:
	var p: Player = _player()
	await wait_physics_frames(1)
	var pm: PowerUpManager = _manager_for(p)
	for i: int in 5:
		assert_true(pm.collect(_set.get_type(&"haste"), p), "refresh is always allowed")
	assert_almost_eq(p.walk_speed(), 112.5, 0.01, "x1.25 once, not x3")
	assert_eq(p.modifiers.temporary_ids().size(), 1)


func test_at_most_three_timed_effects_and_the_rest_wait() -> void:
	var p: Player = _player()
	await wait_physics_frames(1)
	var pm: PowerUpManager = _manager_for(p)
	assert_true(pm.collect(_set.get_type(&"haste"), p))
	assert_true(pm.collect(_set.get_type(&"rapid"), p))
	assert_true(pm.collect(_set.get_type(&"damage"), p))
	assert_false(pm.collect(_set.get_type(&"shield"), p), "a fourth timed effect is refused (the pickup stays on the map)")
	assert_eq(p.shield, 0.0)
	assert_true(pm.collect(_set.get_type(&"heal"), p), "an instant heal is always fine")
	assert_true(pm.collect(_set.get_type(&"haste"), p), "refreshing one of the three is fine")
	p.modifiers.tick(11.0)
	assert_true(pm.collect(_set.get_type(&"shield"), p), "room again after they ran out")


func test_temporary_effects_never_reach_base_or_saved_stats() -> void:
	GameState.start_new_campaign()
	var p: Player = _player()
	await wait_physics_frames(1)
	var pm: PowerUpManager = _manager_for(p)
	var before: String = JSON.stringify(GameState.to_dict())
	var base_hp: float = p._base_stats.max_health
	var base_damage: float = p._base_weapon.damage
	for id: StringName in [&"haste", &"rapid", &"damage", &"shield", &"heal"]:
		pm.apply(_set.get_type(id), p)
	assert_eq(p._base_stats.max_health, base_hp)
	assert_eq(p._base_weapon.damage, base_damage)
	assert_eq((load("res://data/player_stats.tres") as PlayerStats).move_speed, 90.0)
	assert_eq((load("res://data/pistol.tres") as WeaponStats).damage, 10.0)
	assert_eq(p.modifiers.research.size(), 0, "the permanent layer was not touched")
	assert_eq(JSON.stringify(GameState.to_dict()), before, "nothing about power-ups is in the save")
	p.revive()
	assert_eq(p.modifiers.temporary_ids().size(), 0, "a lost attempt ends them")
	assert_eq(p.shield, 0.0)
	assert_eq(p.walk_speed(), 90.0)


# --- Spawning in a level ---------------------------------------------------------------------

func test_a_level_without_the_flag_has_no_manager() -> void:
	var lvl: Dictionary = await _level(false)
	assert_null(lvl["pm"])


func test_power_ups_spawn_on_reachable_cells_at_the_right_distance() -> void:
	var lvl: Dictionary = await _level(true, 0.05)
	var main: Node = lvl["main"]
	var pm: PowerUpManager = lvl["pm"]
	var player: Player = lvl["player"]
	await wait_physics_frames(20)
	var found: Array[PowerUpPickup] = _pickups(main)
	assert_gt(found.size(), 0, "the first power-up appeared after the delay")
	var grid: TerrainGrid = main.terrain_grid
	var here: Vector2i = grid.coords.world_to_cell(player.global_position)
	var reachable: Array[Vector2i] = ReachableCells.from(grid, here)
	for _i: int in 6:
		pm.spawn_one()
	for p: PowerUpPickup in _pickups(main):
		var cell: Vector2i = grid.coords.world_to_cell(p.global_position)
		assert_true(reachable.has(cell), "%s is reachable" % cell)
		var d: float = Vector2(cell - here).length()
		assert_between(d, pm.settings.min_player_distance_cells, pm.settings.max_player_distance_cells)


func test_limits_per_wave_and_on_the_map() -> void:
	var lvl: Dictionary = await _level(true, 0.05)
	var main: Node = lvl["main"]
	var pm: PowerUpManager = lvl["pm"]
	pm.settings.interval = 0.05
	await wait_physics_frames(120)
	assert_lte(_pickups(main).size(), pm.settings.max_on_map, "at most two lying around")
	assert_lte(pm.spawned_this_wave, pm.settings.max_per_wave, "at most three per wave")


func test_no_spawning_before_the_enemies_arrive_or_when_disabled() -> void:
	var c: LevelConfig = LevelConfig.new()
	c.id = "test_powerups_arrival"
	c.areas = [load(AREA)]
	c.waves = 1
	c.spawn_delay_seconds = 5.0
	c.powerups_enabled = true
	c.objective = ObjectiveConfig.new()
	var main: Node = load("res://world/main.tscn").instantiate()
	main.autosave = false
	main.level_config = c
	main.get_node("WaveManager").log_waves = false
	add_child_autofree(main)
	await wait_physics_frames(4)
	var pm: PowerUpManager = main.power_up_manager
	pm.settings = pm.settings.duplicate() as PowerUpSet
	pm.settings.first_delay = 0.0
	pm._timer = 0.0
	await wait_physics_frames(30)
	assert_eq(_pickups(main).size(), 0, "the opening delay: nothing yet")
	pm.enabled = false
	main.get_node("WaveManager").spawn_delay_seconds = 0.0


func _sequence(pm: PowerUpManager, main: Node, wave: int) -> Array:
	pm._on_wave_started(wave)
	var seq: Array = []
	for _i: int in 6:
		var p: PowerUpPickup = pm.spawn_one()
		seq.append([p.type.id, p.global_position])
		p.queue_free()
	pm.clear()
	return seq


func test_the_same_wave_gives_the_same_power_ups() -> void:
	var lvl: Dictionary = await _level(true, 100.0)
	var main: Node = lvl["main"]
	var pm: PowerUpManager = lvl["pm"]
	pm.settings = pm.settings.duplicate() as PowerUpSet
	pm.settings.max_per_wave = 99
	var first: Array = _sequence(pm, main, 3)
	var again: Array = _sequence(pm, main, 3)
	assert_eq(first, again, "seeded: Retry replays the same sequence")
	var other: Array = _sequence(pm, main, 4)
	assert_ne(first, other, "another wave, another sequence")


func test_retry_clears_the_power_ups() -> void:
	var lvl: Dictionary = await _level(true, 0.05)
	var main: Node = lvl["main"]
	var pm: PowerUpManager = lvl["pm"]
	pm.spawn_one()
	assert_gt(_pickups(main).size(), 0)
	lvl["wm"].wave_restarting.emit(1)
	await wait_physics_frames(2)
	assert_eq(_pickups(main).size(), 0)


func test_walking_over_a_pickup_applies_it_and_a_refused_one_stays() -> void:
	var lvl: Dictionary = await _level(true, 100.0)
	var main: Node = lvl["main"]
	var pm: PowerUpManager = lvl["pm"]
	var player: Player = lvl["player"]
	var pickup: PowerUpPickup = PowerUpPickup.create(_set.get_type(&"heal"), pm, player.global_position + Vector2(300, 0), 20.0)
	main.add_child(pickup)
	await wait_physics_frames(2)
	pickup._on_body_entered(player)
	await wait_physics_frames(2)
	assert_eq(player.health, 75.0, "50 + 25")
	assert_true(not is_instance_valid(pickup) or pickup.is_queued_for_deletion(), "collected")
	for id: StringName in [&"haste", &"rapid", &"damage"]:
		pm.collect(_set.get_type(id), player)
	var shield: PowerUpPickup = PowerUpPickup.create(_set.get_type(&"shield"), pm, player.global_position + Vector2(300, 0), 20.0)
	main.add_child(shield)
	await wait_physics_frames(2)
	shield._on_body_entered(player)
	assert_false(shield.is_queued_for_deletion(), "at the limit the pickup stays for later")
	assert_eq(player.shield, 0.0)


func test_the_map_list_forgets_pickups_that_vanished() -> void:
	var lvl: Dictionary = await _level(true, 100.0)
	var main: Node = lvl["main"]
	var pm: PowerUpManager = lvl["pm"]
	var a: PowerUpPickup = pm.spawn_one()
	var b: PowerUpPickup = pm.spawn_one()
	assert_eq(pm._on_map.size(), 2)
	a.free()
	pm._physics_process(0.01)
	assert_eq(pm._on_map.size(), 1, "the freed one is dropped from the list (no typed-array error)")
	assert_true(pm._on_map.has(b))
	b.queue_free()
	await wait_physics_frames(2)
	pm._physics_process(0.01)
	assert_eq(pm._on_map.size(), 0)
	assert_eq(_pickups(main).size(), 0)


## Regression (bug in d958db4): expired pickups stayed in the manager's list, so after max_on_map
## pickups nothing spawned again for the rest of the wave.
func test_expired_pickups_vanish_and_spawning_continues() -> void:
	var lvl: Dictionary = await _level(true, 0.05)
	var main: Node = lvl["main"]
	var pm: PowerUpManager = lvl["pm"]
	pm.settings.interval = 0.1
	pm.settings.lifetime = 0.2
	pm.settings.max_per_wave = 6
	var seen: Dictionary = {}
	for i: int in 150:
		await wait_physics_frames(1)
		for pickup: PowerUpPickup in _pickups(main):
			seen[pickup.get_instance_id()] = true
		assert_lte(pm._on_map.size(), pm.settings.max_on_map)
		if pm.spawned_this_wave >= pm.settings.max_per_wave and _pickups(main).is_empty():
			break
	assert_eq(pm.spawned_this_wave, 6, "spawning went on past max_on_map (2) once the first ones expired")
	assert_eq(seen.size(), 6, "every spawned pickup appeared on the map")
	assert_eq(_pickups(main).size(), 0, "each one vanished after its lifetime")
	pm._physics_process(0.01)
	assert_eq(pm._on_map.size(), 0, "the manager's list is empty again")


func test_spawning_continues_after_pickups_are_collected() -> void:
	var lvl: Dictionary = await _level(true, 0.05)
	var main: Node = lvl["main"]
	var player: Player = lvl["player"]
	var pm: PowerUpManager = lvl["pm"]
	pm.settings.interval = 0.05
	pm.settings.max_per_wave = 5
	pm.settings.max_concurrent = 10
	var collected: int = 0
	for i: int in 200:
		await wait_physics_frames(1)
		for pickup: PowerUpPickup in _pickups(main):
			pickup._on_body_entered(player)  # walk over it
			if pickup.is_queued_for_deletion():
				collected += 1
		if pm.spawned_this_wave >= pm.settings.max_per_wave and _pickups(main).is_empty():
			break
	assert_eq(pm.spawned_this_wave, 5, "a collected pickup frees its place on the map")
	assert_eq(collected, 5)
	await wait_physics_frames(1)
	pm._physics_process(0.01)
	assert_eq(pm._on_map.size(), 0)

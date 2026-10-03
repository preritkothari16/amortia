extends GutTest
## Tests for Runner attacks: MeleeAttack rules, Player.take_damage, fitness D attribution,
## and (in the real level) token-only attacks and dead-enemy cleanup.

const RANGE: float = 18.0
const DAMAGE: float = 8.0
const COOLDOWN: float = 1.2

var _attack: MeleeAttack


func before_each() -> void:
	_attack = MeleeAttack.new()


func after_each() -> void:
	get_tree().paused = false


func _player() -> Player:
	var p: Player = load("res://entities/player/player.tscn").instantiate()
	add_child_autofree(p)
	return p


# --- Rules ---------------------------------------------------------------------------

func test_attacks_inside_range() -> void:
	assert_true(_attack.can_attack(true, 12.0, RANGE, true))
	assert_true(_attack.can_attack(true, RANGE, RANGE, true), "edge of range counts")


func test_no_attack_out_of_range() -> void:
	assert_false(_attack.can_attack(true, RANGE + 0.1, RANGE, true))
	assert_false(_attack.can_attack(true, 64.0, RANGE, true), "pressure distance is not an attack")


func test_needs_attack_token() -> void:
	assert_false(_attack.can_attack(false, 10.0, RANGE, true))


func test_needs_clear_line() -> void:
	assert_false(_attack.can_attack(true, 10.0, RANGE, false))


func test_cooldown_blocks_until_over() -> void:
	var target: Player = _player()
	_attack.strike(target, DAMAGE, COOLDOWN, null)
	assert_false(_attack.can_attack(true, 10.0, RANGE, true))
	_attack.tick(1.0)
	assert_false(_attack.can_attack(true, 10.0, RANGE, true))
	_attack.tick(0.2)
	assert_true(_attack.can_attack(true, 10.0, RANGE, true))


func test_cooldown_starts_even_when_dodged() -> void:
	var target: Player = _player()
	target._invuln_left = 0.3
	assert_eq(_attack.strike(target, DAMAGE, COOLDOWN, null), 0.0)
	assert_almost_eq(_attack.cooldown_left, COOLDOWN, 0.0001)


# --- Player damage -------------------------------------------------------------------

func test_player_starts_at_100() -> void:
	var p: Player = _player()
	assert_eq(p.health, 100.0)
	assert_false(p.is_dead)


func test_hit_removes_hp() -> void:
	var p: Player = _player()
	watch_signals(p)
	assert_eq(p.take_damage(DAMAGE), DAMAGE)
	assert_eq(p.health, 100.0 - DAMAGE)
	assert_signal_emitted_with_parameters(p, "damaged", [DAMAGE])


func test_dodge_invulnerability_blocks_damage() -> void:
	var p: Player = _player()
	p._invuln_left = 0.3
	assert_true(p.is_invulnerable)
	var record: FitnessRecord = FitnessRecord.new()
	assert_eq(_attack.strike(p, DAMAGE, COOLDOWN, record), 0.0)
	assert_eq(p.health, 100.0)
	assert_eq(record.damage_dealt, 0.0, "a dodged hit gives no fitness")


func test_real_dodge_roll_blocks_damage() -> void:
	var p: Player = _player()
	p._try_dodge(Vector2.RIGHT)
	assert_eq(p.take_damage(DAMAGE), 0.0)
	p._tick_dodge_timers(0.31)  # invulnerability (0.3 s) over
	assert_eq(p.take_damage(DAMAGE), DAMAGE)


func test_overkill_not_counted_and_player_dies_once() -> void:
	var p: Player = _player()
	p.health = 5.0
	watch_signals(p)
	var record: FitnessRecord = FitnessRecord.new()
	assert_eq(_attack.strike(p, DAMAGE, COOLDOWN, record), 5.0)
	assert_eq(record.damage_dealt, 5.0, "only the HP that was left")
	assert_true(p.is_dead)
	assert_eq(p.health, 0.0)
	assert_eq(p.take_damage(DAMAGE), 0.0, "no damage after death")
	assert_signal_emit_count(p, "died", 1)


func test_revive_restores_full_hp() -> void:
	var p: Player = _player()
	p.take_damage(1000.0)
	p.revive()
	assert_false(p.is_dead)
	assert_eq(p.health, p.stats.max_health)


# --- Attribution and fitness D -------------------------------------------------------

func test_each_runner_credited_with_its_own_hits() -> void:
	var p: Player = _player()
	var a: MeleeAttack = MeleeAttack.new()
	var b: MeleeAttack = MeleeAttack.new()
	var rec_a: FitnessRecord = FitnessRecord.new()
	var rec_b: FitnessRecord = FitnessRecord.new()
	a.strike(p, DAMAGE, COOLDOWN, rec_a)
	b.strike(p, DAMAGE, COOLDOWN, rec_b)
	a.cooldown_left = 0.0
	a.strike(p, DAMAGE, COOLDOWN, rec_a)
	assert_eq(rec_a.damage_dealt, 2.0 * DAMAGE)
	assert_eq(rec_b.damage_dealt, DAMAGE)
	assert_eq(rec_a.damage_dealt + rec_b.damage_dealt, 100.0 - p.health, "credits add up to HP lost")


func test_proximity_alone_gives_no_damage() -> void:
	var record: FitnessRecord = FitnessRecord.new()
	for i: int in 600:
		record.tick(1.0 / 60.0, 5.0, 64.0)  # 10 s right next to the player
	assert_gt(record.pressure_seconds, 9.9)
	assert_eq(record.damage_dealt, 0.0)


func test_fitness_d_becomes_non_zero() -> void:
	var p: Player = _player()
	var record: FitnessRecord = FitnessRecord.new()
	var fitness: Fitness = Fitness.new(load("res://data/fitness.tres"))
	assert_eq(fitness.components(record, 30.0)[Fitness.D], 0.0)
	for i: int in 3:
		_attack.cooldown_left = 0.0
		_attack.strike(p, DAMAGE, COOLDOWN, record)
	var d: float = fitness.components(record, 30.0)[Fitness.D]
	assert_almost_eq(d, 24.0 / 50.0, 0.0001, "D = damage / damage_cap")
	assert_gt(fitness.score(record, 30.0), fitness.score(FitnessRecord.new(), 30.0))


func test_frozen_record_ignores_late_hits() -> void:
	var p: Player = _player()
	var record: FitnessRecord = FitnessRecord.new()
	record.mark_dead()
	_attack.strike(p, DAMAGE, COOLDOWN, record)
	assert_eq(record.damage_dealt, 0.0)


func test_runner_data_has_attack_values() -> void:
	var stats: EnemyStats = load("res://data/runner.tres")
	assert_eq(stats.attack_damage, 8.0)
	assert_eq(stats.attack_range, 18.0)
	assert_eq(stats.attack_cooldown, 1.2)


# --- In the real level ----------------------------------------------------------------

## Level with one aggressive Runner next to the player; no autosave, no pause between waves.
func _level_with_one_runner() -> Dictionary:
	var main: Node = load("res://world/main.tscn").instantiate()
	main.autosave = false
	var wm: WaveManager = main.get_node("WaveManager")
	wm.spawn_seed = 7
	wm.log_waves = false
	wm.auto_next_wave = false
	wm.pause_between_waves = false  # the Wave Report would pause the whole tree
	add_child_autofree(main)
	await wait_physics_frames(2)
	var player: Player = main.get_node("Player")
	for e: Enemy in wm.alive.slice(1):
		e.despawn()
		wm.alive.erase(e)
	var runner: Enemy = wm.alive[0]
	runner.brain.genes.aggression = 1.0
	runner.global_position = player.global_position + Vector2(40, 0)
	return {"main": main, "wm": wm, "player": player, "runner": runner}


func test_in_game_only_token_holder_hits_and_damage_is_attributed() -> void:
	var lvl: Dictionary = await _level_with_one_runner()
	var player: Player = lvl["player"]
	var runner: Enemy = lvl["runner"]
	var ring: AttackRing = lvl["main"].attack_ring
	var id: int = runner.get_instance_id()
	var hit_without_token: bool = false
	var last_hp: float = player.health
	for i: int in 300:
		await wait_physics_frames(1)
		if player.health < last_hp and ring.get_role(id) != AttackRing.Role.ATTACKING:
			hit_without_token = true
		last_hp = player.health
	assert_lt(player.health, 100.0, "the runner reached the player and hit")
	assert_false(hit_without_token, "only hits while holding a token")
	assert_almost_eq(runner.fitness_record.damage_dealt, 100.0 - player.health, 0.0001)


func test_in_game_dead_runner_stops_attacking_and_is_cleaned_up() -> void:
	var lvl: Dictionary = await _level_with_one_runner()
	var player: Player = lvl["player"]
	var runner: Enemy = lvl["runner"]
	var ring: AttackRing = lvl["main"].attack_ring
	var wm: WaveManager = lvl["wm"]
	for i: int in 300:
		await wait_physics_frames(1)
		if player.health < 100.0:
			break
	assert_lt(player.health, 100.0)
	var id: int = runner.get_instance_id()
	var record: FitnessRecord = runner.fitness_record
	runner.take_damage(9999.0)
	var hp_at_death: float = player.health
	var dealt_at_death: float = record.damage_dealt
	await wait_physics_frames(120)
	assert_eq(player.health, hp_at_death, "no hits after death")
	assert_eq(record.damage_dealt, dealt_at_death)
	assert_false(ring.is_member(id))
	assert_false(is_instance_valid(runner))
	assert_eq(wm.alive.size(), 0)


func test_in_game_player_death_ends_wave_and_next_wave_revives() -> void:
	var lvl: Dictionary = await _level_with_one_runner()
	var player: Player = lvl["player"]
	var wm: WaveManager = lvl["wm"]
	player.health = 1.0
	for i: int in 600:
		await wait_physics_frames(1)
		if player.is_dead:
			break
	assert_true(player.is_dead)
	await wait_physics_frames(2)
	assert_false(wm.is_wave_running(), "player down ends the wave")
	var results: Array[Dictionary] = wm.last_wave_results
	assert_gt(results.size(), 0)
	assert_gt(results[0]["components"][Fitness.D], 0.0, "the killer scored D")
	wm.continue_to_next_wave()
	await wait_physics_frames(2)
	assert_false(player.is_dead)
	assert_eq(player.health, 100.0)

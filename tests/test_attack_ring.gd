extends GutTest
## Tests for AttackRing on small hand-made grids. Ids are plain ints (1, 2, 3...).

const DT: float = 1.0 / 60.0


func _settings() -> AttackRingSettings:
	var s: AttackRingSettings = AttackRingSettings.new()
	s.slot_count = 8
	s.slot_radius = 32.0
	s.max_attackers = 3
	s.attack_distance = 12.0
	s.wait_radius = 64.0
	s.token_duration = 2.5
	s.max_slot_tile_cost = 2.0
	s.max_slot_path_cost = 3.5
	return s


## Open 15x15 road grid, player in the middle tile (7,7) = world (120, 120).
func _ring(walls: Array[Vector2i] = [], settings: AttackRingSettings = null) -> AttackRing:
	var rules: TerrainCosts = TerrainCosts.new()
	rules.costs = {"road": 1.0, "fence": 6.0}
	rules.impassable = PackedStringArray(["wall"])
	var rows: Array[PackedStringArray] = []
	for y: int in 15:
		var row: PackedStringArray = PackedStringArray()
		for x: int in 15:
			row.append("wall" if walls.has(Vector2i(x, y)) else "road")
		rows.append(row)
	var field: FlowField = FlowField.new(TerrainGrid.from_rows(rows, rules))
	field.build(Vector2i(7, 7))
	var ring: AttackRing = AttackRing.new(field, settings if settings != null else _settings())
	ring.update(Vector2(120, 120), 0.0)
	return ring


func _around(ring: AttackRing, count: int, radius: float) -> void:
	for i: int in count:
		ring.engage(i + 1, ring.center + Vector2.RIGHT.rotated(TAU * i / count) * radius)


func test_slots_evenly_spaced_on_circle() -> void:
	var ring: AttackRing = _ring()
	for i: int in 8:
		assert_almost_eq(ring.slot_position(i).distance_to(ring.center), 32.0, 0.001)
	assert_almost_eq(ring.slot_direction(0), Vector2.RIGHT, Vector2(0.001, 0.001))
	assert_almost_eq(ring.slot_direction(2), Vector2.DOWN, Vector2(0.001, 0.001))


func test_unknown_enemy_has_no_role() -> void:
	var ring: AttackRing = _ring()
	assert_eq(ring.get_role(99), AttackRing.Role.NONE)
	ring.disengage(99)  # must not error
	assert_eq(ring.get_target(99), ring.center)


func test_single_enemy_gets_nearest_slot_and_attacks() -> void:
	var ring: AttackRing = _ring()
	ring.engage(1, ring.center + Vector2(0, 50))  # below the player
	assert_eq(ring.get_role(1), AttackRing.Role.WAITING, "slots are handed out in update()")
	ring.update(ring.center, DT)
	assert_eq(ring.get_slot_owner(2), 1, "slot 2 points down")
	assert_eq(ring.get_role(1), AttackRing.Role.ATTACKING, "free token goes to the only holder")
	assert_almost_eq(ring.get_target(1), ring.center + Vector2(0, 12), Vector2(0.001, 0.001), "steps in on its own side")


func test_twelve_enemies_fill_eight_slots_three_attack() -> void:
	var ring: AttackRing = _ring()
	_around(ring, 12, 50.0)
	ring.update(ring.center, DT)
	var roles: Dictionary = {}
	for id: int in range(1, 13):
		var r: AttackRing.Role = ring.get_role(id)
		roles[r] = roles.get(r, 0) + 1
	assert_eq(roles.get(AttackRing.Role.ATTACKING, 0), 3)
	assert_eq(roles.get(AttackRing.Role.HOLDING, 0), 5)
	assert_eq(roles.get(AttackRing.Role.WAITING, 0), 4)
	var owners: Dictionary = {}
	for i: int in 8:
		assert_ne(ring.get_slot_owner(i), AttackRing.FREE)
		owners[ring.get_slot_owner(i)] = true
	assert_eq(owners.size(), 8, "every slot has a different owner")


func test_waiting_target_is_on_outer_ring_own_side() -> void:
	var ring: AttackRing = _ring()
	_around(ring, 8, 40.0)
	ring.engage(100, ring.center + Vector2(-90, 0))
	ring.update(ring.center, DT)
	assert_eq(ring.get_role(100), AttackRing.Role.WAITING)
	assert_almost_eq(ring.get_target(100), ring.center + Vector2(-64, 0), Vector2(0.001, 0.001))


func test_nearest_waiting_enemy_gets_freed_slot() -> void:
	var ring: AttackRing = _ring()
	_around(ring, 8, 40.0)
	ring.engage(100, ring.center + Vector2(90, 0))
	ring.engage(101, ring.center + Vector2(70, 5))
	ring.update(ring.center, DT)
	var freed_slot: int = 0
	var leaver: int = ring.get_slot_owner(freed_slot)
	ring.disengage(leaver)
	ring.update(ring.center, DT)
	assert_eq(ring.get_role(leaver), AttackRing.Role.NONE)
	assert_eq(ring.get_slot_owner(freed_slot), 101, "the closer of the two waiting enemies")
	assert_eq(ring.get_role(100), AttackRing.Role.WAITING)


func test_dead_attacker_token_goes_to_holder() -> void:
	var ring: AttackRing = _ring()
	_around(ring, 8, 40.0)
	ring.update(ring.center, DT)
	assert_eq(ring.get_attacker_count(), 3)
	var attacker: int = -1
	for id: int in range(1, 9):
		if ring.get_role(id) == AttackRing.Role.ATTACKING:
			attacker = id
			break
	ring.disengage(attacker)
	ring.update(ring.center, DT)
	assert_eq(ring.get_attacker_count(), 3, "a holder took over the token")
	assert_eq(ring.get_role(attacker), AttackRing.Role.NONE)


func test_tokens_rotate_after_duration() -> void:
	var ring: AttackRing = _ring()
	_around(ring, 8, 40.0)
	ring.update(ring.center, DT)
	var first: Array[int] = []
	for id: int in range(1, 9):
		if ring.get_role(id) == AttackRing.Role.ATTACKING:
			first.append(id)
	ring.update(ring.center, 2.4)
	for id: int in first:
		assert_eq(ring.get_role(id), AttackRing.Role.ATTACKING, "still within token_duration")
	ring.update(ring.center, 0.2)
	for id: int in first:
		assert_eq(ring.get_role(id), AttackRing.Role.HOLDING, "handed over after 2.5 s")
	assert_eq(ring.get_attacker_count(), 3)


func test_tokens_kept_when_nobody_else_waits() -> void:
	var ring: AttackRing = _ring()
	_around(ring, 2, 40.0)
	ring.update(ring.center, DT)
	ring.update(ring.center, 10.0)
	assert_eq(ring.get_role(1), AttackRing.Role.ATTACKING)
	assert_eq(ring.get_role(2), AttackRing.Role.ATTACKING)


func test_slots_in_walls_are_not_used() -> void:
	# Wall column 2 tiles east of the player: slot 0 (east, 32 px = 2 tiles) is inside it.
	var walls: Array[Vector2i] = []
	for y: int in 15:
		walls.append(Vector2i(9, y))
	var ring: AttackRing = _ring(walls)
	assert_false(ring.is_slot_valid(0))
	_around(ring, 10, 40.0)
	ring.update(ring.center, DT)
	assert_eq(ring.get_slot_owner(0), AttackRing.FREE)


func test_holder_released_when_its_slot_becomes_invalid() -> void:
	var walls: Array[Vector2i] = []
	for y: int in 15:
		walls.append(Vector2i(10, y))
	var ring: AttackRing = _ring(walls)
	ring.engage(1, ring.center + Vector2(40, 0))
	ring.update(ring.center, DT)
	assert_eq(ring.get_slot_owner(0), 1)
	# Player steps one tile east: slot 0 is now inside the wall at x = 10.
	ring.flow_field.build(Vector2i(8, 7))
	ring.update(ring.center + Vector2(16, 0), DT)
	assert_eq(ring.get_slot_owner(0), AttackRing.FREE)
	assert_ne(ring.get_role(1), AttackRing.Role.NONE, "still engaged, moved to another slot")


func test_assignment_does_not_depend_on_engage_order() -> void:
	var a: AttackRing = _ring()
	var b: AttackRing = _ring()
	var positions: Array[Vector2] = []
	for i: int in 12:
		positions.append(a.center + Vector2.RIGHT.rotated(i * 0.7) * (40.0 + i * 3))
	for i: int in 12:
		a.engage(i + 1, positions[i])
	for i: int in range(11, -1, -1):
		b.engage(i + 1, positions[i])
	a.update(a.center, DT)
	b.update(b.center, DT)
	for i: int in 8:
		assert_eq(a.get_slot_owner(i), b.get_slot_owner(i), "slot %d" % i)
	for id: int in range(1, 13):
		assert_eq(a.get_role(id), b.get_role(id), "id %d" % id)


func test_data_file_values() -> void:
	var s: AttackRingSettings = load("res://data/attack_ring.tres")
	assert_eq(s.slot_count, 8)
	assert_eq(s.max_attackers, 3)
	assert_gt(s.release_cost, s.engage_cost, "hysteresis")

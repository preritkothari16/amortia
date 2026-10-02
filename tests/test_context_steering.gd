extends GutTest
## Tests for ContextSteering (pure steering maths).

const EPS: Vector2 = Vector2(0.001, 0.001)


func _weights(seek: float, separation: float, wall: float) -> ContextSteering.Weights:
	var w: ContextSteering.Weights = ContextSteering.Weights.new()
	w.seek = seek
	w.separation = separation
	w.wall_avoidance = wall
	return w


func _field(lines: Array[String], target: Vector2i) -> FlowField:
	var rules: TerrainCosts = TerrainCosts.new()
	rules.costs = {"road": 1.0}
	rules.impassable = PackedStringArray(["wall"])
	var rows: Array[PackedStringArray] = []
	for line: String in lines:
		var row: PackedStringArray = PackedStringArray()
		for c: String in line:
			row.append("wall" if c == "#" else "road")
		rows.append(row)
	var field: FlowField = FlowField.new(TerrainGrid.from_rows(rows, rules))
	field.build(target)
	return field


# --- seek / arrive -------------------------------------------------------------------

func test_seek_full_speed_along_direction() -> void:
	assert_eq(ContextSteering.seek(Vector2.RIGHT, 70.0), Vector2(70, 0))
	assert_almost_eq(ContextSteering.seek(Vector2(3, 4), 10.0), Vector2(6, 8), EPS, "normalises")
	assert_eq(ContextSteering.seek(Vector2.ZERO, 70.0), Vector2.ZERO)


func test_arrive_slows_inside_radius() -> void:
	assert_eq(ContextSteering.arrive(Vector2(100, 0), 60.0, 20.0), Vector2(60, 0), "outside radius: full speed")
	assert_eq(ContextSteering.arrive(Vector2(10, 0), 60.0, 20.0), Vector2(30, 0), "half way in: half speed")
	assert_eq(ContextSteering.arrive(Vector2.ZERO, 60.0, 20.0), Vector2.ZERO, "on target: stop")


# --- separation ----------------------------------------------------------------------

func test_separation_pushes_away_harder_when_closer() -> void:
	var near: Vector2 = ContextSteering.separation(Vector2.ZERO, PackedVector2Array([Vector2(2, 0)]), 10.0)
	var far: Vector2 = ContextSteering.separation(Vector2.ZERO, PackedVector2Array([Vector2(8, 0)]), 10.0)
	assert_lt(near.x, 0.0, "pushed left, away from the neighbour")
	assert_gt(near.length(), far.length())
	assert_almost_eq(ContextSteering.separation(Vector2.ZERO, PackedVector2Array([Vector2(5, 0)]), 10.0), Vector2(-0.5, 0), EPS)


func test_separation_ignores_far_and_overlapping() -> void:
	var others: PackedVector2Array = PackedVector2Array([Vector2(10, 0), Vector2(50, 50), Vector2.ZERO])
	assert_eq(ContextSteering.separation(Vector2.ZERO, others, 10.0), Vector2.ZERO)


func test_separation_balanced_neighbours_cancel() -> void:
	var others: PackedVector2Array = PackedVector2Array([Vector2(4, 0), Vector2(-4, 0)])
	assert_almost_eq(ContextSteering.separation(Vector2.ZERO, others, 10.0), Vector2.ZERO, EPS)


# --- wall avoidance ------------------------------------------------------------------

func test_feeler_directions() -> void:
	var f: PackedVector2Array = ContextSteering.feeler_directions(Vector2(5, 0), deg_to_rad(90.0))
	assert_eq(f.size(), 3)
	assert_almost_eq(f[0], Vector2.RIGHT, EPS)
	assert_almost_eq(f[1], Vector2.DOWN, EPS)
	assert_almost_eq(f[2], Vector2.UP, EPS)


func test_wall_avoidance_no_hits_no_push() -> void:
	var push: Vector2 = ContextSteering.wall_avoidance(PackedFloat32Array([1.0, 1.0, 1.0]), PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]))
	assert_eq(push, Vector2.ZERO)


func test_wall_avoidance_pushes_along_normal_harder_when_close() -> void:
	var close: Vector2 = ContextSteering.wall_avoidance(PackedFloat32Array([0.25]), PackedVector2Array([Vector2.LEFT]))
	var far: Vector2 = ContextSteering.wall_avoidance(PackedFloat32Array([0.75]), PackedVector2Array([Vector2.LEFT]))
	assert_almost_eq(close, Vector2(-0.75, 0), EPS)
	assert_almost_eq(far, Vector2(-0.25, 0), EPS)


func test_wall_avoidance_sums_feelers() -> void:
	# Corner: one feeler sees a wall on the right, another a wall below.
	var push: Vector2 = ContextSteering.wall_avoidance(
		PackedFloat32Array([0.5, 1.0, 0.5]), PackedVector2Array([Vector2.LEFT, Vector2.ZERO, Vector2.UP]))
	assert_almost_eq(push, Vector2(-0.5, -0.5), EPS)


# --- combine / smoothing -------------------------------------------------------------

func test_combine_uses_weights_and_caps_speed() -> void:
	var only_seek: Vector2 = ContextSteering.combine(Vector2(70, 0), Vector2(0, 1), Vector2(0, 1), _weights(1, 0, 0), 70.0)
	assert_eq(only_seek, Vector2(70, 0), "zero weights switch behaviours off")
	var bent: Vector2 = ContextSteering.combine(Vector2(70, 0), Vector2(0, 1), Vector2.ZERO, _weights(1, 0.5, 0), 70.0)
	assert_gt(bent.y, 0.0, "separation bends the path")
	assert_almost_eq(bent.length(), 70.0, 0.001, "capped at max speed")
	var walled: Vector2 = ContextSteering.combine(Vector2(70, 0), Vector2.ZERO, Vector2(-1, 0), _weights(1, 0, 1), 70.0)
	assert_almost_eq(walled, Vector2.ZERO, EPS, "a wall push of 1 at weight 1 cancels full seek")


func test_smooth_velocity_limits_change_per_frame() -> void:
	var v: Vector2 = ContextSteering.smooth_velocity(Vector2(70, 0), Vector2(-70, 0), 600.0, 0.1)
	assert_almost_eq(v, Vector2(10, 0), EPS, "changed by 60 px/s, no snap reversal")


func test_smooth_velocity_turn_rate_limit() -> void:
	# Wants to turn 1 rad while moving right: may only turn 0.5 rad this frame, and brakes
	# to cos(1 rad) of the desired speed because it still faces the wrong way.
	var desired: Vector2 = Vector2.RIGHT.rotated(1.0) * 70.0
	var v: Vector2 = ContextSteering.smooth_velocity(Vector2(70, 0), desired, 10000.0, 0.1, 0.0, 5.0)
	assert_almost_eq(v.angle(), 0.5, 0.001)
	assert_almost_eq(v.length(), 70.0 * cos(1.0), 0.001)
	var free: Vector2 = ContextSteering.smooth_velocity(Vector2(70, 0), Vector2(0, 70), 10000.0, 0.1)
	assert_almost_eq(free, Vector2(0, 70), EPS, "no limit when rate is 0")


func test_smooth_velocity_brakes_instead_of_reversing() -> void:
	# Goal straight behind: no U-turn at speed, it slows down (here to a stop).
	var v: Vector2 = ContextSteering.smooth_velocity(Vector2(70, 0), Vector2(-70, 0), 10000.0, 0.1, 0.0, 5.0)
	assert_almost_eq(v, Vector2.ZERO, EPS)


func test_smooth_velocity_dead_zone() -> void:
	assert_eq(ContextSteering.smooth_velocity(Vector2.ZERO, Vector2(3, 0), 600.0, 0.1, 6.0), Vector2.ZERO)
	assert_eq(ContextSteering.smooth_velocity(Vector2.ZERO, Vector2(30, 0), 600.0, 0.1, 6.0), Vector2(30, 0))


# --- sample_flow ---------------------------------------------------------------------

func test_sample_flow_at_tile_centre_equals_its_arrow() -> void:
	var field: FlowField = _field(["T...."], Vector2i(0, 0))
	assert_almost_eq(ContextSteering.sample_flow(field, Vector2(3 * 16 + 8, 8)), Vector2.LEFT, EPS)


func test_sample_flow_blends_between_tiles() -> void:
	# Find two vertically adjacent tiles whose arrows differ. Half way between their centres
	# the heading must be the average of the two, not a jump to either one.
	var field: FlowField = _field(["......", "......", "......", "......"], Vector2i(0, 3))
	var found: bool = false
	for y: int in 3:
		for x: int in 6:
			var a: Vector2 = field.get_direction(Vector2i(x, y))
			var b: Vector2 = field.get_direction(Vector2i(x, y + 1))
			if a == Vector2.ZERO or b == Vector2.ZERO or a.is_equal_approx(b):
				continue
			var mid: Vector2 = ContextSteering.sample_flow(field, Vector2(x * 16 + 8, (y + 1) * 16))
			assert_almost_eq(mid, (a + b).normalized(), EPS, "between %s and %s" % [Vector2i(x, y), Vector2i(x, y + 1)])
			found = true
	assert_true(found, "test grid has at least one pair of differing arrows")


func test_sample_flow_ignores_walls() -> void:
	var field: FlowField = _field(["...", "##.", "T.."], Vector2i(0, 2))
	# Between road (2,0) and wall (1,1)-ish corner: result must still be a unit heading.
	var dir: Vector2 = ContextSteering.sample_flow(field, Vector2(32, 16))
	assert_almost_eq(dir.length(), 1.0, 0.001)
	assert_gt(dir.x, 0.0, "heads right, round the wall")


# --- queuing -------------------------------------------------------------------------

func test_queue_no_one_ahead_full_speed() -> void:
	var f: float = ContextSteering.queue_factor(Vector2.ZERO, Vector2(70, 0),
		PackedVector2Array([Vector2(-8, 0), Vector2(0, 12)]), PackedVector2Array([Vector2.ZERO, Vector2.ZERO]), 14.0, 8.0)
	assert_eq(f, 1.0, "ally behind and ally off to the side don't block")


func test_queue_stopped_ally_ahead_stops_us() -> void:
	var f: float = ContextSteering.queue_factor(Vector2.ZERO, Vector2(70, 0),
		PackedVector2Array([Vector2(10, 2)]), PackedVector2Array([Vector2.ZERO]), 14.0, 8.0)
	assert_eq(f, 0.0)


func test_queue_matches_slower_ally_pace() -> void:
	var f: float = ContextSteering.queue_factor(Vector2.ZERO, Vector2(70, 0),
		PackedVector2Array([Vector2(10, 0)]), PackedVector2Array([Vector2(35, 0)]), 14.0, 8.0)
	assert_almost_eq(f, 0.5, 0.001)


func test_queue_faster_ally_does_not_slow_us() -> void:
	var f: float = ContextSteering.queue_factor(Vector2.ZERO, Vector2(70, 0),
		PackedVector2Array([Vector2(10, 0)]), PackedVector2Array([Vector2(90, 0)]), 14.0, 8.0)
	assert_eq(f, 1.0)


func test_turn_limit_skipped_when_slow() -> void:
	# Below turn_limit_speed the heading may change freely (only acceleration limits it).
	var v: Vector2 = ContextSteering.smooth_velocity(Vector2(10, 0), Vector2(0, 10), 10000.0, 0.1, 0.0, 5.0, 35.0)
	assert_almost_eq(v, Vector2(0, 10), EPS)

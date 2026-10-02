class_name ContextSteering
extends RefCounted
## Hand-written steering (GDD 6.3). Pure maths, no Nodes: the enemy scene gathers the
## "context" - flow-field direction, nearby allies, feeler ray hits - and these functions turn
## it into one desired velocity. Classic weighted steering behaviours (Reynolds):
##   desired = seek * w_seek + separation * w_sep + wall_avoidance * w_wall   (capped at max speed)
## The enemy then turns its real velocity towards `desired` at a limited rate (smooth_velocity),
## so nothing ever snaps.


## Weights and limits for combine(). Built once per enemy from its stats.
class Weights:
	var seek: float = 1.0
	var separation: float = 1.0
	var wall_avoidance: float = 1.0


# --- Navigation input ----------------------------------------------------------------

## Flow direction at a world position, blended from the arrows of the 4 tile centres around
## it (bilinear interpolation). Reading only the tile under the enemy makes the heading jump
## each time it crosses a tile edge; blending turns those jumps into a smooth curve.
## Unreachable tiles (no arrow) are left out. If the arrows cancel out (e.g. on the ridge
## between two equal routes round an obstacle), falls back to the arrow of the tile itself.
static func sample_flow(field: FlowField, world_pos: Vector2) -> Vector2:
	var coords: GridCoords = field.grid.coords
	# Position in "tile-centre space": integer values sit exactly on tile centres.
	var local: Vector2 = (world_pos - coords.origin) / float(coords.tile_size) - Vector2(0.5, 0.5)
	var base: Vector2i = Vector2i(floori(local.x), floori(local.y))
	var t: Vector2 = local - Vector2(base)  # 0..1 inside the square of 4 centres
	var blended: Vector2 = Vector2.ZERO
	for corner: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
		var weight: float = (t.x if corner.x == 1 else 1.0 - t.x) * (t.y if corner.y == 1 else 1.0 - t.y)
		blended += field.get_direction(base + corner) * weight
	if blended.length() < 0.1:
		return field.get_direction(coords.world_to_cell(world_pos))
	return blended.normalized()


## Pursuit prediction: where the target will be after `prediction_time` seconds if it keeps
## its current velocity. Aiming here makes chasers cut the player off instead of trailing.
static func predict_position(target_position: Vector2, target_velocity: Vector2, prediction_time: float) -> Vector2:
	return target_position + target_velocity * prediction_time


## Sideways offsets for a "fat" line-of-sight check: a centre ray plus one ray on each side,
## `half_width` apart. If all three are clear, a body of that radius fits along the line
## (a single thin ray can slip past a corner the body would hit).
static func lane_offsets(from: Vector2, to: Vector2, half_width: float) -> PackedVector2Array:
	var along: Vector2 = to - from
	if along.length() < 0.001:
		return PackedVector2Array([Vector2.ZERO])
	var side: Vector2 = along.normalized().orthogonal() * half_width
	return PackedVector2Array([Vector2.ZERO, side, -side])


## Which way to head: straight at the target when it is in sight (line-of-sight shortcut),
## otherwise along the flow field. `to_target` = sight target - own position.
static func choose_heading(flow_direction: Vector2, target_in_sight: bool, to_target: Vector2) -> Vector2:
	if target_in_sight and to_target.length() > 0.001:
		return to_target.normalized()
	return flow_direction


# --- Behaviours (each returns a velocity or an unscaled push) ------------------------

## Full speed along `direction`. ZERO direction = stand still.
static func seek(direction: Vector2, max_speed: float) -> Vector2:
	return direction.normalized() * max_speed


## Head for a point but slow down inside `slow_radius`, stopping on it instead of overshooting.
## `offset` = target position - own position.
static func arrive(offset: Vector2, max_speed: float, slow_radius: float) -> Vector2:
	var distance: float = offset.length()
	if distance < 0.001:
		return Vector2.ZERO
	var speed: float = max_speed
	if distance < slow_radius:
		speed = max_speed * distance / slow_radius
	return offset / distance * speed


## Push away from neighbours closer than `radius`. The closer a neighbour, the harder the
## push (1 when touching, 0 at the radius). Neighbours exactly on top give no direction
## and are skipped. Result is unscaled: about 1 per close neighbour.
static func separation(position: Vector2, neighbours: PackedVector2Array, radius: float) -> Vector2:
	var push: Vector2 = Vector2.ZERO
	for other: Vector2 in neighbours:
		var offset: Vector2 = position - other
		var distance: float = offset.length()
		if distance >= radius or distance < 0.001:
			continue
		push += offset / distance * (1.0 - distance / radius)
	return push


## Push away from walls seen by the feelers. For each feeler i:
##   hit_fractions[i] = where along the feeler the wall was hit (0 = at the enemy, 1 = no hit)
##   hit_normals[i]   = the wall's surface normal at the hit (points out of the wall)
## Each hit pushes along its normal, harder the closer the wall: (1 - fraction).
static func wall_avoidance(hit_fractions: PackedFloat32Array, hit_normals: PackedVector2Array) -> Vector2:
	var push: Vector2 = Vector2.ZERO
	for i: int in hit_fractions.size():
		if hit_fractions[i] < 1.0:
			push += hit_normals[i] * (1.0 - hit_fractions[i])
	return push


## Queuing (Reynolds): if an ally just ahead is moving slower than we want to go, match its
## pace instead of shoving into it. Without this, enemies at the back of a crowd push forever
## and the whole crowd churns. Returns a 0..1 factor for the seek velocity.
##   heading     = the velocity we want (seek), its length = the speed we want
##   look_ahead  = how far ahead (px) an ally counts as "in front"
##   lane_width  = how far to the side (px) an ally may be and still block us (about one body)
static func queue_factor(position: Vector2, heading: Vector2, neighbour_positions: PackedVector2Array, neighbour_velocities: PackedVector2Array, look_ahead: float, lane_width: float) -> float:
	var my_speed: float = heading.length()
	if my_speed < 0.001:
		return 1.0
	var dir: Vector2 = heading / my_speed
	var factor: float = 1.0
	for i: int in neighbour_positions.size():
		var offset: Vector2 = neighbour_positions[i] - position
		var ahead: float = offset.dot(dir)
		if ahead <= 0.0 or ahead > look_ahead or absf(offset.cross(dir)) > lane_width:
			continue  # behind us, too far ahead, or off to the side
		var their_speed: float = neighbour_velocities[i].dot(dir)  # their speed in our direction
		factor = minf(factor, clampf(their_speed / my_speed, 0.0, 1.0))
	return factor


## Directions for the feeler rays: one straight ahead, two angled left and right.
static func feeler_directions(heading: Vector2, side_angle: float) -> PackedVector2Array:
	var forward: Vector2 = heading.normalized()
	return PackedVector2Array([forward, forward.rotated(side_angle), forward.rotated(-side_angle)])


# --- Putting it together -------------------------------------------------------------

## Weighted sum of the behaviours, capped at max_speed. Pushes are scaled by max_speed so
## the weights mean the same thing whatever the enemy's speed.
static func combine(seek_velocity: Vector2, separation_push: Vector2, wall_push: Vector2, weights: Weights, max_speed: float) -> Vector2:
	var desired: Vector2 = seek_velocity * weights.seek
	desired += separation_push * weights.separation * max_speed
	desired += wall_push * weights.wall_avoidance * max_speed
	return desired.limit_length(max_speed)


## Moves the current velocity towards `desired` without snapping:
##   1. Desired speeds below `dead_zone` count as "stop", so tiny opposing pushes in a crowd
##      don't make enemies shiver on the spot.
##   2. While moving faster than `turn_limit_speed`, the heading may rotate at most
##      `max_turn_rate` radians per second (0 = no limit), so a sudden new direction becomes
##      a curve. It also "brakes to turn": the target speed is scaled by cos(angle left to
##      turn), so a unit that needs to turn 90 degrees or more slows down instead of circling
##      its goal at full speed (turn-limited units otherwise orbit).
##   3. The velocity then changes by at most `acceleration * delta` per frame.
static func smooth_velocity(current: Vector2, desired: Vector2, acceleration: float, delta: float, dead_zone: float = 0.0, max_turn_rate: float = 0.0, turn_limit_speed: float = 0.0) -> Vector2:
	if desired.length() < dead_zone:
		desired = Vector2.ZERO
	if max_turn_rate > 0.0 and current.length() > maxf(turn_limit_speed, 1.0) and desired.length() > 1.0:
		var angle: float = current.angle_to(desired)
		var max_step: float = max_turn_rate * delta
		if absf(angle) > max_step:
			var brake: float = maxf(cos(angle), 0.0)
			desired = current.normalized().rotated(signf(angle) * max_step) * desired.length() * brake
	return current.move_toward(desired, acceleration * delta)

class_name Steering
extends RefCounted
## Pure steering maths (GDD 6.3). Every function takes plain vectors and returns a desired
## velocity or a push; the enemy scene decides how fast to turn towards it.
## Prototype set: seek, arrive, separation. Wall avoidance and pursuit come later.


## Full speed along `direction` (e.g. the flow-field arrow). ZERO direction = stand still.
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


## Adds a weighted separation push to a desired velocity and caps it at max_speed.
static func blend(desired: Vector2, separation_push: Vector2, separation_weight: float, max_speed: float) -> Vector2:
	return (desired + separation_push * separation_weight * max_speed).limit_length(max_speed)

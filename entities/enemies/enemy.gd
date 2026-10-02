class_name Enemy
extends CharacterBody2D
## Thin enemy shell: physics, collision, health and greybox visuals.
## Where to go comes from the shared FlowField; how to move comes from ContextSteering
## (res://ai/steering/). The Node only supplies world information (ray hits, neighbours).
## Archetype numbers come from an EnemyStats resource (e.g. data/runner.tres).

signal died(enemy: Enemy)

@export var stats: EnemyStats

var health: float = 0.0
## True while crossing a climbable tile (fence) with world collision switched off.
var is_climbing: bool = false
## How the enemy chose its heading this frame: &"flow" (arrows), &"sight" (straight at the
## player / predicted position), &"ring" (going to its attack-ring slot / attack point /
## waiting point), &"close" (arriving next to the player, only without a ring), &"climb".
var nav_mode: StringName = &"flow"

var _flow_field: FlowField
var _grid: TerrainGrid
var _target: Node2D
## Shared attack ring (null = no ring: close in on the player directly).
var _ring: AttackRing
## Shared list of living enemies (owned by WaveManager), used for separation.
var _allies: Array[Enemy] = []
## Collision mask while walking (world + other enemies), and the world-only part of it.
var _normal_mask: int = 0
var _world_mask: int = 0
var _dead: bool = false
var _weights: ContextSteering.Weights = ContextSteering.Weights.new()
## Allies within the separation radius this frame (reused arrays, no per-frame allocation).
var _near_positions: PackedVector2Array = PackedVector2Array()
var _near_velocities: PackedVector2Array = PackedVector2Array()
## Collision radius, used to make line-of-sight checks as wide as the body.
var _body_radius: float = 5.0

@onready var _body: Polygon2D = $Body


func _ready() -> void:
	health = stats.max_health
	_body.color = stats.color
	_normal_mask = collision_mask
	_world_mask = collision_mask & 1  # feelers and climbing only care about the world layer
	_weights.seek = stats.seek_weight
	_weights.separation = stats.separation_weight
	_weights.wall_avoidance = stats.wall_avoidance_weight
	var shape: CircleShape2D = ($CollisionShape2D as CollisionShape2D).shape as CircleShape2D
	if shape != null:
		_body_radius = shape.radius


## Called by the spawner before the enemy starts moving.
func setup(flow_field: FlowField, target: Node2D, allies: Array[Enemy], ring: AttackRing = null) -> void:
	_flow_field = flow_field
	_grid = flow_field.grid
	_target = target
	_allies = allies
	_ring = ring


func _physics_process(delta: float) -> void:
	if _flow_field == null or not _flow_field.is_built():
		return
	var cell: Vector2i = _grid.coords.world_to_cell(global_position)
	var next: Vector2i = _flow_field.get_next_cell(cell)
	var cost: float = _flow_field.get_cost(cell)
	var role: AttackRing.Role = _update_ring_membership(cost)
	var close: bool = _ring == null and cost <= stats.close_in_cost
	# Where to aim if the player is visible (INF = not visible). A clear straight line beats
	# climbing a fence the arrows would have sent us over.
	var sight_point: Vector2 = Vector2.INF if (close or is_climbing) else _sight_target()
	if is_climbing or (sight_point == Vector2.INF and _is_climbable(next)):
		nav_mode = &"climb"
		_climb(cell, next, delta)
		return

	# Gather the context, let ContextSteering decide, then move.
	var seek_velocity: Vector2
	if role != AttackRing.Role.NONE:
		seek_velocity = _ring_seek(role)
	elif close:
		# Next to the player: close in directly and slow down instead of piling onto them.
		nav_mode = &"close"
		seek_velocity = ContextSteering.arrive(_target.global_position - global_position, stats.move_speed, stats.arrive_radius)
	else:
		var in_sight: bool = sight_point != Vector2.INF
		nav_mode = &"sight" if in_sight else &"flow"
		var heading_dir: Vector2 = ContextSteering.choose_heading(
				ContextSteering.sample_flow(_flow_field, global_position), in_sight,
				(sight_point - global_position) if in_sight else Vector2.ZERO)
		seek_velocity = ContextSteering.seek(heading_dir, stats.move_speed)
	_gather_neighbours()
	if cost <= stats.crowd_cost and (role == AttackRing.Role.NONE or role == AttackRing.Role.WAITING):
		# Near the player a crowd forms: wait behind slower allies instead of shoving them.
		# Slot holders and attackers skip this so waiting enemies can't block them for good.
		seek_velocity *= ContextSteering.queue_factor(global_position, seek_velocity, _near_positions, _near_velocities,
				stats.separation_radius, stats.queue_lane_width)
	var separation_push: Vector2 = ContextSteering.separation(global_position, _near_positions, stats.separation_radius)
	var heading: Vector2 = velocity if velocity.length() > 5.0 else seek_velocity
	var wall_push: Vector2 = _wall_push(heading)
	var desired: Vector2 = ContextSteering.combine(seek_velocity, separation_push, wall_push, _weights, stats.move_speed)
	velocity = ContextSteering.smooth_velocity(velocity, desired, stats.acceleration, delta,
			stats.dead_zone_speed, deg_to_rad(stats.max_turn_rate_degrees), stats.turn_limit_min_speed)
	move_and_slide()


## Joins the ring when the flow cost to the player is low enough, leaves it when it is
## clearly too high (in between: keep whatever we had). Returns our role.
func _update_ring_membership(cost: float) -> AttackRing.Role:
	if _ring == null:
		return AttackRing.Role.NONE
	var id: int = get_instance_id()
	if cost <= _ring.settings.engage_cost or (_ring.is_member(id) and cost <= _ring.settings.release_cost):
		_ring.engage(id, global_position)
	else:
		_ring.disengage(id)
	return _ring.get_role(id)


## Seek velocity for an enemy in the ring: straight to its ring target when the way is clear,
## otherwise keep following the flow field until it is.
func _ring_seek(role: AttackRing.Role) -> Vector2:
	var target: Vector2 = _ring.get_target(get_instance_id())
	var clear: bool = _clear_path_to(target)
	if role == AttackRing.Role.WAITING and not clear \
			and global_position.distance_to(_ring.center) <= _ring.settings.wait_radius:
		nav_mode = &"ring"
		return Vector2.ZERO  # too close and boxed in: hold still rather than push inwards
	if clear:
		nav_mode = &"ring"
		return ContextSteering.arrive(target - global_position, stats.move_speed, stats.arrive_radius)
	nav_mode = &"flow"
	return ContextSteering.seek(ContextSteering.sample_flow(_flow_field, global_position), stats.move_speed)


## Line-of-sight shortcut + pursuit: the point to run straight at, or Vector2.INF if the
## player is out of range or hidden behind the world. Tries the predicted position first
## (cut the player off), then the player's current position.
func _sight_target() -> Vector2:
	var target_pos: Vector2 = _target.global_position
	if global_position.distance_squared_to(target_pos) > stats.sight_range * stats.sight_range:
		return Vector2.INF
	var target_velocity: Vector2 = Vector2.ZERO
	if _target is CharacterBody2D:
		target_velocity = (_target as CharacterBody2D).velocity
	var predicted: Vector2 = ContextSteering.predict_position(target_pos, target_velocity, stats.prediction_time)
	if _clear_path_to(predicted):
		return predicted
	if predicted != target_pos and _clear_path_to(target_pos):
		return target_pos
	return Vector2.INF


## True if a body of our radius could move in a straight line to `point` without hitting
## the world (three parallel rays: centre and both sides).
func _clear_path_to(point: Vector2) -> bool:
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	for offset: Vector2 in ContextSteering.lane_offsets(global_position, point, _body_radius):
		var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(
				global_position + offset, point + offset, _world_mask)
		if not space.intersect_ray(query).is_empty():
			return false
	return true


## Casts the feeler rays against the world layer and asks ContextSteering for a push.
## This is the only part of steering that needs the physics engine, so it stays in the Node.
func _wall_push(heading: Vector2) -> Vector2:
	if heading == Vector2.ZERO:
		return Vector2.ZERO
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var feelers: PackedVector2Array = ContextSteering.feeler_directions(heading, deg_to_rad(stats.feeler_angle_degrees))
	var fractions: PackedFloat32Array = PackedFloat32Array()
	var normals: PackedVector2Array = PackedVector2Array()
	for dir: Vector2 in feelers:
		var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(
			global_position, global_position + dir * stats.feeler_length, _world_mask)
		var hit: Dictionary = space.intersect_ray(query)
		if hit.is_empty():
			fractions.append(1.0)
			normals.append(Vector2.ZERO)
		else:
			var hit_pos: Vector2 = hit["position"]
			fractions.append(global_position.distance_to(hit_pos) / stats.feeler_length)
			normals.append(hit["normal"])
	return ContextSteering.wall_avoidance(fractions, normals)


## Crosses a fence by following the arrows tile centre to tile centre, without physics.
## Safe because arrows only ever lead into walkable tiles and never cut wall corners.
func _climb(cell: Vector2i, next: Vector2i, delta: float) -> void:
	if not is_climbing:
		is_climbing = true
		collision_mask = 0
	var goal: Vector2 = _grid.coords.cell_to_world(next)
	var on_climbable: bool = _is_climbable(cell)
	if not on_climbable and not _is_climbable(next):
		# Over the fence: finish at this tile's centre, then hand back to normal movement.
		goal = _grid.coords.cell_to_world(cell)
		if global_position.distance_to(goal) < 1.0:
			is_climbing = false
			collision_mask = _normal_mask
			return
	var speed: float = stats.move_speed
	if on_climbable:
		speed /= _grid.get_cost(cell, _flow_field.profile)
	velocity = global_position.direction_to(goal) * speed
	global_position = global_position.move_toward(goal, speed * delta)


func _is_climbable(cell: Vector2i) -> bool:
	return stats.climbable_terrains.has(_grid.get_terrain(cell))


## Fills _near_positions / _near_velocities with allies inside the separation radius.
func _gather_neighbours() -> void:
	_near_positions.clear()
	_near_velocities.clear()
	var radius_sq: float = stats.separation_radius * stats.separation_radius
	for other: Enemy in _allies:
		if other != self and global_position.distance_squared_to(other.global_position) < radius_sq:
			_near_positions.append(other.global_position)
			_near_velocities.append(other.velocity)


## Called by player bullets (Bullet._on_body_entered).
func take_damage(amount: float) -> void:
	if _dead:
		return
	health -= amount
	queue_redraw()
	_body.color = Color.WHITE
	create_tween().tween_property(_body, "color", stats.color, 0.12)
	if health <= 0.0:
		_die()


func _die() -> void:
	_dead = true
	if _ring != null:
		_ring.disengage(get_instance_id())
	collision_layer = 0
	collision_mask = 0
	set_physics_process(false)
	died.emit(self)
	queue_free()


## Greybox health bar, shown once damaged.
func _draw() -> void:
	if health >= stats.max_health or health <= 0.0:
		return
	var width: float = 12.0
	var top_left: Vector2 = Vector2(-width / 2.0, -10.0)
	draw_rect(Rect2(top_left, Vector2(width, 2)), Color(0.1, 0.1, 0.1))
	draw_rect(Rect2(top_left, Vector2(width * health / stats.max_health, 2)), Color(0.4, 1, 0.4))

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

var _flow_field: FlowField
var _grid: TerrainGrid
var _target: Node2D
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

@onready var _body: Polygon2D = $Body


func _ready() -> void:
	health = stats.max_health
	_body.color = stats.color
	_normal_mask = collision_mask
	_world_mask = collision_mask & 1  # feelers and climbing only care about the world layer
	_weights.seek = stats.seek_weight
	_weights.separation = stats.separation_weight
	_weights.wall_avoidance = stats.wall_avoidance_weight


## Called by the spawner before the enemy starts moving.
func setup(flow_field: FlowField, target: Node2D, allies: Array[Enemy]) -> void:
	_flow_field = flow_field
	_grid = flow_field.grid
	_target = target
	_allies = allies


func _physics_process(delta: float) -> void:
	if _flow_field == null or not _flow_field.is_built():
		return
	var cell: Vector2i = _grid.coords.world_to_cell(global_position)
	var next: Vector2i = _flow_field.get_next_cell(cell)
	if is_climbing or _is_climbable(next):
		_climb(cell, next, delta)
		return

	# Gather the context, let ContextSteering decide, then move.
	var seek_velocity: Vector2
	if _flow_field.get_cost(cell) <= stats.close_in_cost:
		# Next to the player: close in directly and slow down instead of piling onto them.
		seek_velocity = ContextSteering.arrive(_target.global_position - global_position, stats.move_speed, stats.arrive_radius)
	else:
		seek_velocity = ContextSteering.seek(ContextSteering.sample_flow(_flow_field, global_position), stats.move_speed)
	_gather_neighbours()
	if _flow_field.get_cost(cell) <= stats.crowd_cost:
		# Near the player a crowd forms: wait behind slower allies instead of shoving them.
		seek_velocity *= ContextSteering.queue_factor(global_position, seek_velocity, _near_positions, _near_velocities,
				stats.separation_radius, stats.queue_lane_width)
	var separation_push: Vector2 = ContextSteering.separation(global_position, _near_positions, stats.separation_radius)
	var heading: Vector2 = velocity if velocity.length() > 5.0 else seek_velocity
	var wall_push: Vector2 = _wall_push(heading)
	var desired: Vector2 = ContextSteering.combine(seek_velocity, separation_push, wall_push, _weights, stats.move_speed)
	velocity = ContextSteering.smooth_velocity(velocity, desired, stats.acceleration, delta,
			stats.dead_zone_speed, deg_to_rad(stats.max_turn_rate_degrees), stats.turn_limit_min_speed)
	move_and_slide()


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

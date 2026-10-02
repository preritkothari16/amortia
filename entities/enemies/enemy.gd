class_name Enemy
extends CharacterBody2D
## Thin enemy shell: physics, collision, health and greybox visuals.
## Where to go comes from the shared FlowField; how to move comes from Steering (res://ai/).
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
var _world_mask: int = 0
var _dead: bool = false

@onready var _body: Polygon2D = $Body


func _ready() -> void:
	health = stats.max_health
	_body.color = stats.color
	_world_mask = collision_mask


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

	var desired: Vector2
	if cell == _flow_field.target:
		# Same tile as the player: no arrow here, head straight for them.
		desired = Steering.arrive(_target.global_position - global_position, stats.move_speed, stats.arrive_radius)
	else:
		desired = Steering.seek(_flow_field.get_direction(cell), stats.move_speed)
	var push: Vector2 = Steering.separation(global_position, _neighbour_positions(), stats.separation_radius)
	desired = Steering.blend(desired, push, stats.separation_weight, stats.move_speed)
	velocity = velocity.move_toward(desired, stats.acceleration * delta)
	move_and_slide()


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
			collision_mask = _world_mask
			return
	var speed: float = stats.move_speed
	if on_climbable:
		speed /= _grid.get_cost(cell, _flow_field.profile)
	velocity = global_position.direction_to(goal) * speed
	global_position = global_position.move_toward(goal, speed * delta)


func _is_climbable(cell: Vector2i) -> bool:
	return stats.climbable_terrains.has(_grid.get_terrain(cell))


func _neighbour_positions() -> PackedVector2Array:
	var result: PackedVector2Array = PackedVector2Array()
	var radius_sq: float = stats.separation_radius * stats.separation_radius
	for other: Enemy in _allies:
		if other != self and global_position.distance_squared_to(other.global_position) < radius_sq:
			result.append(other.global_position)
	return result


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

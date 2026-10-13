class_name Bullet
extends Area2D
## Greybox projectile: flies straight, dies on first body hit or when its lifetime runs out.

var _velocity: Vector2 = Vector2.ZERO
var _damage: float = 0.0
var _time_left: float = 0.0
## Guards against hitting two bodies in the same physics frame.
var _spent: bool = false


func setup(direction: Vector2, speed: float, damage: float, lifetime: float) -> void:
	_velocity = direction * speed
	_damage = damage
	_time_left = lifetime
	rotation = direction.angle()


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	position += _velocity * delta
	_time_left -= delta
	if _time_left <= 0.0:
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if _spent:
		return
	_spent = true
	# Enemies (and anything else with take_damage) get hurt; tiles report the hit so
	# destructible ones (fences, barricades, doors) can break.
	if body.has_method("take_damage"):
		body.take_damage(_damage)
	elif body is TileMapLayer:
		EventBus.terrain_hit.emit(global_position + _velocity.normalized() * 4.0, _damage)
	queue_free()

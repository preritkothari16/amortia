class_name Nest
extends StaticBody2D
## A Bloom nest (Purge objective): sits on the enemies' physics layer so player bullets hit it,
## has HP, and spawns a straggler every spawn_interval while it lives. Greybox blob.

signal destroyed(nest: Nest)

var max_health: float = 120.0
var health: float = 120.0
var spawn_interval: float = 8.0
var wave_manager: WaveManager
var _spawn_left: float = 0.0
var _body: Polygon2D


func _ready() -> void:
	collision_layer = 4  # enemies layer: bullets (mask world + enemies) hit it
	collision_mask = 0
	var shape: CollisionShape2D = CollisionShape2D.new()
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = 7.0
	shape.shape = circle
	add_child(shape)
	_body = Polygon2D.new()
	var points: PackedVector2Array = PackedVector2Array()
	for i: int in 10:
		var r: float = 7.0 if i % 2 == 0 else 5.0
		points.append(Vector2.from_angle(TAU * i / 10.0) * r)
	_body.polygon = points
	_body.color = Color(0.75, 0.2, 0.45)
	add_child(_body)
	_spawn_left = spawn_interval


func _physics_process(delta: float) -> void:
	if health <= 0.0 or wave_manager == null or wave_manager.is_arriving():
		return
	_spawn_left -= delta
	if _spawn_left <= 0.0:
		_spawn_left = spawn_interval
		wave_manager.spawn_straggler(global_position + Vector2(10, 0))


## Player bullets.
func take_damage(amount: float) -> void:
	if health <= 0.0:
		return
	health -= amount
	_body.color = Color.WHITE
	create_tween().tween_property(_body, "color", Color(0.75, 0.2, 0.45), 0.12)
	queue_redraw()
	if health <= 0.0:
		destroyed.emit(self)
		queue_free()


func _draw() -> void:
	if health < max_health:
		draw_rect(Rect2(Vector2(-7, -11), Vector2(14 * health / max_health, 2)), Color(0.4, 1, 0.4))

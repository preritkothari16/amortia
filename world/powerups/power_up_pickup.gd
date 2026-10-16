class_name PowerUpPickup
extends Area2D
## A power-up lying on the map: a coloured diamond with a letter. Walking over it applies the effect
## (through the PowerUpManager, which enforces the limits). Disappears after its lifetime and blinks
## at the end.

var type: PowerUpType
var manager: Node
var life_left: float = 20.0
var _body: Polygon2D


static func create(power_up: PowerUpType, owner_manager: Node, at: Vector2, lifetime: float) -> PowerUpPickup:
	var p: PowerUpPickup = PowerUpPickup.new()
	p.type = power_up
	p.manager = owner_manager
	p.global_position = at
	p.life_left = lifetime
	return p


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2  # player
	var shape: CollisionShape2D = CollisionShape2D.new()
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = 7.0
	shape.shape = circle
	add_child(shape)
	_body = Polygon2D.new()
	_body.polygon = PackedVector2Array([Vector2(0, -6), Vector2(6, 0), Vector2(0, 6), Vector2(-6, 0)])
	_body.color = type.color
	add_child(_body)
	var label: Label = Label.new()
	label.text = type.symbol
	label.position = Vector2(-5, -6)
	label.add_theme_font_size_override("font_size", 8)
	label.add_theme_color_override("font_color", Color.BLACK)
	add_child(label)
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	life_left -= delta
	if life_left <= 0.0:
		queue_free()
	elif life_left < 5.0:
		_body.visible = int(life_left * 6.0) % 2 == 0  # blink: about to vanish


func _on_body_entered(body: Node2D) -> void:
	if body is Player and manager != null and manager.collect(type, body):
		queue_free()

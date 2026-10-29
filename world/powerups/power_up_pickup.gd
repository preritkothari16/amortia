class_name PowerUpPickup
extends Area2D
## A power-up lying on the map: its pixel-art token (PowerUpArt, the same icon the HUD shows) on a
## soft ground shadow, ringed by a thin outline in the power-up's colour that pulses slowly so it
## stands out from the terrain. Walking over it applies the effect (through the PowerUpManager,
## which enforces the limits). Disappears after its lifetime and blinks at the end.

const PULSE_SECONDS: float = 1.4

static var _ring: Array[Vector2i] = []

var type: PowerUpType
var manager: Node
var life_left: float = 20.0
var _body: Node2D
var _time: float = 0.0


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
	_body = Node2D.new()
	_body.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_body.draw.connect(_draw_body)
	add_child(_body)
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_time += delta
	_body.queue_redraw()


func _physics_process(delta: float) -> void:
	life_left -= delta
	if life_left <= 0.0:
		queue_free()
	elif life_left < 5.0:
		_body.visible = int(life_left * 6.0) % 2 == 0  # blink: about to vanish


## Shadow, pulsing outline ring, token. Whole-pixel positions (the token is 15 px, centred on 0,0).
func _draw_body() -> void:
	var half: float = PowerUpArt.TOKEN_SIZE / 2.0
	_body.draw_rect(Rect2(-6, 6, 13, 2), Color(0, 0, 0, 0.35))  # ground shadow
	_body.draw_rect(Rect2(-4, 8, 9, 1), Color(0, 0, 0, 0.2))
	var pulse: float = 0.5 + 0.5 * sin(_time * TAU / PULSE_SECONDS)
	var ring: Color = Color(type.color, 0.35 + 0.45 * pulse)
	for p: Vector2i in _ring_pixels():
		_body.draw_rect(Rect2(p.x, p.y, 1, 1), ring)
	var tex: Texture2D = PowerUpArt.token(type.id)
	if tex != null:
		_body.draw_texture(tex, Vector2(-floorf(half), -floorf(half)))
	else:  # a type without art: its colour on the plate
		_body.draw_rect(Rect2(-4, -4, 9, 9), type.color)


## Pixels of a circle of radius 8.5 round the token's centre (the token covers radius 7.3). Cached.
static func _ring_pixels() -> Array[Vector2i]:
	if _ring.is_empty():
		for y: int in range(-9, 10):
			for x: int in range(-9, 10):
				var d: float = Vector2(x, y).length()
				if d > 7.9 and d <= 8.9:
					_ring.append(Vector2i(x, y))
	return _ring


func _on_body_entered(body: Node2D) -> void:
	if body is Player and manager != null and manager.collect(type, body):
		queue_free()

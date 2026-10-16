class_name Pickup
extends Area2D
## Greybox pickup (GDD 7.5 samples, 7.6 scrap; Extract supplies): a small diamond the player
## collects by walking over it. Built in code, no scene. Collected -> GameState + EventBus.

const COLORS: Dictionary = {
	&"sample": Color(0.55, 1.0, 0.6), &"scrap": Color(0.75, 0.75, 0.8), &"supply": Color(0.4, 0.8, 1.0),
	&"blueprint": Color(1.0, 0.85, 0.3),
}

var kind: StringName = &"scrap"
var amount: int = 1
## Which weapon a blueprint pickup is for ("shotgun").
var tag: StringName = &""


static func create(pickup_kind: StringName, pickup_amount: int, at: Vector2) -> Pickup:
	var p: Pickup = Pickup.new()
	p.kind = pickup_kind
	p.amount = pickup_amount
	p.global_position = at
	return p


## A blueprint for weapon `weapon_id` lying at `at`.
static func create_blueprint(weapon_id: StringName, at: Vector2) -> Pickup:
	var p: Pickup = Pickup.create(&"blueprint", 1, at)
	p.tag = weapon_id
	return p


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2  # player
	var shape: CollisionShape2D = CollisionShape2D.new()
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = 6.0
	shape.shape = circle
	add_child(shape)
	var body: Polygon2D = Polygon2D.new()
	var r: float = 5.0 if kind == &"blueprint" else (4.0 if kind == &"supply" else 3.0)
	body.polygon = PackedVector2Array([Vector2(0, -r), Vector2(r, 0), Vector2(0, r), Vector2(-r, 0)])
	body.color = COLORS.get(kind, Color.WHITE)
	add_child(body)
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if not body is Player:
		return
	if kind == &"blueprint":
		GameState.collect_blueprint(tag)
	else:
		GameState.add_pickup(kind, amount)
	EventBus.pickup_collected.emit(kind, amount, global_position)
	queue_free()

class_name AttackRingOverlay
extends Node2D
## Debug view of the AttackRing. Toggle with F4.
## Slots: grey circle = free, red X = unusable (wall / behind a fence), green = held,
## orange = held by an attacker (with its attack point). Lines join enemies to their slot.
## Dashed outer circle = waiting ring; small blue dots = enemies waiting there.

var ring: AttackRing


func _ready() -> void:
	visible = false
	z_index = 12


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_attack_ring"):
		visible = not visible


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func _draw() -> void:
	if ring == null:
		return
	var s: AttackRingSettings = ring.settings
	draw_arc(ring.center, s.wait_radius, 0.0, TAU, 48, Color(0.5, 0.7, 1, 0.35), 1.0)
	for i: int in s.slot_count:
		var pos: Vector2 = ring.slot_position(i)
		var owner: int = ring.get_slot_owner(i)
		if not ring.is_slot_valid(i):
			draw_line(pos + Vector2(-3, -3), pos + Vector2(3, 3), Color.RED)
			draw_line(pos + Vector2(3, -3), pos + Vector2(-3, 3), Color.RED)
			continue
		if owner == AttackRing.FREE:
			draw_arc(pos, 3.0, 0.0, TAU, 12, Color(0.8, 0.8, 0.8, 0.8), 1.0)
			continue
		var attacking: bool = ring.get_role(owner) == AttackRing.Role.ATTACKING
		var color: Color = Color(1, 0.6, 0.1) if attacking else Color(0.3, 1, 0.4)
		draw_circle(pos, 3.0, color)
		draw_line(ring.get_member_position(owner), pos, Color(color, 0.6))
		if attacking:
			draw_circle(ring.get_target(owner), 2.0, color)
	for id: int in ring.get_member_ids():
		if ring.get_role(id) == AttackRing.Role.WAITING:
			draw_circle(ring.get_member_position(id), 1.5, Color(0.5, 0.7, 1))

class_name ButtonFx
extends Control
## Hover / focus motion of a menu button (MenuStyle.decorate): a "heat" value eases towards 1
## while the button is hovered or focused and back to 0 after. It widens and lights the
## blood bar on the left, slides a small chevron in beside it and lays a faint red glow over
## the plate. Drawn by a child that ignores the mouse, so the button's own input and layout are
## untouched. Pressing flashes it briefly.

const EASE_SECONDS: float = 0.12

var heat: float = 0.0
var _flash: float = 0.0
var _target: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var b: BaseButton = get_parent() as BaseButton
	b.mouse_entered.connect(_update)
	b.mouse_exited.connect(_update)
	b.focus_entered.connect(_update)
	b.focus_exited.connect(_update)
	b.button_down.connect(func() -> void: _flash = 1.0)
	b.visibility_changed.connect(_update)
	_update()


func _update() -> void:
	var b: BaseButton = get_parent() as BaseButton
	if b == null:
		return
	var hovered: bool = b.is_hovered() and not b.disabled
	_target = 1.0 if (hovered or b.has_focus()) and not b.disabled else 0.0
	set_process(true)


func _process(delta: float) -> void:
	var step: float = delta / EASE_SECONDS
	heat = move_toward(heat, _target, step)
	_flash = maxf(_flash - delta * 5.0, 0.0)
	queue_redraw()
	if heat == _target and _flash == 0.0:
		set_process(false)


func _draw() -> void:
	var b: BaseButton = get_parent() as BaseButton
	if b == null or b.disabled:
		return
	var h: float = heat
	var s: Vector2 = size
	if h > 0.0:
		draw_rect(Rect2(Vector2(2, 1), Vector2(s.x - 3, s.y - 2)), Color(MenuStyle.CRIMSON, 0.1 * h + 0.25 * _flash))
		draw_rect(Rect2(Vector2(0, 0), Vector2(2 + roundf(2.0 * h), s.y)), Color(MenuStyle.RUST.lerp(MenuStyle.EMBER, h), 0.4 + 0.6 * h))
		var cx: float = roundf(4.0 + 2.0 * h)
		var cy: float = roundf(s.y / 2.0)
		var c: Color = Color(MenuStyle.EMBER, h)
		for i: int in 3:  # small pixel chevron
			draw_rect(Rect2(cx + i, cy - 2 + i, 1, 1), c)
			draw_rect(Rect2(cx + i, cy + 2 - i, 1, 1), c)
	# Worn edge: a few nicks along the bottom rim, the same every time for this button.
	var seed_value: int = hash(b.name)
	for i: int in 3:
		var x: float = float(absi(seed_value >> (i * 7)) % maxi(int(s.x) - 8, 1)) + 4.0
		draw_rect(Rect2(x, s.y - 1, 2, 1), Color(0, 0, 0, 0.55))

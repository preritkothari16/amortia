class_name UiBar
extends Control
## Thin horizontal bar (greybox UI): a track, a fill 0..1 and an optional marker (e.g. the
## value before a change). Colours come from the theme's "Palette" type, by name.

## Fill, 0..1. Tween it for the fill animation.
@export_range(0.0, 1.0) var value: float = 0.0:
	set(v):
		value = clampf(v, 0.0, 1.0)
		queue_redraw()
## Marker position 0..1; < 0 = no marker.
var marker: float = -1.0:
	set(v):
		marker = v
		queue_redraw()
## Palette colour name of the fill.
var fill_color: StringName = &"accent":
	set(v):
		fill_color = v
		queue_redraw()


func _init() -> void:
	custom_minimum_size = Vector2(16, 4)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_PASS


func _draw() -> void:
	var r: Rect2 = Rect2(Vector2.ZERO, size)
	draw_rect(r, get_theme_color(&"raised", &"Palette"))
	if value > 0.0:
		draw_rect(Rect2(r.position, Vector2(r.size.x * value, r.size.y)), get_theme_color(fill_color, &"Palette"))
	if marker >= 0.0:
		var x: float = clampf(roundf(r.size.x * marker), 0.0, r.size.x - 1.0)
		draw_rect(Rect2(x, -1.0, 1.0, r.size.y + 2.0), get_theme_color(&"text", &"Palette"))

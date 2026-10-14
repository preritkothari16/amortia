class_name SegmentBar
extends Control
## Bar split into segments by share (e.g. how many enemies use each route strategy).
## `reveal` 0..1 grows the bar from the left (tween it).

var shares: Array[float] = []:
	set(v):
		shares = v
		queue_redraw()
## Segment colours, same order as shares.
var colors: Array[Color] = []:
	set(v):
		colors = v
		queue_redraw()
var reveal: float = 1.0:
	set(v):
		reveal = clampf(v, 0.0, 1.0)
		queue_redraw()


func _init() -> void:
	custom_minimum_size = Vector2(16, 6)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), get_theme_color(&"raised", &"Palette"))
	var total: float = 0.0
	for s: float in shares:
		total += s
	if total <= 0.0:
		return
	var width: float = size.x * reveal
	var x: float = 0.0
	for i: int in shares.size():
		var w: float = size.x * shares[i] / total
		var visible_w: float = clampf(width - x, 0.0, w)
		if visible_w > 0.0:
			draw_rect(Rect2(x, 0.0, visible_w, size.y), colors[i] if i < colors.size() else Color.WHITE)
		x += w

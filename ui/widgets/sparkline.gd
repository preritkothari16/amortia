class_name Sparkline
extends Control
## Tiny line chart of one or two series on a shared 0..1 scale (e.g. best and average fitness
## per wave). `reveal` 0..1 draws it from the left (tween it).

## Each series: {"values": Array[float], "color": StringName (Palette name)}.
var series: Array[Dictionary] = []:
	set(v):
		series = v
		queue_redraw()
var reveal: float = 1.0:
	set(v):
		reveal = clampf(v, 0.0, 1.0)
		queue_redraw()


func _init() -> void:
	custom_minimum_size = Vector2(40, 18)


func _draw() -> void:
	var r: Rect2 = Rect2(Vector2.ZERO, size)
	draw_line(Vector2(0, r.size.y - 0.5), Vector2(r.size.x, r.size.y - 0.5), get_theme_color(&"raised", &"Palette"))
	var peak: float = 0.0
	for s: Dictionary in series:
		for v: float in s["values"]:
			peak = maxf(peak, v)
	var top: float = maxf(peak, 0.05)
	for s: Dictionary in series:
		var values: Array = s["values"]
		var color: Color = get_theme_color(s["color"], &"Palette")
		if values.size() == 1:
			draw_circle(Vector2(1.5, _y(values[0], top, r)), 1.5, color)
			continue
		var points: PackedVector2Array = PackedVector2Array()
		var last: int = values.size() - 1
		for i: int in values.size():
			var t: float = float(i) / last
			if t > reveal + 0.0001:
				break
			points.append(Vector2(1.0 + t * (r.size.x - 2.0), _y(values[i], top, r)))
		if points.size() >= 2:
			draw_polyline(points, color, 1.0)
		if points.size() == values.size():
			draw_circle(points[-1], 1.5, color)


func _y(v: float, top: float, r: Rect2) -> float:
	return 1.5 + (1.0 - v / top) * (r.size.y - 3.0)

class_name GroundShadow
extends Node2D
## Pixel ellipse shadow on the ground (visual only), drawn row by row on the world-px grid.

@export var radius: Vector2 = Vector2(6, 2.5)
@export var colour: Color = Color(0, 0, 0, 0.38)


func _draw() -> void:
	var ry: int = maxi(1, roundi(radius.y))
	for y: int in range(-ry, ry + 1):
		var half: float = radius.x * sqrt(maxf(0.0, 1.0 - pow(float(y) / (radius.y + 0.5), 2.0)))
		var w: int = roundi(half)
		if w > 0:
			# Inner rows full strength, outer rows lighter: a soft edge without blur.
			var edge: float = 1.0 - absf(float(y)) / float(ry + 1)
			draw_rect(Rect2(-w, y, w * 2, 1), Color(colour, colour.a * (0.55 + 0.45 * edge)))
			if w > 2:
				draw_rect(Rect2(-w + 1, y, w * 2 - 2, 1), Color(colour, colour.a * 0.35 * edge))

class_name RuleLine
extends Control
## A thin blood-red rule that fades out at both ends, with a bright notch in the middle (under
## headings). Fills its rect.

@export var colour: Color = MenuStyle.CRIMSON


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var w: int = int(size.x)
	var y: float = floorf(size.y / 2.0)
	for x: int in w:
		var t: float = 1.0 - absf(float(x) / maxf(w - 1, 1) * 2.0 - 1.0)
		draw_rect(Rect2(x, y, 1, 1), Color(colour, clampf(t * 1.6, 0.0, 1.0)))
	var mid: float = floorf(w / 2.0)
	draw_rect(Rect2(mid - 3, y - 1, 6, 1), Color(MenuStyle.EMBER, 0.8))
	draw_rect(Rect2(mid - 1, y - 1, 2, 3), Color(MenuStyle.EMBER, 0.9))

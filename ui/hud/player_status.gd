class_name PlayerStatus
extends Control
## Greybox player panel, bottom-left above the XP bar: HP bar and dodge cooldown.
## Ammo is not shown because weapons have no ammo yet.

const FONT_SIZE: int = 8
const BAR_SIZE: Vector2 = Vector2(70, 5)
const DODGE_SIZE: Vector2 = Vector2(36, 5)
const MARGIN: float = 4.0
## Distance from the bottom edge, leaving room for the XP bar and its text.
const BOTTOM_OFFSET: float = 22.0
const COLOR_BACK: Color = Color(0, 0, 0, 0.6)
const COLOR_HP: Color = Color(0.85, 0.25, 0.25)
const COLOR_DODGE_READY: Color = Color(0.5, 0.9, 0.5)
const COLOR_DODGE_WAIT: Color = Color(0.55, 0.55, 0.55)

var player: Player


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if player == null or player.stats == null:
		return
	var font: Font = ThemeDB.fallback_font
	var y: float = size.y - BOTTOM_OFFSET
	var x: float = MARGIN

	# HP: label, bar, numbers.
	x = _text(font, Vector2(x, y), "HP", Color.WHITE) + 3.0
	var hp_ratio: float = clampf(player.health / player.stats.max_health, 0.0, 1.0)
	_bar(Rect2(x, y - BAR_SIZE.y, BAR_SIZE.x, BAR_SIZE.y), hp_ratio, COLOR_HP)
	x += BAR_SIZE.x + 3.0
	x = _text(font, Vector2(x, y), "%d/%d" % [ceili(player.health), roundi(player.stats.max_health)], Color.WHITE)

	# Dodge: fills up while cooling down, green when ready.
	x += 10.0
	x = _text(font, Vector2(x, y), "DODGE", Color.WHITE) + 3.0
	var left: float = player.dodge_cooldown_left
	var is_ready: bool = left <= 0.0
	var ratio: float = 1.0 if is_ready else 1.0 - left / player.stats.dodge_cooldown
	_bar(Rect2(x, y - DODGE_SIZE.y, DODGE_SIZE.x, DODGE_SIZE.y), ratio,
		COLOR_DODGE_READY if is_ready else COLOR_DODGE_WAIT)
	x += DODGE_SIZE.x + 3.0
	_text(font, Vector2(x, y), "ready" if is_ready else "%.1f s" % left,
		COLOR_DODGE_READY if is_ready else COLOR_DODGE_WAIT)


func _bar(rect: Rect2, ratio: float, color: Color) -> void:
	draw_rect(rect.grow(1.0), COLOR_BACK)
	draw_rect(Rect2(rect.position, Vector2(rect.size.x * ratio, rect.size.y)), color)


## Draws outlined text with its baseline at `pos`; returns the x where it ends.
func _text(font: Font, pos: Vector2, text: String, color: Color) -> float:
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, FONT_SIZE, 2, Color.BLACK)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, FONT_SIZE, color)
	return pos.x + font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, FONT_SIZE).x

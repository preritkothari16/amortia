class_name XpBar
extends Control
## Greybox XP bar along the bottom of the screen (GDD 9.1): level, XP towards the next
## level, unspent skill points, and a short "LEVEL UP" flash.

const BAR_HEIGHT: float = 4.0
const MARGIN: float = 4.0
const FONT_SIZE: int = 8
const COLOR_BACK: Color = Color(0, 0, 0, 0.6)
const COLOR_FILL: Color = Color(0.45, 0.8, 1.0)
const COLOR_FLASH: Color = Color(1.0, 0.9, 0.4)
const FLASH_SECONDS: float = 1.5

var progression: PlayerProgression:
	set(value):
		progression = value
		progression.xp_changed.connect(queue_redraw)
		progression.leveled_up.connect(_on_leveled_up)
		queue_redraw()

var _flash_left: float = 0.0


func _process(delta: float) -> void:
	if _flash_left > 0.0:
		_flash_left = maxf(_flash_left - delta, 0.0)
		queue_redraw()


func _on_leveled_up(_new_level: int) -> void:
	_flash_left = FLASH_SECONDS


func _draw() -> void:
	if progression == null:
		return
	var p: PlayerProgression = progression
	var font: Font = ThemeDB.fallback_font
	var bar: Rect2 = Rect2(MARGIN, size.y - MARGIN - BAR_HEIGHT, size.x - 2.0 * MARGIN, BAR_HEIGHT)
	var flashing: bool = _flash_left > 0.0
	draw_rect(bar.grow(1.0), COLOR_BACK)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * p.progress(), bar.size.y)),
		COLOR_FLASH if flashing else COLOR_FILL)

	var xp_text: String = "MAX" if p.is_max_level() else "%d / %d XP" % [p.xp, p.xp_to_next()]
	var text: String = "Lv %d   %s" % [p.level, xp_text]
	if flashing:
		text += "   LEVEL UP!"
	var baseline: Vector2 = Vector2(MARGIN, bar.position.y - 3.0)
	draw_string_outline(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, FONT_SIZE, 2, Color.BLACK)
	draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, FONT_SIZE,
		COLOR_FLASH if flashing else Color.WHITE)

	# Unspent points: right-aligned, yellow, with the key, so the skill tree is discoverable.
	if p.skill_points > 0:
		var hint: String = "%d skill point%s  -  press K" % [p.skill_points, "" if p.skill_points == 1 else "s"]
		var hint_pos: Vector2 = Vector2(MARGIN, baseline.y)
		var width: float = size.x - 2.0 * MARGIN
		draw_string_outline(font, hint_pos, hint, HORIZONTAL_ALIGNMENT_RIGHT, width, FONT_SIZE, 2, Color.BLACK)
		draw_string(font, hint_pos, hint, HORIZONTAL_ALIGNMENT_RIGHT, width, FONT_SIZE, COLOR_FLASH)

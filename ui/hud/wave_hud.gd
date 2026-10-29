class_name WaveHud
extends Control
## Bottom HUD strip (GDD 9.1, step 71). Draws the strip's band (PlayerStatus sits on it): layered dark
## navy with a soft shadow fading up into the world, a steel hairline on top, faint dividers between
## the three groups - no boxes. And its right group:
##   wave block: "WAVE  GEN g", the big wave number (campaign: n / waves of the level), skull + how
##   many Bloomed are left / incoming (+ the wave timer in the prototype loop)
##   objective checklist, 3 rows: square marker - empty = to do, ticked = done, red cross = can no
##   longer be met; dots mark timers / hints, "!" terrain-event warnings
## Feedback: the wave number flares when the wave changes, a row that gets ticked glows green, one
## that fails glows red.
## The dominant traits of the Runners in play sit in a small plate at the top right, so evolution
## stays visible mid-wave. Detailed gene numbers stay in the Wave Report and the F7 overlay.
## A checklist row too long for the column moves to its own line above the strip, on a plate that
## only covers the right side it needs (up to HudLayout.MAX_OVERFLOW_LINES); ellipsis as last resort.
## Text uses MenuStyle's crisp fonts.

const FONT_SIZE: int = 8
const SMALL_FONT_SIZE: int = 7
const TINY_FONT_SIZE: int = 6
## Checklist rows (right column and overflow lines).
const ROW_FONT_SIZE: int = 7
const WAVE_FONT_SIZE: int = 12
const COLOR_BAND: Color = Color(0.03, 0.045, 0.065, 0.93)
const COLOR_EDGE: Color = Color(0.36, 0.38, 0.42, 0.55)
const COLOR_HEAD: Color = MenuStyle.BONE
const COLOR_TEXT: Color = Color(0.78, 0.76, 0.72)
const COLOR_DIM: Color = Color(0.5, 0.5, 0.52)
const COLOR_DONE: Color = Color(0.56, 0.82, 0.56)
const COLOR_FAILED: Color = Color(0.9, 0.32, 0.28)
const COLOR_ALERT: Color = Color(0.95, 0.72, 0.36)
const COLOR_TRAITS_HEAD: Color = Color(0.86, 0.36, 0.36)
const COLOR_TRAITS: Color = Color(0.95, 0.86, 0.62)
const TRAITS_HEAD: String = "BLOOMED TRAITS"
const SKULL: Texture2D = preload("res://ui/hud/art/icon_skull.png")
const FLARE_SECONDS: float = 1.2
const ROW_FLASH_SECONDS: float = 0.9

var wave_manager: WaveManager
## Campaign: the area sequencer supplies the wave count and the checklist (null in the prototype).
var level_flow: LevelFlow
## Optional: terrain event messages ("Night falls in 5 s").
var terrain_events: TerrainEvents

## WAVE block parts: the label line ("WAVE  GEN 2"), the number ("1", "1 / 3"), the Bloomed line.
var _label: String = ""
var _number: String = ""
var _sub: String = ""
var _traits: String = ""
## Rows shown in the right column and on the overflow lines: {text, mark}.
var _column: Array[Dictionary] = []
var _overflow: Array[Dictionary] = []
var _flare: float = 0.0
## Row text -> its last mark, and rows glowing after a change: text -> [seconds left, mark].
var _marks: Dictionary = {}
var _row_flash: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS  # keep the status right while the report pauses


func _process(delta: float) -> void:
	_flare = maxf(_flare - delta, 0.0)
	for key: String in _row_flash.keys():
		_row_flash[key][0] -= delta
		if _row_flash[key][0] <= 0.0:
			_row_flash.erase(key)
	if wave_manager == null:
		queue_redraw()
		return
	var wm: WaveManager = wave_manager
	var traits: String = "-"
	if not wm.population.is_empty() and wm.population[0] != null:
		traits = WaveReport.dominant_traits(WaveManager.gene_means(wm.population), false)
	var head: String = "WAVE %d" % wm.wave_number
	if level_flow != null:
		head = "WAVE %d / %d" % [level_flow.wave_in_level(), level_flow.config.waves]
	show_rows(head, "GEN %d" % wm.generation, _sub_line(wm), checklist(wm), traits)


## Lays out the strip: wave block and checklist rows in the right column; rows too wide for the
## column go to overflow lines above the strip. `head` is "WAVE n" or "WAVE n / m".
func show_rows(head: String, generation: String, sub: String, rows: Array[Dictionary], traits: String) -> void:
	var number: String = head.trim_prefix("WAVE").strip_edges()
	if _number != "" and number != _number:
		_flare = FLARE_SECONDS  # a new wave: the number flares
	_number = number
	_label = "WAVE  " + generation
	_sub = sub
	_traits = traits
	for row: Dictionary in rows:
		var text: String = row["text"]
		var mark: String = row["mark"]
		var before: String = _marks.get(text, "")
		if before != "" and before != mark and (mark == "done" or mark == "failed"):
			_row_flash[text] = [ROW_FLASH_SECONDS, mark]
		_marks[text] = mark
	if _marks.size() > 64:  # timers change their text every frame: keep only what is shown
		var keep: Dictionary = {}
		for row: Dictionary in rows:
			keep[row["text"]] = row["mark"]
		_marks = keep
	_column.clear()
	_overflow.clear()
	var column_width: float = HudLayout.check_text_width(_screen_width())
	for row: Dictionary in rows:
		var fits: bool = _width(row["text"], ROW_FONT_SIZE) <= column_width
		if fits and _column.size() < HudLayout.CHECK_BASELINE.size():
			_column.append(row)
		elif _overflow.size() < HudLayout.MAX_OVERFLOW_LINES:
			_overflow.append(row)
		elif _column.size() < HudLayout.CHECK_BASELINE.size():
			_column.append(row)  # last resort: shown shortened with an ellipsis
	queue_redraw()


## Number of objective lines above the strip (0 when everything fits the column).
func overflow_lines() -> int:
	return _overflow.size()


## Rows currently in the right column / on the overflow lines (for tests).
func column_rows() -> Array[Dictionary]:
	return _column


func overflow_rows() -> Array[Dictionary]:
	return _overflow


## Top of the HUD, including overflow lines, in this control's coordinates.
func plate_top() -> float:
	return size.y - HudLayout.STRIP_HEIGHT - HudLayout.OVERFLOW_LINE * _overflow.size()


## Left edge of the overflow plate: it only reaches as far left as its longest line needs.
func overflow_left() -> float:
	var widest: float = 0.0
	for row: Dictionary in _overflow:
		widest = maxf(widest, _width(row["text"], ROW_FONT_SIZE))
	return maxf(0.0, _screen_width() - widest - HudLayout.CHECK_TEXT_INDENT - 12.0)


## What the player should be doing right now, as checklist rows.
func checklist(wm: WaveManager) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if wm.failed:
		rows.append({"text": "You were downed - retry the wave", "mark": "failed"})
	elif level_flow != null:
		rows.append_array(level_flow.checklist())
	elif wm.waiting_for_continue:
		rows.append({"text": "Survive and clear the wave", "mark": "done"})
		rows.append({"text": "Read the report, then Continue", "mark": "todo"})
	elif wm.intermission_left >= 0.0:
		rows.append({"text": "Next wave in %.1f s" % wm.intermission_left, "mark": "info"})
	else:
		rows.append({"text": "Survive and clear the wave", "mark": "todo"})
	var event_text: String = terrain_events.status_text() if terrain_events != null else ""
	if event_text != "":
		rows.insert(mini(1, rows.size()), {"text": event_text, "mark": "alert"})
	return rows


## Bloomed line under the wave number: how many are left (or incoming), the prototype's wave timer.
func _sub_line(wm: WaveManager) -> String:
	if wm.is_arriving():
		return "%d incoming" % wm.population.size()
	var text: String = "%d left" % wm.alive.size()
	if level_flow == null and wm.is_wave_running():
		var seconds: int = int(wm.wave_seconds)
		text += "  %d:%02d" % [seconds / 60, seconds % 60]
	return text


func _draw() -> void:
	var font: Font = MenuStyle.body_font()
	var w: float = size.x
	var strip_top: float = size.y - HudLayout.STRIP_HEIGHT
	_band(Rect2(0, strip_top, w, HudLayout.STRIP_HEIGHT))
	if not _overflow.is_empty():
		var left: float = overflow_left()
		var top: float = plate_top()
		_band(Rect2(left, top, w - left, strip_top - top + 1.0))
		for i: int in _overflow.size():
			var y: float = top + HudLayout.OVERFLOW_LINE * (i + 1) - 1.0
			_row(font, Vector2(left + 6.0, y), _overflow[i], w - left - 10.0)
	for i: int in HudLayout.DIVIDERS.size():  # separate the groups: fading vertical hairlines
		var x: float = HudLayout.DIVIDERS[i]
		var span: float = HudLayout.STRIP_HEIGHT - (8.0 if i == 1 else 6.0)
		for k: int in int(span):
			var t: float = 1.0 - absf(float(k) / span * 2.0 - 1.0)
			draw_rect(Rect2(x, strip_top + (HudLayout.STRIP_HEIGHT - span) * 0.5 + k, 1, 1), Color(0.6, 0.62, 0.66, 0.16 * t))

	# Wave block: label line, the big number, the Bloomed line.
	var x0: float = HudLayout.RIGHT_X
	_text(font, Vector2(x0, strip_top + HudLayout.WAVE_LABEL_BASELINE), _label, COLOR_DIM, TINY_FONT_SIZE)
	var heading: Font = MenuStyle.heading_font()
	var parts: PackedStringArray = _number.split(" / ")
	var flare: float = _flare / FLARE_SECONDS
	var num_colour: Color = COLOR_HEAD.lerp(MenuStyle.EMBER, flare)
	var base: float = strip_top + HudLayout.WAVE_NUMBER_BASELINE
	if flare > 0.0:  # a red glow behind the number while it flares
		draw_rect(Rect2(x0 - 2.0, base - 11.0, 30.0, 13.0), Color(MenuStyle.CRIMSON, 0.3 * flare))
	var end: float = _text(heading, Vector2(x0, base), parts[0], num_colour, WAVE_FONT_SIZE)
	if parts.size() > 1:
		_text(font, Vector2(end + 1.0, base), "/ " + parts[1], COLOR_DIM, SMALL_FONT_SIZE)
	var sub_base: float = strip_top + HudLayout.BLOOMED_BASELINE
	draw_texture_rect(SKULL, Rect2(x0, sub_base - 5.0, 5, 5), false, Color(0.85, 0.8, 0.78))
	_text(font, Vector2(x0 + 7.0, sub_base), _sub, COLOR_TEXT, TINY_FONT_SIZE, HudLayout.CHECK_X - x0 - 9.0)

	var right: float = w - HudLayout.RIGHT_MARGIN
	for i: int in _column.size():
		_row(font, Vector2(HudLayout.CHECK_X, strip_top + HudLayout.CHECK_BASELINE[i]), _column[i], right - HudLayout.CHECK_X)
	_draw_traits(font, w)


## The band: layered dark surface, a soft shadow fading up into the world, a steel hairline on top
## that fades out at both ends.
func _band(r: Rect2) -> void:
	for i: int in int(HudLayout.FADE):
		var a: float = 0.32 * float(i + 1) / (HudLayout.FADE + 1.0)
		draw_rect(Rect2(r.position.x, r.position.y - HudLayout.FADE + i, r.size.x, 1), Color(0, 0, 0, a))
	draw_rect(r, COLOR_BAND)
	draw_rect(Rect2(r.position.x, r.end.y - 7.0, r.size.x, 7.0), Color(0, 0, 0, 0.18))  # darker floor
	var n: int = int(r.size.x)
	for x: int in range(0, n, 2):  # hairline in 2 px steps: cheaper than per pixel, same look
		var t: float = minf(1.0, minf(float(x) / 40.0, float(n - x) / 40.0))
		draw_rect(Rect2(r.position.x + x, r.position.y, 2, 1), Color(COLOR_EDGE, COLOR_EDGE.a * t))
	draw_rect(Rect2(r.position.x, r.position.y + 1, r.size.x, 1), Color(0, 0, 0, 0.45))


## One checklist row: marker, then the text (ellipsis if it is still wider than `width`).
func _row(font: Font, at: Vector2, row: Dictionary, width: float) -> void:
	var box: Rect2 = Rect2(at.x + 1.0, at.y - 5.0, 5, 5)
	var mark: String = row["mark"]
	var colour: Color = COLOR_TEXT
	var text: String = row["text"]
	if _row_flash.has(text):  # just ticked / just failed: a glow behind the row that fades
		var k: float = _row_flash[text][0] / ROW_FLASH_SECONDS
		var glow: Color = COLOR_DONE if _row_flash[text][1] == "done" else COLOR_FAILED
		draw_rect(Rect2(at.x - 1.0, at.y - 7.0, minf(width, _width(text, ROW_FONT_SIZE) + HudLayout.CHECK_TEXT_INDENT + 3.0), 9.0), Color(glow, 0.28 * k))
	match mark:
		"todo", "done", "failed":
			draw_rect(box, Color(0.02, 0.03, 0.04))
			draw_rect(box, Color(0.6, 0.6, 0.62), false, -1.0)
			if mark == "done":
				draw_line(box.position + Vector2(1, 2.5), box.position + Vector2(2.2, 4), COLOR_DONE, -1.0)
				draw_line(box.position + Vector2(2.2, 4), box.position + Vector2(4.2, 1), COLOR_DONE, -1.0)
				colour = COLOR_DIM
			elif mark == "failed":
				draw_line(box.position + Vector2(1, 1), box.end - Vector2(1, 1), COLOR_FAILED, -1.0)
				draw_line(Vector2(box.position.x + 1, box.end.y - 1), Vector2(box.end.x - 1, box.position.y + 1), COLOR_FAILED, -1.0)
				colour = COLOR_FAILED
		"alert":
			_text(font, Vector2(at.x + 2.0, at.y), "!", COLOR_ALERT, ROW_FONT_SIZE)
			colour = COLOR_ALERT
		_:
			draw_rect(Rect2(at.x + 2.0, at.y - 4.0, 2, 2), COLOR_DIM)
	var indent: float = HudLayout.CHECK_TEXT_INDENT
	_text(font, Vector2(at.x + indent, at.y), text, colour, ROW_FONT_SIZE, width - indent)


## BLOOMED TRAITS heading + trait words, right-aligned on a small plate in the top-right corner.
func _draw_traits(font: Font, w: float) -> void:
	var text_w: float = maxf(_width(TRAITS_HEAD, TINY_FONT_SIZE), _width(_traits))
	var plate: Rect2 = Rect2(w - text_w - 12.0, 0, text_w + 12.0, 19)
	draw_rect(plate, COLOR_BAND)
	for x: int in range(0, int(plate.size.x), 2):  # hairline under it, fading out to the left
		var t: float = minf(1.0, float(x) / 30.0)
		draw_rect(Rect2(plate.position.x + x, plate.end.y - 1, 2, 1), Color(COLOR_EDGE, COLOR_EDGE.a * t))
	draw_rect(Rect2(plate.position.x, plate.end.y, plate.size.x, 1), Color(0, 0, 0, 0.3))
	draw_rect(Rect2(w - 3.0, 3, 1, 13), Color(MenuStyle.CRIMSON, 0.8))  # a blood-red accent
	_text(MenuStyle.heading_font(), Vector2(w - 6.0 - _width(TRAITS_HEAD, TINY_FONT_SIZE, MenuStyle.heading_font()), 7),
			TRAITS_HEAD, COLOR_TRAITS_HEAD, TINY_FONT_SIZE)
	_text(font, Vector2(w - 6.0 - _width(_traits), 16), _traits, COLOR_TRAITS)


func _screen_width() -> float:
	return size.x if size.x > 0.0 else 480.0


func _width(text: String, font_size: int = FONT_SIZE, font: Font = null) -> float:
	return (font if font != null else MenuStyle.body_font()).get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x


## Outlined text with its baseline at `pos` (whole pixels); `max_width` > 0 trims it with an
## ellipsis. Returns the x where it ends.
func _text(font: Font, pos: Vector2, text: String, color: Color, font_size: int = FONT_SIZE,
		max_width: float = -1.0) -> float:
	if font_size < 0:
		font_size = FONT_SIZE
	if max_width > 0.0 and _width(text, font_size, font) > max_width:
		while text.length() > 1 and _width(text + "...", font_size, font) > max_width:
			text = text.left(text.length() - 1)
		text = text.strip_edges() + "..."
	pos = pos.round()
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, 2, Color(0.02, 0.025, 0.035, 0.9))
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)
	return pos.x + _width(text, font_size, font)

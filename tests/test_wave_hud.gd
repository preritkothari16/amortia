extends GutTest
## Bottom HUD strip, right column (steps 67-71): checklist rows that don't fit the column move to
## lines above the strip (on a plate only as wide as they need); short rows never overlap anything;
## a newly ticked row and a new wave get a short highlight.

const LONG_TRAITS: String = "patient hunters, short-sighted, pack hunters"

var _hud: WaveHud


func before_each() -> void:
	var root: Control = Control.new()
	root.size = Vector2(480, 270)
	add_child_autofree(root)
	_hud = WaveHud.new()
	root.add_child(_hud)
	_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await wait_process_frames(1)


func _width(text: String) -> float:
	return MenuStyle.body_font().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, WaveHud.ROW_FONT_SIZE).x


func _rows(texts: Array[String]) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for t: String in texts:
		rows.append({"text": t, "mark": "todo"})
	return rows


func test_short_rows_stay_in_the_column() -> void:
	_hud.show_rows("WAVE 1 / 3", "GEN 1", "Bloomed left: 5", _rows(["Clear the wave", "No damage"]), LONG_TRAITS)
	assert_eq(_hud.overflow_lines(), 0)
	assert_eq(_hud.column_rows().size(), 2)
	assert_eq(_hud.plate_top(), 270.0 - HudLayout.STRIP_HEIGHT, "plate is just the strip")


func test_long_stealth_row_moves_above_the_strip() -> void:
	var stealth: String = "Reach the exit unseen   close calls 0 (next 3.0 s)   - something noticed you"
	assert_gt(_width(stealth), HudLayout.check_text_width(480.0), "too wide for the right column")
	_hud.show_rows("WAVE 1 / 2", "GEN 1", "Bloomed left: 9", _rows(["Night falls in 5 s", stealth]), LONG_TRAITS)
	assert_eq(_hud.overflow_lines(), 1, "the long row gets its own line")
	assert_eq(_hud.overflow_rows()[0]["text"], stealth)
	assert_eq(_hud.plate_top(), 270.0 - HudLayout.STRIP_HEIGHT - HudLayout.OVERFLOW_LINE, "plate grows to cover it")
	# Back to short rows: the plate shrinks again.
	_hud.show_rows("WAVE 1 / 2", "GEN 1", "Bloomed left: 9", _rows(["Clear the wave"]), LONG_TRAITS)
	assert_eq(_hud.overflow_lines(), 0)
	assert_eq(_hud.plate_top(), 270.0 - HudLayout.STRIP_HEIGHT)


func test_longest_escort_row_fits_the_screen_width() -> void:
	var escort: String = "Escort  HP 120/120  TAKING COVER  stamina ######  [E] follow [R] run   HUNTED by 3!"
	_hud.show_rows("WAVE 3 / 3", "GEN 3", "Bloomed left: 20", _rows([escort]), LONG_TRAITS)
	assert_eq(_hud.overflow_lines(), 1)
	assert_lte(_width(escort) + 4.0 + HudLayout.CHECK_TEXT_INDENT, 476.0, "the full-width line fits 480 px")
	assert_gte(_hud.overflow_left(), 0.0, "its plate stays on screen")


func test_short_overflow_plate_only_covers_the_right_side() -> void:
	var line: String = "Hold the point  45 s   point HP 200   B: 3 barricades"
	_hud.show_rows("WAVE 1 / 1", "GEN 1", "20 left", _rows(["Clear", "Survive", "Stay", line]), LONG_TRAITS)
	assert_eq(_hud.overflow_lines(), 1)
	assert_gt(_hud.overflow_left(), 100.0, "the left of the screen stays open")


func test_ticked_row_and_new_wave_get_a_highlight() -> void:
	var rows: Array[Dictionary] = _rows(["Clear the wave"])
	_hud.show_rows("WAVE 1 / 2", "GEN 1", "5 left", rows, LONG_TRAITS)
	assert_eq(_hud._flare, 0.0, "nothing on the first frame")
	var done: Array[Dictionary] = [{"text": "Clear the wave", "mark": "done"}]
	_hud.show_rows("WAVE 1 / 2", "GEN 1", "0 left", done, LONG_TRAITS)
	assert_true(_hud._row_flash.has("Clear the wave"), "ticked row glows")
	_hud.show_rows("WAVE 2 / 2", "GEN 2", "9 left", rows, LONG_TRAITS)
	assert_gt(_hud._flare, 0.0, "the wave number flares on a new wave")


func test_column_holds_three_rows_then_overflows() -> void:
	_hud.show_rows("WAVE 1 / 3", "GEN 1", "", _rows(["a", "b", "c", "d", "e", "f"]), LONG_TRAITS)
	assert_eq(_hud.column_rows().size(), HudLayout.CHECK_BASELINE.size())
	assert_eq(_hud.overflow_lines(), HudLayout.MAX_OVERFLOW_LINES)
	assert_eq(_hud.overflow_rows()[0]["text"], "d", "rows keep their order")


func test_prototype_checklist_follows_the_wave_manager() -> void:
	var wm: WaveManager = WaveManager.new()
	autofree(wm)
	assert_eq(_hud.checklist(wm)[0]["mark"], "todo")
	wm.waiting_for_continue = true
	var rows: Array[Dictionary] = _hud.checklist(wm)
	assert_eq(rows[0]["mark"], "done", "cleared wave is ticked")
	assert_eq(rows.size(), 2)
	wm.waiting_for_continue = false
	wm.failed = true
	assert_eq(_hud.checklist(wm)[0]["mark"], "failed")

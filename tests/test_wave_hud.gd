extends GutTest
## Top HUD bar: a long objective line must never run into the Bloomed traits on the right.

## Widest trait line the HUD can show (three long trait words).
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


func _bar() -> ColorRect:
	return _hud.get_child(0) as ColorRect


func _width(text: String) -> float:
	return ThemeDB.fallback_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, WaveHud.FONT_SIZE).x


func test_short_status_shares_the_line_with_the_traits() -> void:
	_hud.show_lines("WAVE 1   generation 1", "Wave 1 / 3   Clear the wave   5 left", LONG_TRAITS)
	assert_false(_hud.is_status_below())
	assert_eq(_bar().size.y, WaveHud.BAR_HEIGHT)


func test_long_stealth_status_moves_below_the_traits() -> void:
	# Greywood 1 opening: countdown + Stealth objective + day/night event.
	var status: String = "Wave 1 / 3   They're coming in 3.2 s   Reach the exit unseen   close calls 0 (next 3.0 s)" \
			+ "   [Night falls in 5 s]"
	assert_gt(_width(status) + WaveHud.GAP + _width(LONG_TRAITS), 472.0, "would overlap on one line")
	_hud.show_lines("WAVE 1   generation 1", status, LONG_TRAITS)
	assert_true(_hud.is_status_below(), "status gets its own line")
	assert_eq(_bar().size.y, WaveHud.BAR_HEIGHT_TALL, "bar grows to cover it")
	# Back to a short line: the bar shrinks again.
	_hud.show_lines("WAVE 1   generation 1", "Wave 1 / 3   Clear the wave", LONG_TRAITS)
	assert_false(_hud.is_status_below())
	assert_eq(_bar().size.y, WaveHud.BAR_HEIGHT)


func test_longest_escort_opening_fits_the_screen_width() -> void:
	var status: String = "Wave 3 / 3   They're coming in 3.2 s   B: 2 barricades   " \
			+ "Escort  HP 30/30  TAKING COVER  stamina ######  [E] follow [R] run"
	_hud.show_lines("WAVE 3   generation 3", status, LONG_TRAITS)
	assert_true(_hud.is_status_below())
	assert_lte(_width(status), 472.0, "the full-width line fits 480 px minus margins")

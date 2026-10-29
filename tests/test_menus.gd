extends GutTest
## Menu design system (MenuStyle) and the screens built on it: every page fits the 480 x 270
## layout, pages switch with the keyboard, Level Select shows every zone and level, Settings only
## offers what really works, and menu text uses the crisp fonts (not the blurry raster default).

const VIEWPORT: Rect2 = Rect2(0, 0, 480, 270)


func after_each() -> void:
	get_tree().paused = false


func _menu() -> MainMenu:
	GameState.test_mode = false
	var menu: MainMenu = load("res://ui/menus/main_menu.tscn").instantiate()
	add_child_autofree(menu)
	await wait_process_frames(3)
	return menu


## Visible controls of `root` that stick out of the viewport or are squeezed below their minimum.
func _misfits(root: Node) -> PackedStringArray:
	var bad: PackedStringArray = PackedStringArray()
	for n: Node in root.find_children("*", "Control", true, false):
		var c: Control = n
		if not c.is_visible_in_tree() or c is MenuBackdrop or c is MenuOverlay:
			continue
		var r: Rect2 = c.get_global_rect()
		if r.position.x < -0.5 or r.position.y < -0.5 or r.end.x > VIEWPORT.end.x + 0.5 or r.end.y > VIEWPORT.end.y + 0.5:
			bad.append("%s outside %s" % [c.name, r])
		var m: Vector2 = c.get_combined_minimum_size()
		if m.x > c.size.x + 0.5 or m.y > c.size.y + 0.5:
			bad.append("%s min %s > size %s" % [c.name, m, c.size])
	return bad


func test_every_main_menu_page_fits_the_screen() -> void:
	var menu: MainMenu = await _menu()
	assert_eq(_misfits(menu).size(), 0, "home: " + "; ".join(_misfits(menu).slice(0, 4)))
	menu._show_scenarios(true)
	await wait_process_frames(2)
	assert_eq(_misfits(menu).size(), 0, "level select: " + "; ".join(_misfits(menu).slice(0, 4)))
	menu._show_scenarios(false)
	menu._show_settings(true)
	await wait_process_frames(2)
	assert_eq(_misfits(menu).size(), 0, "settings: " + "; ".join(_misfits(menu).slice(0, 4)))


func test_pages_switch_and_focus_follows() -> void:
	var menu: MainMenu = await _menu()
	assert_eq(get_viewport().gui_get_focus_owner(), menu._new_game_button)
	menu._show_scenarios(true)
	assert_true(menu._levels_page.visible)
	assert_false(menu._home.visible)
	assert_eq(get_viewport().gui_get_focus_owner(), menu._scenario_first, "first level focused")
	var esc: InputEventAction = InputEventAction.new()
	esc.action = "ui_cancel"
	esc.pressed = true
	menu._unhandled_input(esc)
	assert_true(menu._home.visible, "Esc goes back")
	menu._show_settings(true)
	assert_eq(get_viewport().gui_get_focus_owner(), menu._settings.fullscreen_toggle)
	menu._settings._unhandled_input(esc)
	assert_true(menu._home.visible, "Esc leaves Settings")


func test_level_select_shows_four_zones_and_every_level() -> void:
	var menu: MainMenu = await _menu()
	var levels: int = 0
	var zones: Array[ZoneConfig] = GameState.campaign().zones
	for zone: ZoneConfig in zones:
		levels += zone.levels.size()
	var tiles: Array = menu._scenario_menu.find_children("*", "Button", true, false).filter(
			func(b: Node) -> bool: return (b as Button).theme_type_variation == &"TileButton")
	assert_eq(menu._scenario_menu._cards.size(), zones.size(), "one card per zone")
	assert_eq(tiles.size(), levels, "one row per level")
	var texts: PackedStringArray = PackedStringArray()
	for b: Node in menu._scenario_menu.find_children("*", "Button", true, false):
		texts.append((b as Button).text)
	for scenario: Dictionary in DebugScenarios.SCENARIOS:
		assert_true(texts.has(scenario["text"]), scenario["text"])
	assert_true(texts.has("Endless (wave loop)"))
	assert_eq(LevelSelect._short_title(zones[0].levels[1]), "Hold the point")
	assert_eq(LevelSelect._short_title(zones[0].levels[3]), "Boss")


func test_settings_only_offer_what_works_and_list_the_real_keys() -> void:
	var menu: MainMenu = await _menu()
	var toggles: Array = menu._settings.find_children("*", "BaseButton", true, false).filter(
			func(b: Node) -> bool: return b != menu._settings.back_button)
	assert_eq(toggles.size(), 1, "only the fullscreen toggle")
	assert_eq(menu._settings.fullscreen_toggle.button_pressed, UserSettings.fullscreen)
	assert_true(SettingsPanel.key_names("dodge").size() > 0, "dodge has a key")
	assert_eq(SettingsPanel.key_names("no_such_action").size(), 0)


func test_menu_text_uses_the_crisp_fonts() -> void:
	var t: Theme = MenuStyle.theme()
	var body: FontFile = t.default_font as FontFile
	assert_not_null(body)
	assert_true(body.multichannel_signed_distance_field, "body text from a distance field")
	assert_eq(t.get_font("font", "TitleLabel"), MenuStyle.heading_font())
	var report: Theme = MenuStyle.with_fonts(load(ReportScreen.THEME_PATH))
	assert_eq(report.default_font, MenuStyle.body_font(), "between-wave screens too")
	assert_false(ProjectSettings.get_setting("gui/fonts/dynamic_fonts/use_oversampling"), "the HUD is left as it was")


func test_menu_buttons_get_the_hover_animation() -> void:
	var menu: MainMenu = await _menu()
	for b: Node in menu._menu.find_children("*", "Button", true, false):
		assert_not_null(b.get_node_or_null("Fx"), (b as Button).text)
	var fx: ButtonFx = menu._new_game_button.get_node("Fx")
	await wait_seconds(0.3)
	assert_almost_eq(fx.heat, 1.0, 0.01, "focused button is lit")


func test_pause_menu_opens_settings_in_place_and_resumes() -> void:
	var pause: PauseMenu = PauseMenu.new()
	add_child_autofree(pause)
	await wait_process_frames(1)
	pause.open()
	assert_true(get_tree().paused)
	assert_eq(get_viewport().gui_get_focus_owner(), pause._resume_button)
	pause._show_settings(true)
	assert_true(pause._settings.visible)
	assert_false(pause._list.visible)
	pause._settings.back_pressed.emit()
	assert_true(pause._list.visible)
	pause.close()
	assert_false(get_tree().paused)


func test_zone_art_bakes_for_every_zone() -> void:
	for z: int in 4:
		var img: Image = ZoneArt.bake(z)
		assert_eq(img.get_size(), ZoneArt.SIZE)
	assert_ne(ZoneArt.bake(0).get_data(), ZoneArt.bake(3).get_data(), "zones look different")

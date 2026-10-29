class_name MainMenu
extends Control
## Main menu: New Game / Continue (the campaign: 4 zones, 16 levels), New Game+ once the
## Seed is destroyed, Level Select (jump right before a campaign moment, plus the Endless
## wave loop; nothing is saved - DebugScenarios), Settings, Quit.
## Three pages over the same burning-city backdrop (MenuBackdrop) - home (Wordmark logo and the
## buttons), Level Select (LevelSelect), Settings (SettingsPanel) - that cross-fade. The look
## comes from MenuStyle. Keyboard: arrows + Enter, Esc goes back; the mouse works throughout.

const GAME_SCENE: String = "res://world/main.tscn"
const BUTTON_WIDTH: float = 132.0
const FADE_SECONDS: float = 0.16

var _menu: VBoxContainer
var _settings: SettingsPanel
var _scenario_menu: LevelSelect
var _scenario_first: Button
var _scenario_last_wave: CheckBox
var _new_game_button: Button
var _continue_button: Button
var _home: Control
var _levels_page: Control
var _settings_page: Control
var _footer: Control
var _page: Control
var _fade: Tween


func _ready() -> void:
	get_tree().paused = false  # in case we come back here from a paused game
	UserSettings.load_and_apply()
	theme = MenuStyle.theme()
	var backdrop: MenuBackdrop = MenuBackdrop.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	_home = _page_root()
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.offset_bottom = -14.0  # clear of the footer
	_home.add_child(center)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	center.add_child(column)
	var logo: Wordmark = Wordmark.new()
	logo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(logo)
	var tagline: Label = MenuStyle.label(column, "survive the Bloomed - they evolve", &"MutedLabel", true)
	tagline.add_theme_color_override("font_color", Color(MenuStyle.MUTED, 0.9))
	var rule: RuleLine = RuleLine.new()
	rule.custom_minimum_size = Vector2(110, 3)
	rule.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(rule)
	var gap: Control = Control.new()
	gap.custom_minimum_size = Vector2(0, 3)
	column.add_child(gap)

	_menu = VBoxContainer.new()
	_menu.add_theme_constant_override("separation", 3)
	_menu.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(_menu)
	# A test scenario run keeps its state in memory (e.g. the victory unlocks) and is never saved.
	var has_campaign: bool = GameState.test_mode or GameState.load_campaign()
	if GameState.legacy_notice != "":
		var notice: Label = MenuStyle.label(_menu, GameState.legacy_notice, &"AccentLabel", true)
		notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		notice.custom_minimum_size = Vector2(260, 0)
	if GameState.test_mode:
		var chip: PanelContainer = PanelContainer.new()
		chip.theme_type_variation = &"ChipPanel"
		chip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_menu.add_child(chip)
		MenuStyle.label(chip, "TEST MODE - nothing is saved", &"AmberLabel", true)
		_add_button(_menu, "Leave test mode", _on_leave_test_mode)
	_new_game_button = _add_button(_menu, "New Game", _on_new_campaign.bind(false))
	_continue_button = _add_button(_menu, "Continue", _on_continue_campaign)
	_continue_button.visible = has_campaign and GameState.campaign_active and not GameState.campaign_won
	if _continue_button.visible:
		var level: LevelConfig = GameState.current_level()
		_continue_button.text = "Continue: " + ("Safehouse" if GameState.safehouse_pending
				else (level.title if level != null else ""))
		_continue_button.custom_minimum_size = Vector2(maxf(BUTTON_WIDTH, 170.0), 16)
	if GameState.ng_plus_unlocked:
		_add_button(_menu, "New Game+", _on_new_campaign.bind(true))
	_add_button(_menu, "Level Select", _show_scenarios.bind(true))
	_add_button(_menu, "Settings", _show_settings.bind(true))
	_add_button(_menu, "Quit", _on_quit)
	for b: Node in _menu.get_children():
		if b is Button:
			(b as Button).size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	_levels_page = _page_root()
	var levels_margin: MarginContainer = MarginContainer.new()
	levels_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side: String in ["margin_left", "margin_right"]:
		levels_margin.add_theme_constant_override(side, 9)
	levels_margin.add_theme_constant_override("margin_top", 6)
	levels_margin.add_theme_constant_override("margin_bottom", 4)
	_levels_page.add_child(levels_margin)
	_scenario_menu = LevelSelect.new()
	_scenario_menu.on_scenario = _on_scenario
	_scenario_menu.on_level = _on_scenario_level
	_scenario_menu.on_endless = _on_endless
	_scenario_menu.on_back = _show_scenarios.bind(false)
	levels_margin.add_child(_scenario_menu)
	_scenario_first = _scenario_menu.first_button
	_scenario_last_wave = _scenario_menu.last_wave

	_settings_page = _page_root()
	var settings_center: CenterContainer = CenterContainer.new()
	settings_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	settings_center.offset_bottom = -14.0
	_settings_page.add_child(settings_center)
	_settings = SettingsPanel.new()
	_settings.back_pressed.connect(_show_settings.bind(false))
	settings_center.add_child(_settings)

	_footer = MarginContainer.new()
	_footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_footer.offset_top = -13.0
	_footer.offset_bottom = -2.0
	_footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_footer)
	MenuStyle.key_hints(_footer, [["ARROWS", "choose"], ["ENTER", "select"], ["ESC", "back"], ["MOUSE", "point and click"]])

	_levels_page.visible = false
	_settings_page.visible = false
	_page = _home
	_new_game_button.grab_focus()
	_intro()


## Full-screen page holder (pages cross-fade).
func _page_root() -> Control:
	var page: Control = Control.new()
	page.set_anchors_preset(Control.PRESET_FULL_RECT)
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(page)
	return page


## The buttons drop in one after the other the first time the menu opens.
func _intro() -> void:
	var i: int = 0
	for b: Node in _menu.get_children():
		if b is Control and (b as Control).visible:
			var c: Control = b
			c.modulate.a = 0.0
			var tw: Tween = create_tween()
			tw.tween_interval(0.18 + 0.05 * i)
			tw.tween_property(c, "modulate:a", 1.0, 0.2)
			i += 1
	_footer.modulate.a = 0.0
	create_tween().tween_property(_footer, "modulate:a", 1.0, 0.4).set_delay(0.4)


func _on_new_campaign(ng_plus: bool) -> void:
	if GameState.test_mode and not ng_plus:
		GameState.end_test_mode()  # a real new campaign (New Game+ after a test victory stays a test)
	GameState.endless_mode = false
	GameState.start_new_campaign(ng_plus)
	GameState.save_campaign()
	GameState.start_current_level(get_tree())


func _on_continue_campaign() -> void:
	GameState.endless_mode = false
	GameState.campaign_active = true
	if GameState.safehouse_pending:
		# The zone's Apex is already beaten: carry on from the Safehouse, don't replay the boss.
		GameState.safehouse_mode = "zone"
		get_tree().change_scene_to_file(GameState.SAFEHOUSE_SCENE)
		return
	GameState.start_current_level(get_tree())


## Endless (test only): the plain evolution loop on Maple Hollow, no objective, no end. A test
## run, so nothing is saved (not the campaign, not the old prototype save).
func _on_endless() -> void:
	GameState.test_mode = true
	GameState.endless_mode = true
	GameState.leave_campaign()
	get_tree().change_scene_to_file(GAME_SCENE)


func _on_leave_test_mode() -> void:
	GameState.end_test_mode()
	get_tree().reload_current_scene()


func _on_scenario(scenario: Dictionary) -> void:
	DebugScenarios.launch(get_tree(), scenario)


func _on_scenario_level(zone: int, level_index: int) -> void:
	DebugScenarios.launch(get_tree(), {"zone": zone, "level": level_index, "scene": "level",
		"last_wave": _scenario_last_wave.button_pressed})


func _show_scenarios(open: bool) -> void:
	_go_to(_levels_page if open else _home)
	_footer.visible = not open  # the Level Select page uses the whole screen
	if open:
		_scenario_first.grab_focus()
	else:
		MenuStyle.first_button(_menu).grab_focus()


func _show_settings(open: bool) -> void:
	_go_to(_settings_page if open else _home)
	if open:
		_settings.fullscreen_toggle.grab_focus()
	else:
		MenuStyle.first_button(_menu).grab_focus()


## Cross-fade to `page` (instant visibility switch, so focus and tests see the new page at once;
## only its opacity eases in).
func _go_to(page: Control) -> void:
	if _fade != null and _fade.is_valid():
		_fade.kill()
	for p: Control in [_home, _levels_page, _settings_page]:
		p.visible = p == page
	_page = page
	page.modulate.a = 0.0
	_fade = create_tween()
	_fade.tween_property(page, "modulate:a", 1.0, FADE_SECONDS)


func _unhandled_input(event: InputEvent) -> void:
	if _levels_page.visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_show_scenarios(false)


func _on_quit() -> void:
	get_tree().quit()


func _add_button(parent: Control, text: String, action: Callable) -> Button:
	return MenuStyle.button(parent, text, action, BUTTON_WIDTH)

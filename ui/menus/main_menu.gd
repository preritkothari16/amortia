class_name MainMenu
extends Control
## Greybox main menu: New Game / Continue (the campaign: 4 zones, 16 levels), New Game+ once the
## Seed is destroyed, Test Scenarios (jump right before a campaign moment, plus the Endless
## wave loop; nothing is saved - DebugScenarios), Settings (placeholder), Quit.
## Built in code like the other prototype menus. Keyboard: arrows + Enter, Esc goes back.

const GAME_SCENE: String = "res://world/main.tscn"
const FONT_SIZE: int = 8
const BUTTON_SIZE: Vector2 = Vector2(110, 16)

var _menu: VBoxContainer
var _settings: VBoxContainer
var _scenario_menu: VBoxContainer
var _scenario_first: Button
var _scenario_last_wave: CheckBox
var _new_game_button: Button
var _continue_button: Button


func _ready() -> void:
	get_tree().paused = false  # in case we come back here from a paused game
	var backdrop: ColorRect = ColorRect.new()
	backdrop.color = Color(0.1, 0.11, 0.13)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	center.add_child(column)

	_add_label(column, "AMORTIA", 24, Color(0.9, 0.35, 0.35))
	_add_label(column, "greybox prototype", FONT_SIZE, Color(0.55, 0.55, 0.55))
	var gap: Control = Control.new()
	gap.custom_minimum_size = Vector2(0, 8)
	column.add_child(gap)

	_menu = VBoxContainer.new()
	_menu.add_theme_constant_override("separation", 3)
	column.add_child(_menu)
	# A test scenario run keeps its state in memory (e.g. the victory unlocks) and is never saved.
	var has_campaign: bool = GameState.test_mode or GameState.load_campaign()
	if GameState.test_mode:
		_add_label(_menu, "TEST MODE - nothing is saved", FONT_SIZE, Color(1.0, 0.6, 0.4))
		_add_button(_menu, "Leave test mode", _on_leave_test_mode)
	_new_game_button = _add_button(_menu, "New Game", _on_new_campaign.bind(false))
	_continue_button = _add_button(_menu, "Continue", _on_continue_campaign)
	_continue_button.visible = has_campaign and GameState.campaign_active and not GameState.campaign_won
	if _continue_button.visible:
		var level: LevelConfig = GameState.current_level()
		_continue_button.text = "Continue: " + ("Safehouse" if GameState.safehouse_pending
				else (level.title if level != null else ""))
		_continue_button.custom_minimum_size = Vector2(150, 16)
	if GameState.ng_plus_unlocked:
		_add_button(_menu, "New Game+", _on_new_campaign.bind(true))
	_add_button(_menu, "Test Scenarios", _show_scenarios.bind(true))
	_add_button(_menu, "Settings", _show_settings.bind(true))
	_add_button(_menu, "Quit", _on_quit)

	_settings = VBoxContainer.new()
	_settings.add_theme_constant_override("separation", 3)
	_settings.visible = false
	column.add_child(_settings)
	_add_label(_settings, "SETTINGS", 10, Color.WHITE)
	_add_label(_settings, "Audio, controls and display\noptions come in a later phase.", FONT_SIZE, Color(0.6, 0.6, 0.6))
	_add_button(_settings, "Back", _show_settings.bind(false))

	_build_scenario_menu(column)
	_new_game_button.grab_focus()


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


## Test Scenarios submenu: the transitions on the left, any of the 16 levels on the right.
func _build_scenario_menu(column: VBoxContainer) -> void:
	_scenario_menu = VBoxContainer.new()
	_scenario_menu.add_theme_constant_override("separation", 3)
	_scenario_menu.visible = false
	column.add_child(_scenario_menu)
	_add_label(_scenario_menu, "TEST SCENARIOS", 10, Color.WHITE)
	_add_label(_scenario_menu, "Starts right before the moment. Nothing is saved." + (
			" F8 ends the current wave." if DebugKeys.enabled() else ""), FONT_SIZE, Color(0.6, 0.6, 0.6))
	var sides: HBoxContainer = HBoxContainer.new()
	sides.add_theme_constant_override("separation", 12)
	_scenario_menu.add_child(sides)

	var left: VBoxContainer = VBoxContainer.new()
	left.add_theme_constant_override("separation", 3)
	sides.add_child(left)
	_add_label(left, "Transitions", FONT_SIZE, Color(1.0, 0.85, 0.5))
	for scenario: Dictionary in DebugScenarios.SCENARIOS:
		var b: Button = _add_button(left, scenario["text"], _on_scenario.bind(scenario))
		b.custom_minimum_size = Vector2(150, 16)
		if _scenario_first == null:
			_scenario_first = b

	var endless: Button = _add_button(left, "Endless (wave loop)", _on_endless)
	endless.custom_minimum_size = Vector2(150, 16)

	var right: VBoxContainer = VBoxContainer.new()
	right.add_theme_constant_override("separation", 3)
	sides.add_child(right)
	_add_label(right, "Any level (zone - level)", FONT_SIZE, Color(1.0, 0.85, 0.5))
	var grid: GridContainer = GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 3)
	grid.add_theme_constant_override("v_separation", 3)
	right.add_child(grid)
	var zones: Array[ZoneConfig] = GameState.campaign().zones
	for z: int in zones.size():
		for l: int in zones[z].levels.size():
			var apex: bool = l == zones[z].levels.size() - 1
			var b: Button = _add_button(grid, "%d-%s" % [z + 1, "Apex" if apex else str(l + 1)],
					_on_scenario_level.bind(z + 1, l))
			b.custom_minimum_size = Vector2(40, 16)
			b.tooltip_text = zones[z].levels[l].title
	_scenario_last_wave = CheckBox.new()
	_scenario_last_wave.text = "Start at the last wave"
	_scenario_last_wave.add_theme_font_size_override("font_size", FONT_SIZE)
	right.add_child(_scenario_last_wave)

	var back: Button = _add_button(_scenario_menu, "Back", _show_scenarios.bind(false))
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER


func _on_scenario(scenario: Dictionary) -> void:
	DebugScenarios.launch(get_tree(), scenario)


func _on_scenario_level(zone: int, level_index: int) -> void:
	DebugScenarios.launch(get_tree(), {"zone": zone, "level": level_index, "scene": "level",
		"last_wave": _scenario_last_wave.button_pressed})


func _show_scenarios(open: bool) -> void:
	_menu.visible = not open
	_scenario_menu.visible = open
	if open:
		_scenario_first.grab_focus()
	else:
		_menu.get_children().filter(func(c: Node) -> bool: return c is Button and c.visible)[0].grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if _settings.visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_show_settings(false)
	elif _scenario_menu.visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_show_scenarios(false)


func _on_quit() -> void:
	get_tree().quit()


func _show_settings(open: bool) -> void:
	_menu.visible = not open
	_settings.visible = open
	var first: Button = (_settings if open else _menu).get_children().filter(
		func(c: Node) -> bool: return c is Button and c.visible)[0]
	first.grab_focus()


func _add_button(parent: Control, text: String, action: Callable) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.custom_minimum_size = BUTTON_SIZE
	b.add_theme_font_size_override("font_size", FONT_SIZE)
	b.pressed.connect(action)
	parent.add_child(b)
	return b


func _add_label(parent: Control, text: String, font_size: int, color: Color) -> void:
	var l: Label = Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	parent.add_child(l)

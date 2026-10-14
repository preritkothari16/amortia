class_name MainMenu
extends Control
## Greybox main menu: New Game / Continue (the prototype wave loop), Campaign (16 levels:
## new, continue, New Game+ and Endless once the campaign is won), Test Scenarios (jump right
## before a campaign moment, nothing saved - DebugScenarios), Settings (placeholder), Quit.
## Built in code like the other prototype menus. Keyboard: arrows + Enter, Esc goes back.

const GAME_SCENE: String = "res://world/main.tscn"
const FONT_SIZE: int = 8
const BUTTON_SIZE: Vector2 = Vector2(110, 16)

var _menu: VBoxContainer
var _settings: VBoxContainer
var _campaign_menu: VBoxContainer
var _scenario_menu: VBoxContainer
var _scenario_first: Button
var _scenario_last_wave: CheckBox
var _campaign_continue: Button
var _new_game_button: Button
var _continue_button: Button
## Shown when Continue fails (unreadable save).
var _message: Label


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
	_new_game_button = _add_button(_menu, "New Game", _on_new_game)
	_continue_button = _add_button(_menu, "Continue", _on_continue)
	_continue_button.visible = SaveSystem.has_save()
	_message = Label.new()
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.add_theme_font_size_override("font_size", FONT_SIZE)
	_message.add_theme_color_override("font_color", Color(1.0, 0.6, 0.4))
	_message.visible = false
	_add_button(_menu, "Campaign", _show_campaign.bind(true))
	_add_button(_menu, "Test Scenarios", _show_scenarios.bind(true))
	_add_button(_menu, "Settings", _show_settings.bind(true))
	_add_button(_menu, "Quit", _on_quit)
	_menu.add_child(_message)

	_settings = VBoxContainer.new()
	_settings.add_theme_constant_override("separation", 3)
	_settings.visible = false
	column.add_child(_settings)
	_add_label(_settings, "SETTINGS", 10, Color.WHITE)
	_add_label(_settings, "Audio, controls and display\noptions come in a later phase.", FONT_SIZE, Color(0.6, 0.6, 0.6))
	_add_button(_settings, "Back", _show_settings.bind(false))

	_build_campaign_menu(column)
	_build_scenario_menu(column)
	_new_game_button.grab_focus()


## Campaign submenu. Unlocks come from the campaign save.
func _build_campaign_menu(column: VBoxContainer) -> void:
	# A test scenario run keeps its state in memory (e.g. the victory unlocks) and is never saved.
	var has_campaign: bool = GameState.test_mode or GameState.load_campaign()
	_campaign_menu = VBoxContainer.new()
	_campaign_menu.add_theme_constant_override("separation", 3)
	_campaign_menu.visible = false
	column.add_child(_campaign_menu)
	_add_label(_campaign_menu, "CAMPAIGN", 10, Color.WHITE)
	if GameState.test_mode:
		_add_label(_campaign_menu, "TEST MODE - nothing is saved", FONT_SIZE, Color(1.0, 0.6, 0.4))
		_add_button(_campaign_menu, "Leave test mode", _on_leave_test_mode)
	_add_button(_campaign_menu, "New Campaign", _on_new_campaign.bind(false))
	_campaign_continue = _add_button(_campaign_menu, "Continue Campaign", _on_continue_campaign)
	_campaign_continue.visible = has_campaign and GameState.campaign_active and not GameState.campaign_won
	if _campaign_continue.visible:
		var level: LevelConfig = GameState.current_level()
		_add_label(_campaign_menu, level.title if level != null else "", FONT_SIZE, Color(0.6, 0.6, 0.6))
	var ng: Button = _add_button(_campaign_menu, "New Game+", _on_new_campaign.bind(true))
	ng.disabled = not GameState.ng_plus_unlocked
	var endless: Button = _add_button(_campaign_menu, "Endless" + (" (best wave %d)" % GameState.endless_best_wave
			if GameState.endless_best_wave > 0 else ""), _on_endless)
	endless.disabled = not GameState.endless_unlocked
	if ng.disabled:
		_add_label(_campaign_menu, "Destroy the Seed to unlock New Game+ and Endless.", FONT_SIZE, Color(0.55, 0.55, 0.55))
	_add_button(_campaign_menu, "Back", _show_campaign.bind(false))


func _on_new_campaign(ng_plus: bool) -> void:
	if GameState.test_mode and not ng_plus:
		GameState.end_test_mode()  # a real new campaign (New Game+ after a test victory stays a test)
	GameState.start_new_campaign(ng_plus)
	GameState.save_campaign()
	GameState.start_current_level(get_tree())


func _on_continue_campaign() -> void:
	GameState.campaign_active = true
	GameState.start_current_level(get_tree())


## Endless (post-game): the evolution loop with no end, best wave remembered.
func _on_endless() -> void:
	GameState.endless_mode = true
	SaveSystem.pending_state = {}
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
	_add_label(_scenario_menu, "Starts right before the moment. Nothing is saved. F8 ends the current wave.",
			FONT_SIZE, Color(0.6, 0.6, 0.6))
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


func _show_campaign(open: bool) -> void:
	_menu.visible = not open
	_campaign_menu.visible = open
	var first: Button = (_campaign_menu if open else _menu).get_children().filter(
		func(c: Node) -> bool: return c is Button and c.visible and not c.disabled)[0]
	first.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if _settings.visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_show_settings(false)
	elif _campaign_menu.visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_show_campaign(false)
	elif _scenario_menu.visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_show_scenarios(false)


## Fresh start. The old save stays until the new game's first checkpoint overwrites it.
func _on_new_game() -> void:
	if GameState.test_mode:
		GameState.end_test_mode()
	GameState.leave_campaign()
	GameState.endless_mode = false
	SaveSystem.pending_state = {}
	get_tree().change_scene_to_file(GAME_SCENE)


## Reads the save and hands it to the level (which validates it in detail).
func _on_continue() -> void:
	var result: Dictionary = SaveSystem.read_save()
	if not result["ok"]:
		_message.text = "Can't load the save: %s.
New Game will replace it." % result["error"]
		_message.visible = true
		_continue_button.visible = false
		_new_game_button.grab_focus()
		return
	if GameState.test_mode:
		GameState.end_test_mode()
	GameState.leave_campaign()
	GameState.endless_mode = false
	SaveSystem.pending_state = result["data"]
	get_tree().change_scene_to_file(GAME_SCENE)


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

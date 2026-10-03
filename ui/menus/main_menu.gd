class_name MainMenu
extends Control
## Greybox main menu: New Game, Continue (only if a save exists), Settings (placeholder), Quit.
## Built in code like the other prototype menus. Keyboard: arrows + Enter, Esc closes Settings.

const GAME_SCENE: String = "res://world/main.tscn"
const FONT_SIZE: int = 8
const BUTTON_SIZE: Vector2 = Vector2(110, 16)

var _menu: VBoxContainer
var _settings: VBoxContainer
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
	_new_game_button = _add_button(_menu, "New Game", _on_new_game)
	_continue_button = _add_button(_menu, "Continue", _on_continue)
	_continue_button.visible = SaveSystem.has_save()
	_add_button(_menu, "Settings", _show_settings.bind(true))
	_add_button(_menu, "Quit", _on_quit)

	_settings = VBoxContainer.new()
	_settings.add_theme_constant_override("separation", 3)
	_settings.visible = false
	column.add_child(_settings)
	_add_label(_settings, "SETTINGS", 10, Color.WHITE)
	_add_label(_settings, "Audio, controls and display\noptions come in a later phase.", FONT_SIZE, Color(0.6, 0.6, 0.6))
	_add_button(_settings, "Back", _show_settings.bind(false))

	_new_game_button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if _settings.visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_show_settings(false)


func _on_new_game() -> void:
	get_tree().change_scene_to_file(GAME_SCENE)


## Loading isn't built yet; for now this starts the game like New Game.
func _on_continue() -> void:
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

class_name PauseMenu
extends Control
## Pause overlay (Esc): the game darkened behind a red vignette and drifting smoke, a compact
## panel with PAUSED and Resume / Settings / Main Menu / Quit, the save note and the controls.
## Pauses the game and restores the previous pause state on Resume (the Wave Report may already
## have paused it). The save is a between-waves checkpoint, so leaving mid-wave loses only that
## wave's progress; the menu says so. Settings opens the shared SettingsPanel in place.

const MAIN_MENU_SCENE: String = "res://ui/menus/main_menu.tscn"
const BUTTON_WIDTH: float = 120.0

var wave_manager: WaveManager

var _resume_button: Button
var _note: Label
var _panel: PanelContainer
var _list: VBoxContainer
var _settings: SettingsPanel
## Pause state from before the menu opened.
var _was_paused: bool = false


func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS  # must work while the game is paused
	theme = MenuStyle.theme()
	add_child(MenuOverlay.new())
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_panel = PanelContainer.new()
	_panel.theme_type_variation = &"MenuPanel"
	center.add_child(_panel)
	var stack: VBoxContainer = VBoxContainer.new()
	_panel.add_child(stack)

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 3)
	stack.add_child(_list)
	MenuStyle.heading(_list, "PAUSED", &"TitleLabel", 96.0)
	var gap: Control = Control.new()
	gap.custom_minimum_size = Vector2(0, 2)
	_list.add_child(gap)
	_resume_button = _add_button(_list, "Resume", close)
	_add_button(_list, "Settings", _show_settings.bind(true))
	_add_button(_list, "Main Menu", _on_main_menu)
	_add_button(_list, "Quit", _on_quit)
	_note = MenuStyle.label(_list, "", &"AccentLabel", true)
	var keys: HBoxContainer = MenuStyle.key_hints(_list, [["WASD", "move"], ["LMB", "shoot"], ["SPACE", "dodge"], ["Q", "swap"]])
	keys.add_theme_constant_override("separation", 6)

	_settings = SettingsPanel.new()
	_settings.visible = false
	_settings.back_pressed.connect(_show_settings.bind(false))
	stack.add_child(_settings)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	close() if visible else open()


func open() -> void:
	if visible:
		return
	_was_paused = get_tree().paused
	get_tree().paused = true
	var mid_wave: bool = wave_manager != null and wave_manager.is_wave_running()
	_note.text = "Leaving now loses this wave's progress\n(the game saves at the end of each wave)." if mid_wave else "Progress is saved."
	_show_settings(false)
	visible = true
	MenuStyle.enter(_panel, 0.0, 0.15)
	_resume_button.grab_focus()


func close() -> void:
	if not visible:
		return
	visible = false
	get_tree().paused = _was_paused


func _show_settings(open_it: bool) -> void:
	_list.visible = not open_it
	_settings.visible = open_it
	if open_it:
		_settings.fullscreen_toggle.grab_focus()
	elif visible:
		_resume_button.grab_focus()


func _on_main_menu() -> void:
	GameState.leave_campaign()
	get_tree().paused = false
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func _on_quit() -> void:
	get_tree().quit()


func _add_button(parent: Control, text: String, action: Callable) -> Button:
	var b: Button = MenuStyle.button(parent, text, action, BUTTON_WIDTH)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return b

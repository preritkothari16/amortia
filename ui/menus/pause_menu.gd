class_name PauseMenu
extends Control
## Greybox pause menu (Esc): Resume, Skills, Main Menu, Quit, plus a controls reminder.
## Pauses the game and restores the previous pause state on Resume (the Wave Report may
## already have paused it). The save is a between-waves checkpoint, so leaving mid-wave loses
## only that wave's progress; the menu says so.

const MAIN_MENU_SCENE: String = "res://ui/menus/main_menu.tscn"
const FONT_SIZE: int = 8
const BUTTON_SIZE: Vector2 = Vector2(110, 16)
const CONTROLS: String = "WASD move  ·  mouse aim  ·  LMB shoot  ·  Space dodge\nK skill tree  ·  Esc pause"

var wave_manager: WaveManager
var skill_menu: SkillTreeMenu

var _resume_button: Button
var _note: Label
## Pause state from before the menu opened.
var _was_paused: bool = false


func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS  # must work while the game is paused
	var backdrop: ColorRect = ColorRect.new()
	backdrop.color = Color(0, 0, 0, 0.6)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel: PanelContainer = PanelContainer.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.13, 0.14, 0.16, 0.97)
	style.border_color = Color(0.5, 0.5, 0.55)
	style.set_border_width_all(1)
	style.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 3)
	panel.add_child(column)

	_add_label(column, "PAUSED", 10, Color.WHITE)
	_resume_button = _add_button(column, "Resume", close)
	_add_button(column, "Skills", _on_skills)
	_add_button(column, "Main Menu", _on_main_menu)
	_add_button(column, "Quit", _on_quit)
	_note = _add_label(column, "", FONT_SIZE, Color(1.0, 0.7, 0.45))
	_add_label(column, CONTROLS, FONT_SIZE, Color(0.55, 0.55, 0.55))


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
	visible = true
	_resume_button.grab_focus()


func close() -> void:
	if not visible:
		return
	visible = false
	get_tree().paused = _was_paused


func _on_skills() -> void:
	close()
	if skill_menu != null:
		skill_menu.open()


func _on_main_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func _on_quit() -> void:
	get_tree().quit()


func _add_button(parent: Control, text: String, action: Callable) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.custom_minimum_size = BUTTON_SIZE
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.add_theme_font_size_override("font_size", FONT_SIZE)
	b.pressed.connect(action)
	parent.add_child(b)
	return b


func _add_label(parent: Control, text: String, font_size: int, color: Color) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	parent.add_child(l)
	return l

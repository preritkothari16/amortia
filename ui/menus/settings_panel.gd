class_name SettingsPanel
extends VBoxContainer
## Settings, shared by the main menu and the pause menu. Only what really can be changed is a
## control (Display: fullscreen); the controls are listed read-only, straight from the InputMap,
## so the list can't drift from the real bindings. `back_pressed` when Back (or Esc) is used.

signal back_pressed

## [label, actions...]; the keys of every action are listed (move: all four).
const CONTROLS: Array = [
	["Move", "move_up", "move_left", "move_down", "move_right"],
	["Shoot", "shoot"],
	["Dodge", "dodge"],
	["Swap weapon", "swap_weapon"],
	["Noise-maker", "throw_noise"],
	["Barricade", "build"],
	["Interact", "interact"],
	["Escort: follow / wait", "escort_command"],
	["Escort: run", "escort_run"],
	["Report details", "report_details"],
]

var fullscreen_toggle: CheckButton
var back_button: Button


func _ready() -> void:
	add_theme_constant_override("separation", 4)
	MenuStyle.heading(self, "SETTINGS", &"TitleLabel", 90.0)
	var cols: HBoxContainer = HBoxContainer.new()
	cols.add_theme_constant_override("separation", 8)
	cols.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(cols)

	var display: VBoxContainer = _section(cols, "DISPLAY", 150.0)
	fullscreen_toggle = CheckButton.new()
	fullscreen_toggle.text = "Fullscreen"
	fullscreen_toggle.button_pressed = UserSettings.fullscreen
	fullscreen_toggle.custom_minimum_size = Vector2(140, 16)
	fullscreen_toggle.toggled.connect(func(on: bool) -> void: UserSettings.set_fullscreen(on))
	display.add_child(fullscreen_toggle)
	MenuStyle.decorate(fullscreen_toggle)
	var note: Label = MenuStyle.label(display, "The picture is scaled in whole steps so the pixel art stays sharp; a window between steps gets dark borders.", &"HintLabel")
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(140, 0)

	var controls: VBoxContainer = _section(cols, "CONTROLS", 190.0)
	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 1)
	controls.add_child(grid)
	_control_row(grid, "Aim", "Mouse")
	for row: Array in CONTROLS:
		var keys: PackedStringArray = PackedStringArray()
		for i: int in range(1, row.size()):
			keys.append_array(key_names(row[i]))
		if not keys.is_empty():
			var joined: String = "".join(keys) if row.size() > 2 and keys.size() == row.size() - 1 else " / ".join(keys)
			_control_row(grid, row[0], joined)
	_control_row(grid, "Pause", "Esc")

	back_button = MenuStyle.button(self, "Back", func() -> void: back_pressed.emit(), 110.0)
	back_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER


func _section(parent: Node, title: String, width: float) -> VBoxContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.theme_type_variation = &"CardPanel"
	panel.custom_minimum_size = Vector2(width, 0)
	parent.add_child(panel)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	panel.add_child(box)
	MenuStyle.label(box, title, &"SectionLabel")
	return box


func _control_row(grid: GridContainer, action: String, keys: String) -> void:
	MenuStyle.label(grid, action, &"MutedLabel")
	var k: Label = MenuStyle.label(grid, keys)
	k.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT


## Readable names of the keys / buttons bound to `action` ("W", "Space", "LMB"...).
static func key_names(action: String) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if not InputMap.has_action(action):
		return out
	for e: InputEvent in InputMap.action_get_events(action):
		var name: String = ""
		if e is InputEventKey:
			var k: InputEventKey = e
			var code: Key = k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode
			name = OS.get_keycode_string(code)
		elif e is InputEventMouseButton:
			name = {MOUSE_BUTTON_LEFT: "LMB", MOUSE_BUTTON_RIGHT: "RMB", MOUSE_BUTTON_MIDDLE: "MMB"}.get((e as InputEventMouseButton).button_index, "Mouse")
		if name != "" and not out.has(name):
			out.append(name)
	return out


func _unhandled_input(event: InputEvent) -> void:
	if is_visible_in_tree() and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		back_pressed.emit()

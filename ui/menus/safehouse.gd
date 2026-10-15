class_name Safehouse
extends Control
## Greybox Safehouse hub (GDD 7.6), shown after each zone's Apex. Shows what the run carries
## and offers the way on. The rooms (Workbench, Lab, Radio, Garden, Bunks) are placeholders
## until their content is designed - listed, disabled, nothing invented.
## Victory mode (after the Seed): the campaign is won; Endless and New Game+ are unlocked.

const MAIN_MENU_SCENE: String = "res://ui/menus/main_menu.tscn"
const FONT_SIZE: int = 8
## Text width in viewport px (the viewport is 480 wide).
const LABEL_WIDTH: float = 400.0
const ROOMS: Array[String] = ["Workbench (gun mods)", "Lab (research samples)", "Radio (side objectives)",
	"Garden (healing items)", "Bunks (rescued survivors)"]

var _column: VBoxContainer


func _ready() -> void:
	get_tree().paused = false
	var backdrop: ColorRect = ColorRect.new()
	backdrop.color = Color(0.12, 0.11, 0.1)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_column = VBoxContainer.new()
	_column.add_theme_constant_override("separation", 3)
	center.add_child(_column)
	var victory: bool = GameState.safehouse_mode == "victory"
	var zones: Array[ZoneConfig] = GameState.campaign().zones
	var done: ZoneConfig = zones[GameState.current_zone - 1]
	if victory:
		_label("THE SEED IS DESTROYED", 14, Color(0.6, 1.0, 0.6))
		_label("Campaign complete. Endless and New Game+ are unlocked.", FONT_SIZE, Color(0.8, 0.8, 0.8))
	else:
		_label("SAFEHOUSE", 14, Color(1.0, 0.85, 0.5))
		_label("%s cleared." % done.title, FONT_SIZE, Color(0.8, 0.8, 0.8))
	_label("Samples %d   Scrap %d   Side objectives %d" % [GameState.samples, GameState.scrap, GameState.side_done.size()],
			FONT_SIZE, Color(0.6, 1.0, 0.7))
	var best: Genome = GameState.zone_best_genome(GameState.current_zone)
	if best != null:
		_label("Strongest strain of the zone: " + best.describe(), FONT_SIZE, Color(0.6, 0.6, 0.6))
	_label("Rooms (coming later):", FONT_SIZE, Color(0.8, 0.8, 0.8))
	for room: String in ROOMS:
		var b: Button = _button(room, func() -> void: pass)
		b.disabled = true
	if victory:
		_button("Main Menu", _on_main_menu).grab_focus()
	else:
		var next: ZoneConfig = zones[GameState.current_zone]
		_button("Continue to %s" % next.title, _on_continue).grab_focus()
		_button("Main Menu (progress saved)", _on_main_menu)


func _on_continue() -> void:
	GameState.enter_next_zone()
	GameState.start_current_level(get_tree())


func _on_main_menu() -> void:
	GameState.leave_campaign()
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func _label(text: String, size: int, color: Color) -> void:
	var l: Label = Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Wrapped inside a fixed width: the genome line is wider than the 480 px viewport otherwise.
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(LABEL_WIDTH, 0)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	_column.add_child(l)


func _button(text: String, action: Callable) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(180, 15)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.add_theme_font_size_override("font_size", FONT_SIZE)
	b.pressed.connect(action)
	_column.add_child(b)
	return b

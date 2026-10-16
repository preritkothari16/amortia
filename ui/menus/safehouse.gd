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
## Rooms that are still placeholders (disabled). Workbench and Lab work.
const ROOMS: Array[String] = ["Radio (side objectives)", "Garden (healing items)", "Bunks (rescued survivors)"]

var _column: VBoxContainer
## The Workbench / Lab screen that replaces the column while it is open.
var _panel: VBoxContainer
var _status_label: Label
var _center: CenterContainer


func _ready() -> void:
	get_tree().paused = false
	var backdrop: ColorRect = ColorRect.new()
	backdrop.color = Color(0.12, 0.11, 0.1)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	_center = CenterContainer.new()
	_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_center)
	_column = VBoxContainer.new()
	_column.add_theme_constant_override("separation", 3)
	_center.add_child(_column)
	var victory: bool = GameState.safehouse_mode == "victory"
	var zones: Array[ZoneConfig] = GameState.campaign().zones
	var done: ZoneConfig = zones[GameState.current_zone - 1]
	if victory:
		_label("THE SEED IS DESTROYED", 14, Color(0.6, 1.0, 0.6))
		_label("Campaign complete. New Game+ is unlocked.", FONT_SIZE, Color(0.8, 0.8, 0.8))
	else:
		_label("SAFEHOUSE", 14, Color(1.0, 0.85, 0.5))
		_label("%s cleared." % done.title, FONT_SIZE, Color(0.8, 0.8, 0.8))
	_status_label = _label(_resources_text(), FONT_SIZE, Color(0.6, 1.0, 0.7))
	var best: Genome = GameState.zone_best_genome(GameState.current_zone)
	if best != null:
		_label("Strongest strain of the zone: " + best.describe(), FONT_SIZE, Color(0.6, 0.6, 0.6))
	if not victory:
		_button("Workbench (weapons)", _open_panel.bind("workbench"))
		_button("Lab (research)", _open_panel.bind("lab"))
		_label("Coming later:", FONT_SIZE, Color(0.8, 0.8, 0.8))
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


func _resources_text() -> String:
	return "Samples %d   Scrap %d   Side objectives %d" % [GameState.samples, GameState.scrap, GameState.side_done.size()]


# --- Workbench and Lab ----------------------------------------------------------------------

func _open_panel(kind: String) -> void:
	_column.visible = false
	if _panel != null:
		_panel.queue_free()
	_panel = VBoxContainer.new()
	_panel.add_theme_constant_override("separation", 3)
	_center.add_child(_panel)
	if kind == "workbench":
		_build_workbench()
	else:
		_build_lab()
	var back: Button = _button_in(_panel, "Back", _close_panel)
	back.grab_focus()


func _close_panel() -> void:
	if _panel != null:
		_panel.queue_free()
		_panel = null
	_column.visible = true
	_status_label.text = _resources_text()
	(_column.get_children().filter(func(c: Node) -> bool: return c is Button and not c.disabled)[0] as Button).grab_focus()


func _refresh(kind: String) -> void:
	_open_panel(kind)


func _build_workbench() -> void:
	_label_in(_panel, "WORKBENCH", 12, Color(1.0, 0.85, 0.5))
	_label_in(_panel, _resources_text(), FONT_SIZE, Color(0.6, 1.0, 0.7))
	var l: PlayerLoadout = GameState.loadout
	_label_in(_panel, "In hand: %s    Spare: %s    (Q swaps in a level)" % [_weapon_name(l.equipped[0]),
			_weapon_name(l.equipped[1]) if l.equipped[1] != &"" else "-"], FONT_SIZE, Color(0.8, 0.8, 0.8))
	for id: StringName in WeaponLibrary.ids():
		var w: WeaponStats = WeaponLibrary.get_weapon(id)
		_label_in(_panel, "%s - %s" % [w.display_name, w.description], FONT_SIZE, Color(0.7, 0.7, 0.7))
		if l.is_owned(id):
			var row: HBoxContainer = HBoxContainer.new()
			row.add_theme_constant_override("separation", 3)
			_panel.add_child(row)
			_button_in(row, "Carry in hand", _equip.bind(id, 0)).disabled = l.equipped[0] == id
			if id != WeaponLibrary.PISTOL or l.equipped[0] != id:
				_button_in(row, "Carry as spare", _equip.bind(id, 1)).disabled = l.equipped[1] == id or l.equipped[0] == id and l.owned.size() < 2
		elif l.blueprints.has(id):
			var problem: String = l.build_problem(id, GameState.scrap)
			var b: Button = _button_in(_panel, "Build (%d scrap)" % w.unlock_cost_scrap, _build.bind(id))
			b.disabled = problem != ""
			b.tooltip_text = problem
		else:
			_label_in(_panel, "No blueprint yet - find one on a level or earn it.", FONT_SIZE, Color(0.5, 0.5, 0.5))


func _weapon_name(id: StringName) -> String:
	var w: WeaponStats = WeaponLibrary.get_weapon(id)
	return w.display_name if w != null else "-"


func _equip(id: StringName, slot: int) -> void:
	GameState.loadout.equip(id, slot)
	GameState.save_campaign()
	_refresh("workbench")


func _build(id: StringName) -> void:
	GameState.build_weapon(id)
	GameState.save_campaign()
	_refresh("workbench")


func _build_lab() -> void:
	var research: ResearchState = GameState.research()
	_label_in(_panel, "LAB", 12, Color(1.0, 0.85, 0.5))
	_label_in(_panel, _resources_text(), FONT_SIZE, Color(0.6, 1.0, 0.7))
	var cap: float = research.tree.group_caps.get(&"health", 0.0)
	_label_in(_panel, "Permanent extra max HP: +%d of +%d" % [roundi(research.group_total(&"health")), roundi(cap)],
			FONT_SIZE, Color(0.8, 0.8, 0.8))
	for node: ResearchNode in research.tree.nodes:
		var status: ResearchState.Status = research.status(node.id, GameState.scrap, GameState.samples, GameState.current_zone)
		_label_in(_panel, "%s - %s" % [node.display_name, node.description], FONT_SIZE, Color(0.7, 0.7, 0.7))
		var text: String = "Done" if status == ResearchState.Status.OWNED 				else "Research (%d samples, %d scrap)" % [node.cost_samples, node.cost_scrap]
		var b: Button = _button_in(_panel, text, _research_node.bind(node.id))
		b.disabled = status != ResearchState.Status.OK
		b.tooltip_text = ResearchState.describe(status)


func _research_node(id: StringName) -> void:
	GameState.buy_research(id)
	GameState.save_campaign()
	_refresh("lab")


func _label_in(parent: Control, text: String, size: int, color: Color) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(LABEL_WIDTH, 0)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	parent.add_child(l)
	return l


func _button_in(parent: Control, text: String, action: Callable) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(120 if parent is HBoxContainer else 180, 14)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.add_theme_font_size_override("font_size", FONT_SIZE)
	b.pressed.connect(action)
	parent.add_child(b)
	return b


func _label(text: String, size: int, color: Color) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Wrapped inside a fixed width: the genome line is wider than the 480 px viewport otherwise.
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(LABEL_WIDTH, 0)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	_column.add_child(l)
	return l


func _button(text: String, action: Callable) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(180, 15)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.add_theme_font_size_override("font_size", FONT_SIZE)
	b.pressed.connect(action)
	_column.add_child(b)
	return b

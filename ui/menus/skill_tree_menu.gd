class_name SkillTreeMenu
extends Control
## Greybox skill tree (GDD 7.3, prototype: 2 nodes per branch). K opens/closes it, Esc closes.
## Pauses the game while open. Clicking an available node buys it; the player's stats update
## at once (shown in the line at the bottom).

const BRANCH_NAMES: Array[String] = ["FIREPOWER", "FORTIFY", "ADAPT"]
const BRANCH_COLORS: Array[Color] = [Color(1.0, 0.55, 0.3), Color(0.45, 0.75, 1.0), Color(0.5, 0.9, 0.5)]
const COLOR_OWNED: Color = Color(0.5, 0.9, 0.5)
const COLOR_LOCKED: Color = Color(0.5, 0.5, 0.5)
const FONT_SIZE: int = 8
const NODE_SIZE: Vector2 = Vector2(124, 40)

var player: Player

var _body: VBoxContainer
## Pause state from before the menu opened (the Wave Report may already have paused the game).
var _was_paused: bool = false


func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS  # must work while the game is paused
	var backdrop: ColorRect = ColorRect.new()
	backdrop.color = Color(0, 0, 0, 0.6)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var panel: PanelContainer = PanelContainer.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.13, 0.14, 0.16, 0.97)
	style.border_color = Color(0.5, 0.5, 0.55)
	style.set_border_width_all(1)
	style.set_content_margin_all(6)
	panel.add_theme_stylebox_override("panel", style)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	add_child(panel)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 3)
	panel.add_child(_body)
	panel.resized.connect(func() -> void: panel.position = (size - panel.size) / 2.0)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("skill_tree"):
		get_viewport().set_input_as_handled()
		close() if visible else open()
	elif visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
	elif visible and event.is_action_pressed("ui_accept"):
		# Don't let Enter/Space reach the Wave Report's Continue underneath.
		get_viewport().set_input_as_handled()


func open() -> void:
	if player == null or visible:
		return
	_was_paused = get_tree().paused
	get_tree().paused = true
	get_viewport().gui_release_focus()
	_build()
	visible = true


func close() -> void:
	if not visible:
		return
	visible = false
	get_tree().paused = _was_paused


func _buy(id: StringName) -> void:
	if player.skills.unlock(id):
		print("[Skills] bought %s -> %s" % [id, _stats_text()])
	_build()


# --- Building the menu ---------------------------------------------------------------

func _build() -> void:
	for child: Node in _body.get_children():
		_body.remove_child(child)
		child.queue_free()
	var skills: PlayerSkills = player.skills
	_add_label(_body, "SKILL TREE        skill points: %d        (level %d)" % [
		skills.progression.skill_points, skills.progression.level], 10, Color.WHITE)

	var columns: HBoxContainer = HBoxContainer.new()
	columns.add_theme_constant_override("separation", 6)
	_body.add_child(columns)
	for branch: int in BRANCH_NAMES.size():
		var column: VBoxContainer = VBoxContainer.new()
		column.add_theme_constant_override("separation", 1)
		columns.add_child(column)
		_add_label(column, BRANCH_NAMES[branch], FONT_SIZE, BRANCH_COLORS[branch], HORIZONTAL_ALIGNMENT_CENTER)
		var nodes: Array[SkillNode] = skills.tree.branch_nodes(branch as SkillNode.Branch)
		for i: int in nodes.size():
			if i > 0:
				_add_label(column, "|", FONT_SIZE, COLOR_LOCKED, HORIZONTAL_ALIGNMENT_CENTER)
			column.add_child(_node_button(nodes[i]))

	_add_label(_body, "Now: " + _stats_text(), FONT_SIZE, Color(0.8, 0.8, 0.8))
	_add_label(_body, "Click a skill to buy it.   K / Esc: close", FONT_SIZE, COLOR_LOCKED)


func _node_button(node: SkillNode) -> Button:
	var status: PlayerSkills.Status = player.skills.check(node.id)
	var state: String
	var color: Color = Color.WHITE
	match status:
		PlayerSkills.Status.OWNED:
			state = "OWNED"
			color = COLOR_OWNED
		PlayerSkills.Status.OK:
			state = "click to buy"
		PlayerSkills.Status.MISSING_PREREQUISITE:
			state = "LOCKED: needs " + ", ".join(node.requires.map(_node_name))
			color = COLOR_LOCKED
		PlayerSkills.Status.NOT_ENOUGH_POINTS:
			state = "need %d point%s" % [node.cost, "" if node.cost == 1 else "s"]
			color = COLOR_LOCKED
	var button: Button = Button.new()
	button.text = "%s  (%d pt)\n%s\n%s" % [node.display_name, node.cost, node.description, state]
	button.custom_minimum_size = NODE_SIZE
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", FONT_SIZE)
	button.add_theme_color_override("font_color", color)
	button.add_theme_color_override("font_disabled_color", color)
	button.disabled = status != PlayerSkills.Status.OK
	button.pressed.connect(_buy.bind(node.id))
	return button


func _node_name(id: StringName) -> String:
	var node: SkillNode = player.skills.tree.get_node_by_id(id)
	return node.display_name if node != null else String(id)


## The stats the skills can change, as they are right now.
func _stats_text() -> String:
	var s: PlayerStats = player.stats
	var w: WeaponStats = player.weapon
	return "fire every %.2f s · damage %.1f · HP %.0f/%.0f · speed %.0f · dodge cd %.2f s · invuln %.2f s" % [
		w.fire_cooldown, w.damage, player.health, s.max_health, s.move_speed,
		s.dodge_cooldown, s.dodge_invulnerable_time]


func _add_label(parent: Control, text: String, font_size: int, color: Color,
		align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	var l: Label = Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	parent.add_child(l)

class_name GameOverScreen
extends Control
## Greybox Game Over screen: shown when the player goes down. The wave is lost (not bred, see
## WaveManager.fail_wave), so the only way on is Retry, which replays the same wave with the
## same Bloomed. Shows how the attempt went, and has the skill tree so XP earned in the
## attempt can be spent before retrying. Pauses the game while open.

const FONT_SIZE: int = 8
const COLOR_TITLE: Color = Color(1.0, 0.35, 0.3)
const COLOR_DIM: Color = Color(0.6, 0.6, 0.6)
const COLOR_TRAITS: Color = Color(1, 0.9, 0.5)

## Opens the skill tree (connected by the level).
signal skills_requested
## Retry pressed (button, Enter or Space). The level replays the wave.
signal retry_requested
## Main Menu pressed.
signal main_menu_requested

var wave_manager: WaveManager:
	set(value):
		wave_manager = value
		if wave_manager != null:
			wave_manager.wave_failed.connect(_on_wave_failed)
			wave_manager.wave_started.connect(_on_wave_started)

## Set by the level: level / XP lines and the unspent skill points on the Skills button.
var player: Player

var _body: VBoxContainer
var _retry_button: Button
var _skills_button: Button
## Player's total XP when the attempt started, for "XP this attempt".
var _xp_at_wave_start: int = 0


func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS  # must work while the game is paused
	var backdrop: ColorRect = ColorRect.new()
	backdrop.color = Color(0.1, 0, 0, 0.6)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel: PanelContainer = PanelContainer.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.13, 0.12, 0.12, 0.97)
	style.border_color = Color(0.7, 0.3, 0.3)
	style.set_border_width_all(1)
	style.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(300, 0)
	center.add_child(panel)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 2)
	panel.add_child(_body)


func _process(_delta: float) -> void:
	if visible:
		_update_skills_button()  # points change while the skill tree is open on top


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_on_retry()


func _on_wave_started(_wave: int) -> void:
	if player != null:
		_xp_at_wave_start = player.progression.total_xp
	if visible:
		visible = false
		get_tree().paused = false


func _on_wave_failed(summary: Dictionary) -> void:
	_build(summary)
	visible = true
	if wave_manager.pause_between_waves:
		get_tree().paused = true
	_retry_button.grab_focus()


func _on_retry() -> void:
	visible = false
	get_tree().paused = false
	retry_requested.emit()


# --- Building the screen -------------------------------------------------------------

func _build(s: Dictionary) -> void:
	for child: Node in _body.get_children():
		child.queue_free()
	var seconds: int = int(s["wave_seconds"])
	var total: int = s["killed"] + s["survived"]
	var c: Dictionary = s["component_means"]

	_label("YOU WERE DOWNED", 12, COLOR_TITLE)
	_label("Wave %d  (generation %d)" % [s["wave"], s["generation"]], FONT_SIZE, Color.WHITE)
	_spacer()
	_label("Survived %d:%02d   |   Bloomed killed %d / %d" % [seconds / 60, seconds % 60, s["killed"], total])
	if player != null:
		var p: PlayerProgression = player.progression
		_label("Level %d   |   XP this attempt +%d   |   %d / %d XP to next level" % [
			p.level, p.total_xp - _xp_at_wave_start, p.xp, p.xp_to_next()])
	_label("Bloomed fitness  best %.3f   average %.3f   (avg  D %.2f  P %.2f  S %.2f  O %.2f)" % [
		s["best_fitness"], s["mean_fitness"], c[Fitness.D], c[Fitness.P], c[Fitness.S], c[Fitness.O]], FONT_SIZE, COLOR_DIM)
	if not s["gene_means"].is_empty():
		_label("Their traits:  " + WaveReport.dominant_traits(s["gene_means"], false), FONT_SIZE, COLOR_TRAITS)
	_label("Deadliest: " + s["best_genome"], FONT_SIZE, COLOR_DIM)
	_spacer()
	_label("Retry replays this wave with the same Bloomed.\nThey only evolve once you clear it. XP and skills are kept.", FONT_SIZE, COLOR_DIM)
	_spacer()

	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 8)
	_body.add_child(buttons)
	_skills_button = _button(buttons, "Skills (K)", skills_requested.emit)
	_skills_button.focus_mode = Control.FOCUS_NONE  # Enter stays on Retry
	_update_skills_button()
	_retry_button = _button(buttons, "Retry  (Enter)", _on_retry)
	var menu_button: Button = _button(buttons, "Main Menu", main_menu_requested.emit)
	menu_button.focus_mode = Control.FOCUS_NONE


## "Skills (K)", highlighted with the count when there are points to spend.
func _update_skills_button() -> void:
	if _skills_button == null or player == null:
		return
	var points: int = player.progression.skill_points
	_skills_button.text = "Skills (K)  -  %d point%s to spend" % [points, "" if points == 1 else "s"] if points > 0 else "Skills (K)"
	_skills_button.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4) if points > 0 else Color.WHITE)


func _button(parent: Control, text: String, action: Callable) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", FONT_SIZE)
	b.pressed.connect(action)
	parent.add_child(b)
	return b


func _label(text: String, font_size: int = FONT_SIZE, color: Color = Color.WHITE) -> void:
	var l: Label = Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	_body.add_child(l)


func _spacer() -> void:
	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(0, 3)
	_body.add_child(spacer)

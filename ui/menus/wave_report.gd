class_name WaveReport
extends Control
## Greybox Wave Report (GDD 9.1): shown after every wave once the GA has bred the next
## generation. Pauses the game until Continue (button, Enter or Space) when
## WaveManager.pause_between_waves is on; otherwise it stays up until the next wave starts.
## Shows how the wave went and what evolution changed, so the GA is visible to the player.

## Genes in the change table: [gene name, label, decimals].
const TABLE_GENES: Array[Array] = [
	["speed", "Speed", 1], ["health", "Health", 1], ["vision", "Vision", 1],
	["aggression", "Aggression", 2], ["flanking", "Flanking", 2], ["patience", "Patience", 2],
]
## Change smaller than this (in gene units) shows as "=": stats 1..10, behaviour 0..1.
const STAT_NOISE: float = 0.05
const BEHAVIOUR_NOISE: float = 0.01
## Trait words for genes far from average: gene -> [word when high, word when low].
const TRAIT_WORDS: Dictionary = {
	"speed": ["fast", "slow"], "health": ["tough", "fragile"], "vision": ["sharp-eyed", "short-sighted"],
	"aggression": ["aggressive", "timid"], "caution": ["cautious", "reckless"],
	"flanking": ["flankers", "head-on"], "cohesion": ["pack hunters", "loners"],
	"patience": ["patient hunters", "lazy"],
}
const COLOR_UP: Color = Color(1.0, 0.55, 0.3)
const COLOR_DOWN: Color = Color(0.45, 0.75, 1.0)
const COLOR_SAME: Color = Color(0.6, 0.6, 0.6)
const FONT_SIZE: int = 8

var wave_manager: WaveManager:
	set(value):
		wave_manager = value
		if wave_manager != null:
			wave_manager.generation_bred.connect(_on_generation_bred)
			wave_manager.wave_started.connect(_on_wave_started)

## Set by the level: for the unspent skill points shown on the Skills button.
var player: Player
## Opens the skill tree (connected by the level).
signal skills_requested

var _body: VBoxContainer
var _continue_button: Button
var _skills_button: Button


func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS  # must work while the game is paused
	var backdrop: ColorRect = ColorRect.new()
	backdrop.color = Color(0, 0, 0, 0.55)
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
	panel.custom_minimum_size = Vector2(400, 0)
	add_child(panel)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 1)
	panel.add_child(_body)
	panel.resized.connect(func() -> void: panel.position = (size - panel.size) / 2.0)


func _process(_delta: float) -> void:
	if visible:
		_update_skills_button()  # points change while the skill tree is open on top


## "Skills (K)", highlighted with the count when there are points to spend.
func _update_skills_button() -> void:
	if _skills_button == null or player == null:
		return
	var points: int = player.progression.skill_points
	_skills_button.text = "Skills (K)  -  %d point%s to spend" % [points, "" if points == 1 else "s"] if points > 0 else "Skills (K)"
	_skills_button.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4) if points > 0 else Color.WHITE)


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_on_continue()


func _on_generation_bred(summary: Dictionary) -> void:
	_build(summary)
	visible = true
	# Pause only when the game waits for Continue; with the intermission countdown the report
	# just stays up until the next wave starts.
	if wave_manager.pause_between_waves:
		get_tree().paused = true
	_continue_button.grab_focus()


func _on_wave_started(_wave: int) -> void:
	# The next wave started (Continue, F3, ...): close the report and resume.
	if visible:
		visible = false
		get_tree().paused = false


func _on_continue() -> void:
	visible = false
	get_tree().paused = false
	if wave_manager != null:
		wave_manager.continue_to_next_wave()


# --- Building the report -------------------------------------------------------------

func _build(s: Dictionary) -> void:
	for child: Node in _body.get_children():
		child.queue_free()
	var before: Dictionary = s["means_before"]
	var after: Dictionary = s["means_after"]
	var c: Dictionary = s["component_means"]

	_label("WAVE %d REPORT" % s["from_wave"], 10, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	_label("%d killed, %d survived in %.0f s   |   next: wave %d = generation %d (stat budget %d)" % [
		s["killed"], s["survived"], s["wave_seconds"], s["from_wave"] + 1, s["generation"], s["budget"]],
		FONT_SIZE, COLOR_SAME, HORIZONTAL_ALIGNMENT_CENTER)
	_label("Fitness  best %.3f   average %.3f      (avg  D %.2f  P %.2f  S %.2f  O %.2f)" % [
		s["best_fitness"], s["mean_fitness"], c[Fitness.D], c[Fitness.P], c[Fitness.S], c[Fitness.O]])
	_label("Fitness history (best / avg):  " + _history_text(), FONT_SIZE, COLOR_SAME)
	_label("Dominant traits:  " + dominant_traits(after), FONT_SIZE, Color(1, 0.9, 0.5))
	_spacer()

	var grid: GridContainer = GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 0)
	_body.add_child(grid)
	for header: String in ["Gene (average)", "Wave %d" % s["from_wave"], "Next wave", "Change"]:
		_cell(grid, header, Color(0.8, 0.8, 0.85))
	for row: Array in TABLE_GENES:
		var gene: String = row[0]
		var fmt: String = "%." + str(row[2]) + "f"
		var delta: float = after[gene] - before[gene]
		var noise: float = STAT_NOISE if Genome.STAT_GENES.has(StringName(gene)) else BEHAVIOUR_NOISE
		_cell(grid, row[1], Color.WHITE)
		_cell(grid, fmt % before[gene], COLOR_SAME)
		_cell(grid, fmt % after[gene], Color.WHITE)
		if absf(delta) < noise:
			_cell(grid, "=", COLOR_SAME)
		else:
			_cell(grid, ("^ +" if delta > 0.0 else "v ") + (fmt % delta), COLOR_UP if delta > 0.0 else COLOR_DOWN)
	_spacer()
	_label("Path modes:  wave %d  %s    ->    next  %s%s" % [
		s["from_wave"], _modes_text(s["path_modes_before"]), _modes_text(s["path_modes"]),
		"   (diversity guard ON: mutation x2)" if s["diversity_guard"] else ""])
	_label("Best genome: " + s["best_genome"], FONT_SIZE, COLOR_SAME)
	_spacer()
	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 8)
	_body.add_child(buttons)
	_skills_button = Button.new()
	_skills_button.add_theme_font_size_override("font_size", FONT_SIZE)
	_skills_button.focus_mode = Control.FOCUS_NONE  # Enter stays on Continue
	_skills_button.pressed.connect(skills_requested.emit)
	buttons.add_child(_skills_button)
	_update_skills_button()
	_continue_button = Button.new()
	_continue_button.text = "Continue  (Enter)"
	_continue_button.add_theme_font_size_override("font_size", FONT_SIZE)
	_continue_button.pressed.connect(_on_continue)
	buttons.add_child(_continue_button)


## The 3 gene averages furthest from "average" (5 for stats, 0.5 for behaviour), as words.
## Also used by the HUD (without the numbers).
static func dominant_traits(means: Dictionary, show_values: bool = true) -> String:
	var scored: Array = []
	for gene: String in TRAIT_WORDS:
		var is_stat: bool = Genome.STAT_GENES.has(StringName(gene))
		var deviation: float = (means[gene] - 5.0) / 4.5 if is_stat else (means[gene] - 0.5) / 0.5
		scored.append([absf(deviation), gene, deviation])
	scored.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	var words: PackedStringArray = PackedStringArray()
	for i: int in 3:
		var entry: Array = scored[i]
		if entry[0] < 0.1:
			break
		var gene: String = entry[1]
		var word: String = TRAIT_WORDS[gene][0 if entry[2] > 0.0 else 1]
		words.append("%s (%s %.2f)" % [word, gene, means[gene]] if show_values else word)
	if words.is_empty():
		return "balanced (no gene far from average)" if show_values else "balanced"
	return ", ".join(words)


func _history_text() -> String:
	var parts: PackedStringArray = PackedStringArray()
	var start: int = maxi(wave_manager.history.size() - 6, 0)
	for i: int in range(start, wave_manager.history.size()):
		var h: Dictionary = wave_manager.history[i]
		parts.append("w%d %.2f/%.2f" % [h["from_wave"], h["best_fitness"], h["mean_fitness"]])
	return "  ".join(parts)


static func _modes_text(counts: Dictionary) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for mode: String in Genome.PathMode.keys():
		parts.append("%s %d" % [mode, counts.get(mode, 0)])
	return " ".join(parts)


func _label(text: String, font_size: int = FONT_SIZE, color: Color = Color.WHITE,
		align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	var l: Label = Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	_body.add_child(l)


func _cell(grid: GridContainer, text: String, color: Color) -> void:
	var l: Label = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", FONT_SIZE)
	l.add_theme_color_override("font_color", color)
	grid.add_child(l)


func _spacer() -> void:
	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(0, 3)
	_body.add_child(spacer)

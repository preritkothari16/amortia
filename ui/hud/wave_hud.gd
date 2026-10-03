class_name WaveHud
extends Control
## Greybox top HUD bar (GDD 9.1). Left: wave, generation and the current objective/status.
## Right: the dominant traits of the Runners in play, so evolution is visible mid-wave.
## Detailed gene numbers stay in the Wave Report and the F7 overlay.

const FONT_SIZE: int = 8
const COLOR_TRAITS: Color = Color(1.0, 0.9, 0.5)
const COLOR_STATUS: Color = Color(0.8, 0.8, 0.8)

var wave_manager: WaveManager

var _left: Label
var _right: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS  # keep the status right while the report pauses
	var bar: ColorRect = ColorRect.new()
	bar.color = Color(0, 0, 0, 0.45)
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.custom_minimum_size = Vector2(0, 21)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bar)
	# Both labels span the bar; alignment puts one on each side.
	_left = _make_label(HORIZONTAL_ALIGNMENT_LEFT)
	_right = _make_label(HORIZONTAL_ALIGNMENT_RIGHT)


func _process(_delta: float) -> void:
	if wave_manager == null:
		return
	var wm: WaveManager = wave_manager
	_left.text = "WAVE %d   generation %d\n%s" % [wm.wave_number, wm.generation, _status(wm)]
	var traits: String = "-"
	if not wm.population.is_empty() and wm.population[0] != null:
		traits = WaveReport.dominant_traits(WaveManager.gene_means(wm.population), false)
	_right.text = "Bloomed traits\n" + traits
	_right.add_theme_color_override("font_color", COLOR_TRAITS)


## One line: what the player should be doing right now.
func _status(wm: WaveManager) -> String:
	if wm.waiting_for_continue:
		return "Wave cleared - read the report, then Continue"
	if wm.intermission_left >= 0.0:
		return "Next wave in %.1f s" % wm.intermission_left
	var seconds: int = int(wm.wave_seconds)
	return "Objective: survive and clear the wave   %d / %d left   %d:%02d" % [
		wm.alive.size(), wm.population.size(), seconds / 60, seconds % 60]


func _make_label(align: HorizontalAlignment) -> Label:
	var l: Label = Label.new()
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", FONT_SIZE)
	l.add_theme_color_override("font_color", COLOR_STATUS)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 2)
	l.add_theme_constant_override("line_spacing", -2)
	add_child(l)
	l.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	l.offset_left = 4.0
	l.offset_right = -4.0
	l.offset_top = 1.0
	return l

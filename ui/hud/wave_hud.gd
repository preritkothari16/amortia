class_name WaveHud
extends Control
## Greybox top HUD bar (GDD 9.1). Left: wave, generation and the current objective/status.
## Right: the dominant traits of the Runners in play, so evolution is visible mid-wave.
## Detailed gene numbers stay in the Wave Report and the F7 overlay. A status line too long to sit
## beside the traits moves to a third, full-width line and the bar grows to fit it.

const FONT_SIZE: int = 8
const COLOR_TRAITS: Color = Color(1.0, 0.9, 0.5)
const COLOR_STATUS: Color = Color(0.8, 0.8, 0.8)
## Minimum space between the status line and the traits on its right, in px.
const GAP: float = 12.0
const BAR_HEIGHT: float = 21.0
const BAR_HEIGHT_TALL: float = 30.0

var wave_manager: WaveManager
## Campaign: the area sequencer supplies the status line (null in the prototype).
var level_flow: LevelFlow
## Optional: terrain event messages ("Night falls in 5 s").
var terrain_events: TerrainEvents

var _bar: ColorRect
var _left: Label
var _right: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS  # keep the status right while the report pauses
	_bar = ColorRect.new()
	_bar.color = Color(0, 0, 0, 0.45)
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bar)
	_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_bar.offset_bottom = BAR_HEIGHT
	# Both labels span the bar; alignment puts one on each side.
	_left = _make_label(HORIZONTAL_ALIGNMENT_LEFT)
	_left.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS  # last resort: never off-screen
	_right = _make_label(HORIZONTAL_ALIGNMENT_RIGHT)


func _process(_delta: float) -> void:
	if wave_manager == null:
		return
	var wm: WaveManager = wave_manager
	var traits: String = "-"
	if not wm.population.is_empty() and wm.population[0] != null:
		traits = WaveReport.dominant_traits(WaveManager.gene_means(wm.population), false)
	show_lines("WAVE %d   generation %d" % [wm.wave_number, wm.generation], _status(wm), traits)


## Lays out the bar: head and status on the left, traits on the right. A status that would run into
## the traits goes on its own line below them.
func show_lines(head: String, status: String, traits: String) -> void:
	_right.text = "Bloomed traits\n" + traits
	_right.add_theme_color_override("font_color", COLOR_TRAITS)
	var right_width: float = maxf(_width("Bloomed traits"), _width(traits))
	var fits: bool = _width(status) + GAP + right_width <= _left.size.x
	_left.text = head + ("\n" if fits else "\n\n") + status
	_bar.offset_bottom = BAR_HEIGHT if fits else BAR_HEIGHT_TALL


## True while the status sits on its own line below the traits.
func is_status_below() -> bool:
	return _left.text.contains("\n\n")


func _width(text: String) -> float:
	return _left.get_theme_font("font").get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x


## One line: what the player should be doing right now.
func _status(wm: WaveManager) -> String:
	if wm.failed:
		return "You were downed - retry the wave"
	var event_text: String = terrain_events.status_text() if terrain_events != null else ""
	if level_flow != null:
		return level_flow.status_text() + ("   [%s]" % event_text if event_text != "" else "")
	if event_text != "":
		return event_text
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

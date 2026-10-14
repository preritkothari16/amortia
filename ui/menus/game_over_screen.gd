class_name GameOverScreen
extends ReportScreen
## Downed screen: shown when the player goes down. The wave is lost (not bred, see
## WaveManager.fail_wave), so the way on is Retry, which replays the same wave with the same
## Bloomed. Shows how the attempt went (time, kills, XP), what got you (the Bloomed that dealt
## the most damage, in plain words, with one tip), and has the skill tree so XP earned in the
## attempt can be spent before retrying. Raw genome in Details (D). Pauses the game while open.
## Layout and keys: ReportScreen. One scene (game_over_screen.tscn), built once, refilled.

## Retry pressed (button, Enter or Space). The level replays the wave.
signal retry_requested
## Main Menu pressed.
signal main_menu_requested
## Restart level pressed (campaign: the whole level from wave 1, XP and evolution kept).
signal restart_level_requested

## Show the Restart level button (campaign levels).
var allow_level_restart: bool = false:
	set(v):
		allow_level_restart = v
		if _restart_button != null:
			_restart_button.visible = v

var wave_manager: WaveManager:
	set(value):
		wave_manager = value
		if wave_manager != null:
			wave_manager.wave_failed.connect(_on_wave_failed)
			wave_manager.wave_started.connect(_on_wave_started)

var _retry_button: Button
var _restart_button: Button
var _subtitle: Label
var _time: Label
var _kills_bar: UiBar
var _kills: Label
var _level: Label
var _xp_bar: UiBar
var _xp: Label
var _xp_gain: Label
var _culprit: Label
var _tip: Label
var _details: VBoxContainer
## Player's total XP when the attempt started, for "+XP this attempt".
var _xp_at_wave_start: int = 0


func _ready() -> void:
	super()
	# A narrower panel than the report: less to show.
	_frame.add_theme_constant_override("margin_left", 48)
	_frame.add_theme_constant_override("margin_right", 48)


# --- Layout (built once) ------------------------------------------------------------------

func _build_header(root: VBoxContainer) -> void:
	var head: VBoxContainer = vbox(root, false, 0)
	label(head, "DOWNED", &"DangerTitleLabel").horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle = label(head, "", &"MutedLabel")
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _build_pages() -> void:
	var page: VBoxContainer = add_page("overview")
	var attempt: VBoxContainer = card(page, "This attempt")
	var grid: GridContainer = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("v_separation", 3)
	attempt.add_child(grid)
	label(grid, "Time survived", &"MutedLabel")
	spacer(grid)
	_time = label(grid, "")
	_time.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label(grid, "Bloomed killed", &"MutedLabel")
	_kills_bar = UiBar.new()
	_kills_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(_kills_bar)
	_kills = label(grid, "")
	_kills.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_level = label(grid, "", &"MutedLabel")
	_xp_bar = UiBar.new()
	_xp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_xp_bar.fill_color = &"down"
	grid.add_child(_xp_bar)
	var xp_row: HBoxContainer = hbox(grid)
	xp_row.alignment = BoxContainer.ALIGNMENT_END
	_xp = label(xp_row, "")
	var gain: PanelContainer = PanelContainer.new()
	gain.theme_type_variation = &"AccentChip"
	gain.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	xp_row.add_child(gain)
	_xp_gain = label(gain, "", &"AccentLabel")

	var got: VBoxContainer = card(page, "What got you", true)
	_culprit = label(got, "", &"", true)
	_tip = label(got, "", &"AccentLabel", true)

	var strip: VBoxContainer = card(page)
	label(strip, "Retry replays this wave with the same Bloomed. They only evolve when you clear it. Your XP and skills are kept.",
		&"MutedLabel", true)

	var details: VBoxContainer = card(add_page("details"), "", true)
	label(details, "Details (raw data)", &"SectionLabel")
	_details = vbox(details, false, 1)


func _build_footer(root: VBoxContainer) -> void:
	var row: HBoxContainer = hbox(root)
	add_details_button(row)
	add_button(row, "Main Menu", main_menu_requested.emit, &"TertiaryButton")
	spacer(row)
	_restart_button = add_button(row, "Restart level", _on_restart_level, &"")
	_restart_button.visible = allow_level_restart
	add_skills_button(row)
	_retry_button = add_button(row, "Retry (Enter)", _on_retry, &"PrimaryButton")


func _primary_button() -> Button:
	return _retry_button


func _primary_action() -> void:
	_on_retry()


# --- Opening / closing --------------------------------------------------------------------

func _on_wave_started(_wave: int) -> void:
	if player != null:
		_xp_at_wave_start = player.progression.total_xp
	if visible:
		visible = false
		get_tree().paused = false


func _on_wave_failed(summary: Dictionary) -> void:
	fill(summary)
	present()
	if wave_manager.pause_between_waves:
		get_tree().paused = true


func _on_restart_level() -> void:
	skip_motion()
	visible = false
	get_tree().paused = false
	restart_level_requested.emit()


func _on_retry() -> void:
	skip_motion()
	visible = false
	get_tree().paused = false
	retry_requested.emit()


# --- Filling --------------------------------------------------------------------------------

func fill(s: Dictionary) -> void:
	var seconds: int = int(s["wave_seconds"])
	var total: int = s["killed"] + s["survived"]
	_subtitle.text = "Wave %d  ·  Generation %d" % [s["wave"], s["generation"]]
	_time.text = "%d:%02d" % [seconds / 60, seconds % 60]
	count_up(_kills, "%d / " + str(total), s["killed"])
	tween_bar(_kills_bar, "value", 0.0, float(s["killed"]) / maxf(total, 1))
	if player != null:
		var p: PlayerProgression = player.progression
		var need: int = p.xp_to_next()
		_level.text = "Level %d" % p.level
		_xp.text = "%d / %d XP" % [p.xp, need] if need > 0 else "Max level"
		_xp_gain.text = "+%d XP" % (p.total_xp - _xp_at_wave_start)
		tween_bar(_xp_bar, "value", 0.0, float(p.xp) / need if need > 0 else 1.0)

	var culprit: Dictionary = deadliest()
	if culprit.is_empty():
		_culprit.text = "No Bloomed reached you this time."
		_tip.text = ""
	else:
		var g: Genome = culprit["genome"]
		var dealt: float = (culprit["record"] as FitnessRecord).damage_dealt
		_culprit.text = "The deadliest was %s. It dealt %d damage%s." % [GeneInfo.describe_plain(g), roundi(dealt),
			"" if (culprit["record"] as FitnessRecord).died else " and is still standing"]
		_tip.text = "Tip: " + GeneInfo.tip_for(g)
	_fill_details(s, culprit)


## The enemy of the lost wave that dealt the most damage (best fitness on a tie / no damage):
## {genome, record, fitness, components} from WaveManager.last_wave_results, or {}.
func deadliest() -> Dictionary:
	if wave_manager == null or wave_manager.last_wave_results.is_empty():
		return {}
	var best: Dictionary = wave_manager.last_wave_results[0]
	for r: Dictionary in wave_manager.last_wave_results:
		if (r["record"] as FitnessRecord).damage_dealt > (best["record"] as FitnessRecord).damage_dealt:
			best = r
	return best


func _fill_details(s: Dictionary, culprit: Dictionary) -> void:
	clear(_details)
	var c: Dictionary = s["component_means"]
	label(_details, "Deadliest genome: " + ((culprit["genome"] as Genome).describe() if not culprit.is_empty() else "-"),
		&"SmallTextLabel", true)
	if not culprit.is_empty():
		var cc: Dictionary = culprit["components"]
		label(_details, "Its fitness %.3f  (D %.3f  P %.3f  S %.3f  O %.3f)  raw: %s" % [culprit["fitness"],
			cc[Fitness.D], cc[Fitness.P], cc[Fitness.S], cc[Fitness.O], (culprit["record"] as FitnessRecord).to_dict()],
			&"SmallTextLabel", true)
	label(_details, "Highest fitness: " + s["best_genome"], &"SmallTextLabel", true)
	label(_details, "Wave fitness best %.3f  mean %.3f  |  mean D %.3f  P %.3f  S %.3f  O %.3f  |  not bred (lost wave)" % [
		s["best_fitness"], s["mean_fitness"], c[Fitness.D], c[Fitness.P], c[Fitness.S], c[Fitness.O]], &"SmallTextLabel", true)
	if not s["gene_means"].is_empty():
		label(_details, "Traits (population): " + WaveReport.dominant_traits(s["gene_means"]), &"SmallLabel", true)

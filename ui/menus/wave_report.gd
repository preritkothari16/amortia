class_name WaveReport
extends ReportScreen
## Wave Report (GDD 9.1), shown after a wave once the GA has bred the next generation.
## Pauses the game until Continue (button, Enter or Space) when
## WaveManager.pause_between_waves is on; otherwise it stays up until the next wave starts.
## Shows how the wave went and what evolution changed, in plain words: header, a one-line
## story with trait chips, how they changed (top 4, "Show all" by group), how they hunt (route
## strategy), how deadly they were (fitness + history), what to expect. Details (D) keeps the
## raw genome and numbers (viva). Layout and keys: ReportScreen. One scene for every wave
## (wave_report.tscn); the node tree is built once and refilled.

## Genes shown in the overview ("How they changed").
const TOP_CHANGES: int = 4
## Trait words for genes far from average: gene -> [word when high, word when low].
## Kept for the HUD's dominant_traits() line.
const TRAIT_WORDS: Dictionary = {
	"speed": ["fast", "slow"], "health": ["tough", "fragile"], "vision": ["sharp-eyed", "short-sighted"],
	"aggression": ["aggressive", "timid"], "caution": ["cautious", "reckless"],
	"flanking": ["flankers", "head-on"], "cohesion": ["pack hunters", "loners"],
	"patience": ["patient hunters", "lazy"],
}
const HISTORY_SHOWN: int = 12

var wave_manager: WaveManager:
	set(value):
		wave_manager = value
		if wave_manager != null:
			wave_manager.generation_bred.connect(_on_generation_bred)
			wave_manager.wave_started.connect(_on_wave_started)

## Continue pressed (button, Enter or Space).
signal continue_pressed

## Open as soon as a generation is bred (prototype). Off: the level opens it later with
## open_last() (campaign: when the player walks out of the area).
var auto_open: bool = true
## Continue also starts the next wave on the WaveManager (prototype). Off: whoever listens
## to continue_pressed decides (campaign: load the next area first).
var drives_wave_manager: bool = true
## The latest bred-generation summary (for open_last()).
var last_summary: Dictionary = {}

var _continue_button: Button
var _title: Label
var _subtitle: Label
var _next_chip: Label
var _story: Label
var _trait_chips: HBoxContainer
var _changes: GridContainer
var _show_all_button: Button
var _hunt_now: SegmentBar
var _hunt_next: SegmentBar
var _hunt_legend: HBoxContainer
var _best_value: Label
var _mean_value: Label
var _spark: Sparkline
var _components: Label
var _expect: VBoxContainer
var _all_columns: Array[VBoxContainer] = []
var _details: VBoxContainer


# --- Layout (built once) ------------------------------------------------------------------

func _build_header(root: VBoxContainer) -> void:
	var row: HBoxContainer = hbox(root)
	var left: VBoxContainer = vbox(row, true, 0)
	_title = label(left, "", &"TitleLabel")
	_subtitle = label(left, "", &"MutedLabel")
	var chip: PanelContainer = PanelContainer.new()
	chip.theme_type_variation = &"AccentChip"
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(chip)
	_next_chip = label(chip, "", &"AccentLabel")


func _build_pages() -> void:
	_build_overview(add_page("overview"))
	_build_all_genes(add_page("all"))
	_build_details(add_page("details"))


func _build_overview(page: VBoxContainer) -> void:
	var story: HBoxContainer = hbox(card(page))
	_story = label(story, "", &"", true)
	_trait_chips = hbox(story)
	_trait_chips.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var columns: HBoxContainer = hbox(page)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var left: VBoxContainer = vbox(columns, true)
	var right: VBoxContainer = vbox(columns, true)

	var changed: VBoxContainer = card(left, "", true)
	var head: HBoxContainer = hbox(changed)
	label(head, "How they changed", &"SectionLabel").size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_show_all_button = add_button(head, "Show all", show_page.bind("all"), &"TertiaryButton")
	_changes = _gene_grid(changed)

	var hunt: VBoxContainer = card(left)
	var hunt_head: HBoxContainer = hbox(hunt)
	label(hunt_head, "How they hunt", &"SectionLabel")
	var note: Label = label(hunt_head, "(no effect yet)", &"SmallLabel")
	note.size_flags_vertical = Control.SIZE_SHRINK_END
	note.tooltip_text = GeneInfo.PATH_MODE_NOTE
	note.mouse_filter = Control.MOUSE_FILTER_PASS
	var bars: GridContainer = GridContainer.new()
	bars.columns = 2
	hunt.add_child(bars)
	label(bars, "This wave", &"SmallLabel")
	_hunt_now = SegmentBar.new()
	_hunt_now.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bars.add_child(_hunt_now)
	label(bars, "Next wave", &"SmallLabel")
	_hunt_next = SegmentBar.new()
	_hunt_next.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bars.add_child(_hunt_next)
	_hunt_legend = hbox(hunt)

	var deadly: VBoxContainer = card(right, "How deadly they were")
	var nums: HBoxContainer = hbox(deadly)
	var best: VBoxContainer = vbox(nums, false, 0)
	label(best, "Best", &"SmallLabel")
	_best_value = label(best, "", &"SectionLabel")
	_best_value.add_theme_color_override("font_color", get_theme_color(&"accent", &"Palette"))
	var mean: VBoxContainer = vbox(nums, false, 0)
	label(mean, "Average", &"SmallLabel")
	_mean_value = label(mean, "", &"SectionLabel")
	_spark = Sparkline.new()
	_spark.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_spark.tooltip_text = "Fitness per wave: best (gold) and average (grey). 0 = harmless, 1 = deadliest."
	nums.add_child(_spark)
	_components = label(deadly, "", &"SmallLabel", true)

	var expect: VBoxContainer = card(right, "What to expect", true)
	_expect = vbox(expect, false, 1)


func _build_all_genes(page: VBoxContainer) -> void:
	var box: VBoxContainer = card(page, "", true)
	var head: HBoxContainer = hbox(box)
	label(head, "How they changed: all genes", &"SectionLabel").size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_button(head, "Back to summary", show_page.bind("overview"), &"TertiaryButton")
	var columns: HBoxContainer = hbox(box)
	_all_columns = [vbox(columns, true, 1), vbox(columns, true, 1)]
	label(box, "Grey names evolve but have no effect in the game yet. Hover a name for what it does.", &"SmallLabel", true)


func _build_details(page: VBoxContainer) -> void:
	var box: VBoxContainer = card(page, "", true)
	label(box, "Details (raw data)", &"SectionLabel")
	_details = vbox(box, false, 1)


func _build_footer(root: VBoxContainer) -> void:
	var row: HBoxContainer = hbox(root)
	add_details_button(row)
	spacer(row)
	add_skills_button(row)
	_continue_button = add_button(row, "Continue (Enter)", _on_continue, &"PrimaryButton")


func _primary_button() -> Button:
	return _continue_button


func _primary_action() -> void:
	_on_continue()


## 4-column grid: gene name, before -> after bar, values, change pill.
func _gene_grid(parent: Node) -> GridContainer:
	var g: GridContainer = GridContainer.new()
	g.columns = 4
	g.add_theme_constant_override("v_separation", 2)
	parent.add_child(g)
	return g


# --- Opening / closing --------------------------------------------------------------------

func _on_generation_bred(summary: Dictionary) -> void:
	last_summary = summary
	if not auto_open:
		return
	fill(summary)
	present()
	# Pause only when the game waits for Continue; with the intermission countdown the report
	# just stays up until the next wave starts.
	if wave_manager.pause_between_waves:
		get_tree().paused = true


## Shows the report of the last bred generation and pauses until Continue.
func open_last() -> void:
	if last_summary.is_empty():
		continue_pressed.emit()
		return
	fill(last_summary)
	present()
	get_tree().paused = true


func _on_wave_started(_wave: int) -> void:
	# The next wave started (Continue, F3, ...): close the report and resume.
	if visible:
		visible = false
		get_tree().paused = false


func _on_continue() -> void:
	skip_motion()
	visible = false
	get_tree().paused = false
	continue_pressed.emit()
	if drives_wave_manager and wave_manager != null:
		wave_manager.continue_to_next_wave()


# --- Filling (every wave, same nodes) -------------------------------------------------------

func fill(s: Dictionary) -> void:
	var before: Dictionary = s["means_before"]
	var after: Dictionary = s["means_after"]
	var seconds: int = int(s["wave_seconds"])
	_title.text = "WAVE %d CLEARED" % s["from_wave"]
	_subtitle.text = "%d killed, %d got away  ·  %d:%02d" % [s["killed"], s["survived"], seconds / 60, seconds % 60]
	_next_chip.text = "Next: Wave %d · Generation %d" % [s["from_wave"] + 1, s["generation"]]

	var changes: Array[Array] = GeneInfo.ranked_changes(before, after)
	_story.text = GeneInfo.story_sentence(s["generation"], changes)
	clear(_trait_chips)
	var chips: Array = []
	for t: Array in GeneInfo.standout_traits(after):
		chips.append(_trait_chip(t[0], t[1], after[t[0]]))
	if chips.is_empty():
		chips.append(_trait_chip("", "Balanced", 0.5))
	stagger_in(chips)

	clear(_changes)
	for i: int in mini(TOP_CHANGES, changes.size()):
		_gene_row(_changes, changes[i], i)
	_fill_all_genes(before, after)
	_fill_hunt(s)
	_fill_deadly(s)

	clear(_expect)
	for line: String in GeneInfo.expectations(changes):
		label(_expect, "•  " + line, &"", true)
	_fill_details(s)


func _trait_chip(gene: String, word: String, value: float) -> PanelContainer:
	var chip: PanelContainer = PanelContainer.new()
	chip.theme_type_variation = &"Chip"
	_trait_chips.add_child(chip)
	var row: HBoxContainer = hbox(chip)
	row.add_theme_constant_override("separation", 3)
	label(row, word, &"SmallTextLabel")
	var bar: UiBar = UiBar.new()
	bar.custom_minimum_size = Vector2(20, 3)
	row.add_child(bar)
	if gene != "":
		chip.tooltip_text = "%s %s (average). %s" % [GeneInfo.gene_name(gene), GeneInfo.format_value(gene, value),
			GeneInfo.MEANINGS[gene]]
		tween_bar(bar, "value", 0.0, GeneInfo.normalized(gene, value))
	else:
		chip.tooltip_text = "No gene stands out from the average."
		bar.value = 0.5
	return chip


## One "how they changed" row: name, bar (fill = next wave, marker = this wave), values, pill.
func _gene_row(grid: GridContainer, row: Array, index: int) -> void:
	var gene: String = row[0]
	var before: float = row[1]
	var after: float = row[2]
	var delta: float = row[3]
	var notable: bool = GeneInfo.is_notable(gene, delta)
	var name_label: Label = label(grid, GeneInfo.gene_name(gene), &"MutedLabel" if GeneInfo.is_inert(gene) else &"")
	name_label.tooltip_text = GeneInfo.MEANINGS[gene]
	name_label.mouse_filter = Control.MOUSE_FILTER_PASS
	var bar: UiBar = UiBar.new()
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.marker = GeneInfo.normalized(gene, before)
	bar.fill_color = &"muted" if not notable else (&"up" if delta > 0.0 else &"down")
	bar.tooltip_text = "This wave %s, next wave %s" % [GeneInfo.format_value(gene, before), GeneInfo.format_value(gene, after)]
	grid.add_child(bar)
	tween_bar(bar, "value", GeneInfo.normalized(gene, before), GeneInfo.normalized(gene, after), CHIP_STAGGER * index)
	label(grid, "%s → %s" % [GeneInfo.format_value(gene, before), GeneInfo.format_value(gene, after)], &"SmallTextLabel")
	delta_pill(grid, GeneInfo.format_delta(gene, delta), delta, notable)


func _fill_all_genes(before: Dictionary, after: Dictionary) -> void:
	for col: VBoxContainer in _all_columns:
		clear(col)
	for i: int in GeneInfo.GROUPS.size():
		var group: Array = GeneInfo.GROUPS[i]
		var col: VBoxContainer = _all_columns[0 if i < 2 else 1]
		label(col, group[0], &"AccentLabel")
		var grid: GridContainer = _gene_grid(col)
		for gene: String in group[1]:
			if after.has(gene) and before.has(gene):
				_gene_row(grid, [gene, before[gene], after[gene], after[gene] - before[gene]], 0)


func _fill_hunt(s: Dictionary) -> void:
	var accent: Color = get_theme_color(&"accent", &"Palette")
	var colors: Array[Color] = [accent, accent.darkened(0.4), get_theme_color(&"muted", &"Palette")]
	var now: Array[float] = []
	var next: Array[float] = []
	for mode: String in Genome.PathMode.keys():
		now.append(float(s["path_modes_before"].get(mode, 0)))
		next.append(float(s["path_modes"].get(mode, 0)))
	_hunt_now.colors = colors
	_hunt_next.colors = colors
	_hunt_now.shares = now
	_hunt_next.shares = next
	tween_bar(_hunt_now, "reveal", 0.0, 1.0)
	tween_bar(_hunt_next, "reveal", 0.0, 1.0, 0.1)
	clear(_hunt_legend)
	var keys: Array = Genome.PathMode.keys()
	for i: int in keys.size():
		var item: HBoxContainer = hbox(_hunt_legend)
		item.add_theme_constant_override("separation", 2)
		var swatch: ColorRect = ColorRect.new()
		swatch.color = colors[i]
		swatch.custom_minimum_size = Vector2(5, 5)
		swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		item.add_child(swatch)
		var info: Array = GeneInfo.PATH_MODES[keys[i]]
		var l: Label = label(item, "%s %d → %d" % [info[0], int(now[i]), int(next[i])], &"SmallTextLabel")
		l.tooltip_text = info[1]
		l.mouse_filter = Control.MOUSE_FILTER_PASS


func _fill_deadly(s: Dictionary) -> void:
	count_up(_best_value, "%.2f", s["best_fitness"])
	count_up(_mean_value, "%.2f", s["mean_fitness"])
	var best: Array[float] = []
	var mean: Array[float] = []
	var history: Array = wave_manager.history if wave_manager != null and not wave_manager.history.is_empty() else [s]
	for i: int in range(maxi(history.size() - HISTORY_SHOWN, 0), history.size()):
		best.append(history[i]["best_fitness"])
		mean.append(history[i]["mean_fitness"])
	_spark.series = [{"values": mean, "color": &"muted"}, {"values": best, "color": &"accent"}]
	tween_bar(_spark, "reveal", 0.0, 1.0)
	var c: Dictionary = s["component_means"]
	_components.text = "Average score parts: damage %.2f · pressure %.2f · survival %.2f · objective %.2f" % [
		c[Fitness.D], c[Fitness.P], c[Fitness.S], c[Fitness.O]]
	_components.tooltip_text = "Damage dealt to you, time spent close to you, time alive, objective progress (each 0 to 1)."
	_components.mouse_filter = Control.MOUSE_FILTER_PASS


## Raw data for the viva: the genome string, D/P/S/O, GA numbers, path modes, history, means.
func _fill_details(s: Dictionary) -> void:
	clear(_details)
	var c: Dictionary = s["component_means"]
	var w: FitnessSettings = load("res://data/fitness.tres")
	label(_details, "Best genome: " + s["best_genome"], &"SmallTextLabel", true)
	label(_details, "Fitness best %.3f  mean %.3f  |  mean D %.3f  P %.3f  S %.3f  O %.3f  |  F = %.2f D + %.2f P + %.2f S + %.2f O" % [
		s["best_fitness"], s["mean_fitness"], c[Fitness.D], c[Fitness.P], c[Fitness.S], c[Fitness.O],
		w.weight_damage, w.weight_pressure, w.weight_survival, w.weight_objective], &"SmallTextLabel", true)
	label(_details, "GA: wave %d -> generation %d  |  stat budget %d  |  mutation rate %.3f  |  diversity guard %s" % [
		s["from_wave"], s["generation"], s["budget"], s["mutation_rate"], "ON (x2)" if s["diversity_guard"] else "off"],
		&"SmallTextLabel", true)
	label(_details, "Path modes  %s  ->  %s" % [_modes_text(s["path_modes_before"]), _modes_text(s["path_modes"])],
		&"SmallTextLabel", true)
	label(_details, "History (best / mean): " + _history_text(), &"SmallTextLabel", true)
	var grid: GridContainer = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	_details.add_child(grid)
	for gene: String in GeneInfo.all_genes():
		if s["means_after"].has(gene):
			label(grid, "%s %.3f -> %.3f (%+.3f)" % [gene, s["means_before"][gene], s["means_after"][gene],
				s["means_after"][gene] - s["means_before"][gene]], &"SmallLabel")


## The 3 gene averages furthest from "average" (5 for stats, 0.5 for behaviour), as words.
## Used by the HUD (without the numbers).
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
	if wave_manager == null:
		return ""
	var parts: PackedStringArray = PackedStringArray()
	for i: int in range(maxi(wave_manager.history.size() - 8, 0), wave_manager.history.size()):
		var h: Dictionary = wave_manager.history[i]
		parts.append("w%d %.2f/%.2f" % [h["from_wave"], h["best_fitness"], h["mean_fitness"]])
	return "  ".join(parts)


static func _modes_text(counts: Dictionary) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for mode: String in Genome.PathMode.keys():
		parts.append("%s %d" % [mode, counts.get(mode, 0)])
	return " ".join(parts)

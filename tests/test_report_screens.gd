extends GutTest
## Between-wave screens (Wave Report, Downed): everything fits the 480 x 270 viewport (the game
## is integer-scaled to 720p / 768p / 1080p, so the layout is the same at all three), the
## layout stays the same from wave to wave (the old report grew on wave 2), the default view
## has no gene / fitness abbreviations, Details keeps the raw data, Enter / D work, and the
## theme meets the type scale and contrast rules.

const VIEWPORT: Rect2 = Rect2(0, 0, 480, 270)
const ABBREVIATIONS: String = "\\b(spd|hp|vis|agg|cau|fla|coh|pat|swi|cli|cra|tox|nig|FLOW|ASTAR|GREEDY)\\b|\\b[DPSO] \\d"


func after_each() -> void:
	get_tree().paused = false


func _level() -> Dictionary:
	var main: Node = load("res://world/main.tscn").instantiate()
	main.autosave = false
	var wm: WaveManager = main.get_node("WaveManager")
	wm.log_waves = false
	wm.spawn_seed = 11
	add_child_autofree(main)
	await wait_physics_frames(2)
	main.get_node("Player").health = 100000.0
	return {"main": main, "wm": wm, "report": main.get_node("HUD/WaveReport"),
		"downed": main.get_node("HUD/GameOverScreen"), "player": main.get_node("Player")}


## Every visible control inside the viewport; labels that don't wrap are wide enough for their
## text; containers are at least their minimum size (= nothing squeezed or cut).
func _assert_fits(screen: ReportScreen, what: String) -> void:
	var frame: Control = screen.get_node("Frame")
	assert_almost_eq(frame.size, VIEWPORT.size, Vector2(0.5, 0.5), what + ": frame = screen")
	var bad: PackedStringArray = PackedStringArray()
	for c: Control in _visible_controls(screen):
		var r: Rect2 = c.get_global_rect()
		if r.position.x < -0.5 or r.position.y < -0.5 or r.end.x > VIEWPORT.end.x + 0.5 or r.end.y > VIEWPORT.end.y + 0.5:
			bad.append("%s outside %s" % [c.get_path(), r])
		var m: Vector2 = c.get_combined_minimum_size()
		if m.x > c.size.x + 0.5 or m.y > c.size.y + 0.5:
			bad.append("%s min %s > size %s" % [c.get_path(), m, c.size])
	assert_eq(bad.size(), 0, what + ": " + "; ".join(bad.slice(0, 5)))


func _visible_controls(n: Node) -> Array[Control]:
	var out: Array[Control] = []
	for c: Node in n.get_children():
		if c is Control and (c as Control).is_visible_in_tree():
			out.append(c)
			out.append_array(_visible_controls(c))
	return out


func _visible_text(screen: ReportScreen) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for c: Control in _visible_controls(screen):
		if c is Label or c is Button:
			parts.append(c.text)
	return "\n".join(parts)


func _key(screen: Node, action: String) -> void:
	var ev: InputEventAction = InputEventAction.new()
	ev.action = action
	ev.pressed = true
	screen._unhandled_input(ev)


func _end_wave(lvl: Dictionary) -> void:
	await wait_physics_frames(1)
	lvl["wm"].end_wave()
	await wait_physics_frames(3)


# --- Wave Report ---------------------------------------------------------------------------

func test_report_fits_and_keeps_its_layout_on_waves_1_2_and_7() -> void:
	var lvl: Dictionary = await _level()
	var report: WaveReport = lvl["report"]
	var panel_rect: Rect2 = Rect2()
	var root_children: int = -1
	for wave: int in range(1, 8):
		await _end_wave(lvl)
		assert_true(report.visible, "report after wave %d" % wave)
		if wave in [1, 2, 7]:
			report.skip_motion()
			await wait_frames(2)
			_assert_fits(report, "wave %d" % wave)
			var panel: Control = report.get_node("Frame/Panel")
			var root: Node = report.get_node("Frame/Panel/Root")
			if wave == 1:
				panel_rect = panel.get_global_rect()
				root_children = root.get_child_count()
			else:
				assert_eq(panel.get_global_rect(), panel_rect, "same panel on wave %d" % wave)
				assert_eq(root.get_child_count(), root_children, "same layout on wave %d" % wave)
			var title: Label = report.get_node("Frame/Panel/Root").get_child(0).get_child(0).get_child(0)
			assert_eq(title.text, "WAVE %d CLEARED" % wave)
			assert_true(title.is_visible_in_tree() and title.get_global_rect().position.y >= 0.0, "header on screen")
			assert_eq(get_viewport().gui_get_focus_owner(), report._continue_button, "Continue has focus")
		report._continue_button.pressed.emit()
		await wait_physics_frames(2)
		assert_false(report.visible)


func test_report_default_view_has_no_abbreviations_and_details_keep_raw_data() -> void:
	var lvl: Dictionary = await _level()
	var report: WaveReport = lvl["report"]
	await _end_wave(lvl)
	report.skip_motion()
	await wait_frames(2)
	var regex: RegEx = RegEx.create_from_string(ABBREVIATIONS)
	var text: String = _visible_text(report)
	assert_null(regex.search(text), "default view: '%s'" % (regex.search(text).get_string() if regex.search(text) else ""))
	assert_string_contains(text, "How they changed")
	assert_string_contains(text, "How deadly they were")
	assert_string_contains(text, "What to expect")
	_key(report, "report_details")
	await wait_frames(2)
	assert_eq(report.current_page(), "details")
	var details: String = _visible_text(report)
	assert_string_contains(details, report.last_summary["best_genome"], "raw genome in Details")
	assert_string_contains(details, "fer ", "the genome shows ferocity")
	_assert_fits(report, "details")
	report.show_page("all")
	await wait_frames(2)
	_assert_fits(report, "show all")
	for group: Array in GeneInfo.GROUPS:
		assert_string_contains(_visible_text(report), group[0])
	assert_null(regex.search(_visible_text(report)), "show all uses full names")
	_key(report, "report_details")
	_key(report, "report_details")
	assert_eq(report.current_page(), "overview", "D twice: back to the summary")


func test_enter_skips_the_motion_then_continues() -> void:
	var lvl: Dictionary = await _level()
	var report: WaveReport = lvl["report"]
	var wm: WaveManager = lvl["wm"]
	await _end_wave(lvl)
	report.present()  # restart the motion
	assert_true(report.is_animating())
	_key(report, "ui_accept")
	assert_true(report.visible, "first Enter only skips the motion")
	assert_false(report.is_animating())
	_key(report, "ui_accept")
	assert_false(report.visible, "second Enter continues")
	assert_eq(wm.wave_number, 2)


func test_reports_have_no_skills_button_or_xp_any_more() -> void:
	var lvl: Dictionary = await _level()
	var report: WaveReport = lvl["report"]
	await _end_wave(lvl)
	report.skip_motion()
	await wait_frames(2)
	var text: String = _visible_text(report)
	assert_false(text.contains("Skills"), "no Skills button")
	assert_false(text.contains("XP"), "no XP")
	assert_false(lvl["downed"].find_children("*", "Button", true, false).any(
			func(b: Node) -> bool: return (b as Button).text.begins_with("Skills")))


# --- Downed --------------------------------------------------------------------------------

func _go_down(lvl: Dictionary) -> void:
	await wait_physics_frames(1)
	var player: Player = lvl["player"]
	player.health = 1.0
	player.take_damage(5.0)
	await wait_physics_frames(3)


func test_downed_screen_fits_on_waves_1_2_and_7() -> void:
	var lvl: Dictionary = await _level()
	var downed: GameOverScreen = lvl["downed"]
	var wm: WaveManager = lvl["wm"]
	for wave: int in range(1, 8):
		if wave in [1, 2, 7]:
			await _go_down(lvl)
			assert_true(downed.visible, "downed in wave %d" % wave)
			downed.skip_motion()
			await wait_frames(2)
			_assert_fits(downed, "downed wave %d" % wave)
			assert_eq(get_viewport().gui_get_focus_owner(), downed._retry_button)
			var regex: RegEx = RegEx.create_from_string(ABBREVIATIONS)
			assert_null(regex.search(_visible_text(downed)), "downed default view")
			assert_string_contains(_visible_text(downed), "What got you")
			downed._retry_button.pressed.emit()
			await wait_physics_frames(3)
			assert_eq(wm.wave_number, wave, "retry replays the same wave")
			lvl["player"].health = 100000.0
		await _end_wave(lvl)
		lvl["report"]._continue_button.pressed.emit()
		await wait_physics_frames(2)


func test_downed_details_show_the_deadliest_genome_and_enter_retries() -> void:
	var lvl: Dictionary = await _level()
	var downed: GameOverScreen = lvl["downed"]
	var wm: WaveManager = lvl["wm"]
	await _go_down(lvl)
	var culprit: Dictionary = downed.deadliest()
	assert_false(culprit.is_empty())
	for r: Dictionary in wm.last_wave_results:
		assert_true((r["record"] as FitnessRecord).damage_dealt <= (culprit["record"] as FitnessRecord).damage_dealt)
	_key(downed, "report_details")
	downed.skip_motion()
	await wait_frames(2)
	assert_string_contains(_visible_text(downed), (culprit["genome"] as Genome).describe())
	_assert_fits(downed, "downed details")
	_key(downed, "ui_accept")  # skips the motion if still running
	if downed.visible:
		_key(downed, "ui_accept")
	assert_false(downed.visible)
	assert_false(wm.failed, "Retry restarted the wave")


func test_downed_restart_level_button_follows_the_flag() -> void:
	var lvl: Dictionary = await _level()
	var downed: GameOverScreen = lvl["downed"]
	assert_false(downed._restart_button.visible)
	downed.allow_level_restart = true
	assert_true(downed._restart_button.visible)


# --- Words and theme -------------------------------------------------------------------------

func test_every_gene_has_a_full_name_meaning_and_group() -> void:
	var grouped: Array[String] = GeneInfo.all_genes()
	for gene: StringName in Genome.STAT_GENES + Genome.BEHAVIOUR_GENES + Genome.TERRAIN_GENES:
		assert_true(grouped.has(String(gene)), "%s grouped" % gene)
		assert_true(GeneInfo.NAMES.has(String(gene)), "%s named" % gene)
		assert_true(GeneInfo.MEANINGS.has(String(gene)), "%s explained" % gene)


func test_every_gene_acts_and_drives_the_story_by_size_of_change() -> void:
	var before: Dictionary = {}
	var after: Dictionary = {}
	for gene: String in GeneInfo.all_genes():
		before[gene] = 0.5 if not GeneInfo.is_stat(gene) else 5.0
		after[gene] = before[gene]
	after["cohesion"] = 0.3
	after["speed"] = 5.5
	assert_eq(GeneInfo.INERT.size(), 0, "no gene without an effect is left")
	var changes: Array[Array] = GeneInfo.ranked_changes(before, after)
	assert_eq(changes[0][0], "cohesion", "the biggest change relative to its range comes first")
	assert_eq(changes[1][0], "speed")
	assert_eq(GeneInfo.expectations(changes), ["They arrive one by one.", "They reach you sooner."] as Array[String])
	assert_eq(GeneInfo.story_sentence(4, changes), "Generation 4 is spreading out and getting faster.")


func test_theme_type_scale_and_contrast() -> void:
	var t: Theme = load(ReportScreen.THEME_PATH)
	assert_eq(t.get_font_size("font_size", "TitleLabel"), 16, "32 px at 720p")
	assert_eq(t.get_font_size("font_size", "SectionLabel"), 10, "20 px at 720p")
	assert_eq(t.get_font_size("font_size", "Label"), 8, "16 px at 720p")
	for type: StringName in t.get_type_list():
		if t.has_font_size("font_size", type):
			assert_gte(t.get_font_size("font_size", type), 7, "%s >= 14 px at 720p" % type)
	var muted: Color = t.get_color("muted", "Palette")
	for bg: String in ["panel", "card"]:
		assert_gte(_contrast(muted, t.get_color(bg, "Palette")), 4.5, "muted on " + bg)
		assert_gte(_contrast(t.get_color("text", "Palette"), t.get_color(bg, "Palette")), 4.5, "text on " + bg)
	assert_eq(t.get_color("panel", "Palette"), Color("#16181d"))
	assert_eq(t.get_color("accent", "Palette"), Color("#e8b84a"))


static func _contrast(a: Color, b: Color) -> float:
	var la: float = _luminance(a)
	var lb: float = _luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


static func _luminance(c: Color) -> float:
	var lin: Callable = func(v: float) -> float: return v / 12.92 if v <= 0.03928 else pow((v + 0.055) / 1.055, 2.4)
	return 0.2126 * lin.call(c.r) + 0.7152 * lin.call(c.g) + 0.0722 * lin.call(c.b)

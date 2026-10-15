extends GutTest
## Regression tests for the 2026-10-15 audit (docs/audit/BUG_FIXES.md): campaign continuity
## (New Game+ Continue, Safehouse resume, Endless best wave), damaged saves, Safehouse layout.
## The real user://campaign.json is backed up and restored around these tests.

var _backup: String = ""
var _had_save: bool = false


func before_all() -> void:
	_had_save = FileAccess.file_exists(SaveSystem.CAMPAIGN_PATH)
	if _had_save:
		_backup = FileAccess.get_file_as_string(SaveSystem.CAMPAIGN_PATH)


func after_all() -> void:
	if _had_save:
		var f: FileAccess = FileAccess.open(SaveSystem.CAMPAIGN_PATH, FileAccess.WRITE)
		f.store_string(_backup)
		f.close()
	else:
		SaveSystem.delete_save(SaveSystem.CAMPAIGN_PATH)


func after_each() -> void:
	GameState.leave_campaign()
	GameState.test_mode = false
	GameState.start_new_campaign()
	GameState.campaign_active = false
	GameState.campaign_won = false
	GameState.endless_unlocked = false
	GameState.ng_plus_unlocked = false
	GameState.ng_plus = false
	GameState.endless_mode = false
	GameState.endless_best_wave = 0
	GameState.safehouse_pending = false
	GameState.current_zone = 1
	get_tree().paused = false


func _evolution() -> Dictionary:
	return {"next_wave": 2, "generation": 1, "population": [], "history": []}


func _finish_zone_one() -> String:
	GameState.start_new_campaign()
	for n: int in 3:
		GameState.finish_level(_evolution(), {})
	return GameState.finish_level(_evolution(), {})


# --- New Game+ / second run: Continue must come back ---------------------------------------

func test_new_run_after_a_win_clears_the_win_but_keeps_the_unlocks() -> void:
	GameState.campaign_won = true
	GameState.endless_unlocked = true
	GameState.ng_plus_unlocked = true
	GameState.start_new_campaign(true)
	assert_false(GameState.campaign_won, "the old win must not hide Continue in the new run")
	assert_true(GameState.endless_unlocked)
	assert_true(GameState.ng_plus_unlocked)


func test_continue_campaign_is_offered_in_a_new_game_plus_run() -> void:
	GameState.campaign_won = true
	GameState.ng_plus_unlocked = true
	GameState.start_new_campaign(true)
	assert_eq(GameState.save_campaign(), OK)
	var menu: Node = load("res://ui/menus/main_menu.tscn").instantiate()
	add_child_autofree(menu)
	assert_true(menu._continue_button.visible, "Continue Campaign is visible during New Game+")


# --- Safehouse resume ------------------------------------------------------------------------

func test_beating_an_apex_marks_the_safehouse_as_pending_and_it_is_saved() -> void:
	assert_eq(_finish_zone_one(), "safehouse")
	assert_true(GameState.safehouse_pending)
	var back: Variant = JSON.parse_string(JSON.stringify(GameState.to_dict()))
	GameState.safehouse_pending = false
	assert_true(GameState.from_dict(back))
	assert_true(GameState.safehouse_pending, "a saved game quit at the Safehouse resumes there")


func test_entering_the_next_zone_clears_the_pending_safehouse() -> void:
	_finish_zone_one()
	GameState.enter_next_zone()
	assert_false(GameState.safehouse_pending)
	assert_eq(GameState.current_level().id, "z2_l1")


func test_a_normal_level_does_not_set_the_pending_safehouse() -> void:
	GameState.start_new_campaign()
	GameState.finish_level(_evolution(), {})
	assert_false(GameState.safehouse_pending)


func test_the_victory_is_not_a_pending_safehouse() -> void:
	GameState.start_new_campaign()
	GameState.current_zone = 4
	GameState.level_index = 3
	assert_eq(GameState.finish_level(_evolution(), {}), "victory")
	assert_false(GameState.safehouse_pending)


# --- Endless best wave ----------------------------------------------------------------------

func test_endless_best_wave_is_saved_and_never_lowered() -> void:
	GameState.note_endless_wave(7)
	assert_eq(GameState.endless_best_wave, 7)
	GameState.note_endless_wave(3)
	assert_eq(GameState.endless_best_wave, 7, "a worse wave does not replace the best")
	GameState.endless_best_wave = 0
	assert_true(GameState.load_campaign())
	assert_eq(GameState.endless_best_wave, 7, "survives closing the game")


func test_endless_best_wave_is_not_saved_in_test_mode() -> void:
	GameState.start_new_campaign()
	GameState.save_campaign()
	GameState.test_mode = true
	GameState.note_endless_wave(12)
	GameState.test_mode = false
	GameState.endless_best_wave = 0
	GameState.load_campaign()
	assert_eq(GameState.endless_best_wave, 0, "test scenarios never touch the real save")


# --- Damaged saves ---------------------------------------------------------------------------

func test_campaign_save_with_wrong_types_loads_with_defaults() -> void:
	var junk: Dictionary = {
		"format": GameState.SAVE_FORMAT, "active": "yes", "zone": "two", "level_index": null,
		"zone_evolution": [], "zone_best": 5, "zone_elite": "x", "player": 3, "samples": [],
		"scrap": {}, "side_done": 12, "won": 1, "endless_unlocked": null, "ng_plus_unlocked": "true",
		"ng_plus": [], "endless_best_wave": "many", "safehouse_pending": 1,
	}
	assert_true(GameState.from_dict(junk), "still a campaign save, just damaged")
	assert_eq(GameState.current_zone, 1)
	assert_eq(GameState.level_index, 0)
	assert_eq(GameState.samples, 0)
	assert_eq(GameState.scrap, 0)
	assert_eq(GameState.side_done.size(), 0)
	assert_false(GameState.campaign_won)
	assert_false(GameState.safehouse_pending)
	assert_eq(GameState.endless_best_wave, 0)
	assert_true(GameState.player_data.is_empty())


func test_side_done_keeps_only_text_ids() -> void:
	var d: Dictionary = GameState.to_dict()
	d["side_done"] = ["a", 5, null, "b"]
	assert_true(GameState.from_dict(d))
	assert_eq(GameState.side_done, ["a", "b"] as Array[String])


func test_save_with_an_unreadable_terrain_gene_is_repaired_not_crashed() -> void:
	var rules: GenomeRules = load("res://data/genome_rules.tres")
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 5
	var g: Dictionary = Genome.random(rng, rules, rules.budget_for_wave(1)).to_dict()
	g["swimmer"] = null
	g["crawler"] = [1]
	var data: Dictionary = {"version": 1, "player": {"level": 1},
		"evolution": {"next_wave": 1, "generation": 0, "population": [g]}}
	var r: Dictionary = SaveGame.validate(data, load("res://data/progression.tres"),
			load("res://data/skill_tree.tres"), rules)
	assert_true(r["ok"], r["error"])
	var healed: Genome = Genome.from_dict(r["data"]["evolution"]["population"][0])
	assert_eq(healed.swimmer, 0.0)
	assert_eq(healed.crawler, 0.0)
	assert_true(str(r["warnings"]).contains("swimmer"))


# --- Safehouse layout --------------------------------------------------------------------------

func test_safehouse_text_fits_the_480_px_viewport() -> void:
	var g: Genome = Genome.new()
	g.speed = 7.5
	g.health = 5.8
	g.vision = 1.7
	GameState.start_new_campaign()
	GameState.zone_best = {1: {"fitness": 0.5, "genome": g.to_dict()}}
	GameState.safehouse_mode = "zone"
	var screen: Control = load("res://ui/menus/safehouse.tscn").instantiate()
	add_child_autofree(screen)
	await wait_physics_frames(2)
	var checked: int = 0
	for label: Node in screen.find_children("*", "Label", true, false):
		assert_lte((label as Label).get_combined_minimum_size().x, 480.0, "label too wide: " + (label as Label).text)
		checked += 1
	assert_gt(checked, 4)


# --- Main menu: New Game is the campaign, Endless lives in Test Scenarios ----------------------

func _button_texts(root_node: Node) -> PackedStringArray:
	var texts: PackedStringArray = PackedStringArray()
	for b: Node in root_node.find_children("*", "Button", true, false):
		texts.append((b as Button).text)
	return texts


func test_main_menu_new_game_is_the_campaign_and_endless_is_a_test_scenario() -> void:
	GameState.test_mode = false
	var menu: Node = load("res://ui/menus/main_menu.tscn").instantiate()
	add_child_autofree(menu)
	var top: PackedStringArray = _button_texts(menu._menu)
	assert_true(top.has("New Game"))
	assert_true(top.has("Test Scenarios"))
	assert_false(top.has("Campaign"), "no separate Campaign submenu any more")
	for t: String in top:
		assert_false(t.begins_with("Endless"), "Endless is not a top-level button")
	assert_true(_button_texts(menu._scenario_menu).has("Endless (wave loop)"))


func test_endless_from_the_menu_is_a_test_run_that_saves_nothing() -> void:
	var menu: Node = load("res://ui/menus/main_menu.tscn").instantiate()
	add_child_autofree(menu)
	GameState.start_new_campaign()
	GameState.save_campaign()
	var before: String = FileAccess.get_file_as_string(SaveSystem.CAMPAIGN_PATH)
	GameState.test_mode = true
	GameState.endless_mode = true
	GameState.note_endless_wave(9)
	assert_eq(FileAccess.get_file_as_string(SaveSystem.CAMPAIGN_PATH), before, "campaign save untouched")

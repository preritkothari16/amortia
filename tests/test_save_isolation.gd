extends GutTest
## Tests, scripts and headless runs must never touch the player's real saves (SaveSystem sandbox).
## The real files are only READ here (FileAccess on the plain user:// path), never written.

const REAL_PATHS: Array[String] = [SaveSystem.SAVE_PATH, SaveSystem.CAMPAIGN_PATH]


func after_each() -> void:
	get_tree().paused = false
	GameState.test_mode = false
	GameState.leave_campaign()
	SaveSystem.delete_save(SaveSystem.SAVE_PATH)
	SaveSystem.delete_save(SaveSystem.CAMPAIGN_PATH)


## Existence, modified time and bytes of the real save files.
func _real_snapshot() -> Dictionary:
	var out: Dictionary = {}
	for p: String in REAL_PATHS:
		var exists: bool = FileAccess.file_exists(p)
		out[p] = [exists, FileAccess.get_modified_time(p) if exists else 0,
			FileAccess.get_file_as_bytes(p) if exists else PackedByteArray()]
	return out


func test_this_test_run_is_sandboxed() -> void:
	assert_true(SaveSystem.is_sandboxed())
	for p: String in REAL_PATHS:
		var used: String = SaveSystem.resolve(p)
		assert_ne(used, p, "%s is redirected" % p)
		assert_true(used.begins_with(SaveSystem.SANDBOX_ROOT + "/"), used)
		assert_eq(used.get_file(), p.get_file(), "same file name inside the sandbox")


func test_when_to_sandbox() -> void:
	var none: PackedStringArray = PackedStringArray()
	assert_false(SaveSystem.should_sandbox(false, false, "res://ui/menus/main_menu.tscn", none), "normal game saves for real")
	assert_false(SaveSystem.should_sandbox(false, false, "res://world/main.tscn", none), "editor Play of a level saves for real")
	assert_false(SaveSystem.should_sandbox(false, false, "", none))
	assert_true(SaveSystem.should_sandbox(true, false, "res://ui/menus/main_menu.tscn", none), "headless run")
	assert_true(SaveSystem.should_sandbox(false, true, "", none), "godot -s script (GUT command line, simulations)")
	assert_true(SaveSystem.should_sandbox(false, false, "res://addons/gut/gui/run_from_editor.tscn", none), "GUT editor panel")
	assert_true(SaveSystem.should_sandbox(false, false, "res://ui/menus/main_menu.tscn",
			PackedStringArray([SaveSystem.SANDBOX_ARG])), "forced with -- --sandbox-saves")


func test_resolve_only_moves_user_files_outside_the_sandbox() -> void:
	assert_eq(SaveSystem.resolve("res://data/ga.tres"), "res://data/ga.tres")
	var inside: String = SaveSystem.resolve(SaveSystem.CAMPAIGN_PATH)
	assert_eq(SaveSystem.resolve(inside), inside, "already in the sandbox: unchanged")
	assert_true(SaveSystem.resolve("user://slots/a.json").ends_with("/slots/a.json"))
	assert_true(SaveSystem.resolve("user://slots/a.json").begins_with(SaveSystem.SANDBOX_ROOT + "/"))


func test_writes_reads_and_deletes_never_reach_the_real_files() -> void:
	var before: Dictionary = _real_snapshot()
	assert_eq(SaveSystem.write_save({"version": 1, "player": {}, "evolution": {}}), OK)
	assert_true(SaveSystem.has_save())
	assert_true(FileAccess.file_exists(SaveSystem.resolve(SaveSystem.SAVE_PATH)))
	assert_eq(SaveSystem.read_save()["data"]["version"], 1.0)
	GameState.start_new_campaign()
	assert_eq(GameState.save_campaign(), OK)
	assert_true(GameState.load_campaign())
	assert_true(SaveSystem.has_save(SaveSystem.CAMPAIGN_PATH))
	SaveSystem.delete_save(SaveSystem.SAVE_PATH)
	SaveSystem.delete_save(SaveSystem.CAMPAIGN_PATH)
	assert_false(SaveSystem.has_save(SaveSystem.CAMPAIGN_PATH))
	assert_eq(_real_snapshot(), before, "real save files unchanged (or still absent)")


func test_prototype_autosave_goes_to_the_sandbox() -> void:
	var before: Dictionary = _real_snapshot()
	SaveSystem.delete_save(SaveSystem.SAVE_PATH)
	var main: Node = load("res://world/main.tscn").instantiate()
	assert_true(main.autosave, "the game's autosave stays on")
	var wm: WaveManager = main.get_node("WaveManager")
	wm.log_waves = false
	wm.spawn_seed = 5
	add_child_autofree(main)
	await wait_physics_frames(4)
	wm.end_wave()  # bred -> main.save_game()
	await wait_physics_frames(2)
	var r: Dictionary = SaveSystem.read_save()
	assert_true(r["ok"], "the checkpoint was written: %s" % r["error"])
	assert_eq(int(r["data"]["evolution"]["next_wave"]), 2)
	assert_eq(_real_snapshot(), before, "the real user://save.json is untouched")


func test_debug_scenarios_write_nothing_at_all() -> void:
	var before: Dictionary = _real_snapshot()
	DebugScenarios.prepare(2, 0, false)
	assert_true(GameState.test_mode)
	assert_eq(GameState.save_campaign(), OK)
	assert_false(SaveSystem.has_save(SaveSystem.CAMPAIGN_PATH), "test mode writes not even the sandbox")
	GameState.end_test_mode()
	assert_eq(_real_snapshot(), before)


func test_folders_of_dead_runs_are_removed_and_ours_kept() -> void:
	var stale: String = SaveSystem.SANDBOX_ROOT.path_join("999999999")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(stale))
	var f: FileAccess = FileAccess.open(stale.path_join("campaign.json"), FileAccess.WRITE)
	f.store_string("{}")
	f.close()
	SaveSystem._open_sandbox()
	assert_false(DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(stale)), "a crashed run's folder is pruned")
	assert_true(DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(SaveSystem.resolve(SaveSystem.CAMPAIGN_PATH).get_base_dir())))

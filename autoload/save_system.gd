extends Node
## Save slot file access (GDD 10): JSON files in user://. Only plain dictionaries go in or
## out — building and checking their contents is SaveGame's job (world/save_game.gd).
## The main menu fills `pending_state` (Continue) or clears it (New Game) before loading the
## level; the level reads it once in _ready.
## Two slots: SAVE_PATH = the prototype loop (format unchanged since step 25), CAMPAIGN_PATH =
## the campaign (its own file, so old prototype saves stay valid as they are).
##
## Sandbox: GUT tests (command line or editor panel), `-s` scripts and headless runs must never
## touch the player's real saves. In those runs every user:// path given to this class is
## redirected into SANDBOX_ROOT/<process id>/ (resolve()), which is deleted when the process
## ends. A normal windowed game (editor Play or export) saves for real. `-- --sandbox-saves`
## forces the sandbox in a windowed run too.

const SAVE_PATH: String = "user://save.json"
const CAMPAIGN_PATH: String = "user://campaign.json"
const SANDBOX_ROOT: String = "user://sandbox"
const SANDBOX_ARG: String = "--sandbox-saves"
## Main scene of GUT's editor panel run (res://addons/gut/gui/run_from_editor.tscn).
const GUT_SCENES: String = "res://addons/gut/"

## Save data the next level should start from. Empty = new game.
var pending_state: Dictionary = {}

## This process's sandbox folder; "" = real saves. Static, so every SaveSystem instance agrees.
static var _sandbox_dir: String = ""
static var _decided: bool = false


## True if a run with these facts must not touch the real saves.
static func should_sandbox(headless: bool, scripted: bool, scene_path: String, user_args: PackedStringArray) -> bool:
	return headless or scripted or scene_path.begins_with(GUT_SCENES) or user_args.has(SANDBOX_ARG)


static func is_sandboxed() -> bool:
	_decide()
	return _sandbox_dir != ""


## The file actually used for `path`: itself, or its place in the sandbox.
static func resolve(path: String) -> String:
	_decide()
	if _sandbox_dir == "" or not path.begins_with("user://") or path.begins_with(SANDBOX_ROOT + "/"):
		return path
	return _sandbox_dir.path_join(path.trim_prefix("user://"))


## Decides once per process. Until the main scene exists (autoloads load first) a "real saves"
## answer is not kept, because the GUT editor runner is only recognisable by its scene.
static func _decide() -> void:
	if _decided:
		return
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var scene: Node = tree.current_scene if tree != null else null
	var scene_path: String = scene.scene_file_path if scene != null else ""
	var scripted: bool = tree != null and tree.get_script() != null  # `godot -s script.gd`
	if should_sandbox(DisplayServer.get_name() == "headless", scripted, scene_path, OS.get_cmdline_user_args()):
		_open_sandbox()
		_decided = true
	elif scene != null:
		_decided = true


static func _open_sandbox() -> void:
	_sandbox_dir = SANDBOX_ROOT.path_join(str(OS.get_process_id()))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_sandbox_dir))
	# Folders of earlier runs that crashed before cleaning up.
	for old: String in DirAccess.get_directories_at(SANDBOX_ROOT):
		if old.is_valid_int() and int(old) != OS.get_process_id() and not OS.is_process_running(int(old)):
			_remove_tree(SANDBOX_ROOT.path_join(old))
	print("[Save] sandboxed saves in %s (real saves untouched)" % ProjectSettings.globalize_path(_sandbox_dir))


static func _remove_tree(dir_path: String) -> void:
	for f: String in DirAccess.get_files_at(dir_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(dir_path.path_join(f)))
	for d: String in DirAccess.get_directories_at(dir_path):
		_remove_tree(dir_path.path_join(d))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(dir_path))


func _exit_tree() -> void:
	if _sandbox_dir != "":
		_remove_tree(_sandbox_dir)


func has_save(path: String = SAVE_PATH) -> bool:
	return FileAccess.file_exists(resolve(path))


## Writes `data` as JSON. Writes a temp file first and then renames it, so a crash while
## saving can't leave a half-written save behind. Returns OK or the error.
func write_save(data: Dictionary, path: String = SAVE_PATH) -> Error:
	var target: String = resolve(path)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(target.get_base_dir()))
	var temp_path: String = target + ".tmp"
	var file: FileAccess = FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		push_error("SaveSystem: can't write %s (%s)" % [temp_path, error_string(FileAccess.get_open_error())])
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	var err: Error = DirAccess.rename_absolute(ProjectSettings.globalize_path(temp_path), ProjectSettings.globalize_path(target))
	if err != OK:
		push_error("SaveSystem: can't replace %s (%s)" % [target, error_string(err)])
	return err


## Reads a save file. Returns {"ok": bool, "data": Dictionary, "error": String}.
## Never crashes on a missing, empty or broken file.
func read_save(path: String = SAVE_PATH) -> Dictionary:
	if not has_save(path):
		return {"ok": false, "data": {}, "error": "no save file"}
	var text: String = FileAccess.get_file_as_string(resolve(path))
	if text.is_empty():
		return {"ok": false, "data": {}, "error": "save file is empty or unreadable"}
	var json: JSON = JSON.new()
	if json.parse(text) != OK:
		return {"ok": false, "data": {}, "error": "bad JSON at line %d: %s" % [json.get_error_line(), json.get_error_message()]}
	if not json.data is Dictionary:
		return {"ok": false, "data": {}, "error": "save file is not a JSON object"}
	return {"ok": true, "data": json.data, "error": ""}


func delete_save(path: String = SAVE_PATH) -> void:
	if has_save(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(resolve(path)))

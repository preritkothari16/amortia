extends Node
## Save slot file access (GDD 10): one JSON file in user://. Only plain dictionaries go in or
## out — building and checking their contents is SaveGame's job (world/save_game.gd).
## The main menu fills `pending_state` (Continue) or clears it (New Game) before loading the
## level; the level reads it once in _ready.

const SAVE_PATH: String = "user://save.json"
const TEMP_PATH: String = "user://save.json.tmp"

## Save data the next level should start from. Empty = new game.
var pending_state: Dictionary = {}


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


## Writes `data` as JSON. Writes a temp file first and then renames it, so a crash while
## saving can't leave a half-written save behind. Returns OK or the error.
func write_save(data: Dictionary) -> Error:
	var file: FileAccess = FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveSystem: can't write %s (%s)" % [TEMP_PATH, error_string(FileAccess.get_open_error())])
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	var dir: DirAccess = DirAccess.open("user://")
	var err: Error = dir.rename(TEMP_PATH.get_file(), SAVE_PATH.get_file())
	if err != OK:
		push_error("SaveSystem: can't replace %s (%s)" % [SAVE_PATH, error_string(err)])
	return err


## Reads the save file. Returns {"ok": bool, "data": Dictionary, "error": String}.
## Never crashes on a missing, empty or broken file.
func read_save() -> Dictionary:
	if not has_save():
		return {"ok": false, "data": {}, "error": "no save file"}
	var text: String = FileAccess.get_file_as_string(SAVE_PATH)
	if text.is_empty():
		return {"ok": false, "data": {}, "error": "save file is empty or unreadable"}
	var json: JSON = JSON.new()
	if json.parse(text) != OK:
		return {"ok": false, "data": {}, "error": "bad JSON at line %d: %s" % [json.get_error_line(), json.get_error_message()]}
	if not json.data is Dictionary:
		return {"ok": false, "data": {}, "error": "save file is not a JSON object"}
	return {"ok": true, "data": json.data, "error": ""}


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))

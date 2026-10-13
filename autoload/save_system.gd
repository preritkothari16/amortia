extends Node
## Save slot file access (GDD 10): JSON files in user://. Only plain dictionaries go in or
## out — building and checking their contents is SaveGame's job (world/save_game.gd).
## The main menu fills `pending_state` (Continue) or clears it (New Game) before loading the
## level; the level reads it once in _ready.
## Two slots: SAVE_PATH = the prototype loop (format unchanged since step 25), CAMPAIGN_PATH =
## the campaign (its own file, so old prototype saves stay valid as they are).

const SAVE_PATH: String = "user://save.json"
const CAMPAIGN_PATH: String = "user://campaign.json"

## Save data the next level should start from. Empty = new game.
var pending_state: Dictionary = {}


func has_save(path: String = SAVE_PATH) -> bool:
	return FileAccess.file_exists(path)


## Writes `data` as JSON. Writes a temp file first and then renames it, so a crash while
## saving can't leave a half-written save behind. Returns OK or the error.
func write_save(data: Dictionary, path: String = SAVE_PATH) -> Error:
	var temp_path: String = path + ".tmp"
	var file: FileAccess = FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		push_error("SaveSystem: can't write %s (%s)" % [temp_path, error_string(FileAccess.get_open_error())])
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	var dir: DirAccess = DirAccess.open("user://")
	var err: Error = dir.rename(temp_path.get_file(), path.get_file())
	if err != OK:
		push_error("SaveSystem: can't replace %s (%s)" % [path, error_string(err)])
	return err


## Reads a save file. Returns {"ok": bool, "data": Dictionary, "error": String}.
## Never crashes on a missing, empty or broken file.
func read_save(path: String = SAVE_PATH) -> Dictionary:
	if not has_save(path):
		return {"ok": false, "data": {}, "error": "no save file"}
	var text: String = FileAccess.get_file_as_string(path)
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
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

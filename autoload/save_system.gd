extends Node
## Save slot access (GDD 10). Prototype: only answers "is there a save?" so the main menu can
## show Continue. Writing and loading the save (XP, skills, wave, population) comes later.

const SAVE_PATH: String = "user://save.json"


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

class_name UserSettings
extends RefCounted
## The settings the player can actually change (Settings page, main menu and pause): for now
## only the window mode. Kept in user://settings.cfg and applied when the main menu opens.
## Nothing here touches gameplay.

const PATH: String = "user://settings.cfg"

static var fullscreen: bool = false
static var _loaded: bool = false


static func load_and_apply() -> void:
	if not _loaded:
		_loaded = true
		var cfg: ConfigFile = ConfigFile.new()
		if cfg.load(PATH) == OK:
			fullscreen = bool(cfg.get_value("display", "fullscreen", false))
	apply()


static func set_fullscreen(on: bool) -> void:
	fullscreen = on
	apply()
	var cfg: ConfigFile = ConfigFile.new()
	cfg.set_value("display", "fullscreen", fullscreen)
	cfg.save(PATH)


## Puts the window in the saved mode (no-op in headless runs and when it already matches).
static func apply() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var want: DisplayServer.WindowMode = DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	var now: DisplayServer.WindowMode = DisplayServer.window_get_mode()
	var is_full: bool = now == DisplayServer.WINDOW_MODE_FULLSCREEN or now == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	if is_full != fullscreen:
		DisplayServer.window_set_mode(want)

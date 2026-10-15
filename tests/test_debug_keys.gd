extends GutTest
## Developer keys (F1-F10) work in debug builds only; a release build ignores them.

func after_each() -> void:
	DebugKeys.override = -1
	get_tree().paused = false


func _key(action: String) -> InputEventAction:
	var e: InputEventAction = InputEventAction.new()
	e.action = action
	e.pressed = true
	return e


func _level() -> Dictionary:
	var main: Node = load("res://world/main.tscn").instantiate()
	main.autosave = false
	var wm: WaveManager = main.get_node("WaveManager")
	wm.log_waves = false
	wm.spawn_seed = 5
	wm.pause_between_waves = false
	add_child_autofree(main)
	await wait_physics_frames(3)
	return {"main": main, "wm": wm}


func test_enabled_follows_the_build_unless_overridden() -> void:
	assert_eq(DebugKeys.enabled(), OS.is_debug_build())
	DebugKeys.override = 0
	assert_false(DebugKeys.enabled())
	DebugKeys.override = 1
	assert_true(DebugKeys.enabled())


func test_release_build_ignores_the_wave_keys() -> void:
	var lvl: Dictionary = await _level()
	var wm: WaveManager = lvl["wm"]
	DebugKeys.override = 0
	var wave: int = wm.wave_number
	wm._unhandled_input(_key("debug_end_wave"))
	wm._unhandled_input(_key("debug_spawn_wave"))
	wm._unhandled_input(_key("debug_restart_wave"))
	assert_true(wm.is_wave_running(), "F8 did not end the wave")
	assert_eq(wm.wave_number, wave, "F3 / F9 did not change the wave")


func test_debug_build_still_has_the_wave_keys() -> void:
	var lvl: Dictionary = await _level()
	var wm: WaveManager = lvl["wm"]
	DebugKeys.override = 1
	wm._unhandled_input(_key("debug_end_wave"))
	assert_false(wm.is_wave_running(), "F8 ends the wave in a debug build")


func test_release_build_ignores_ignite_and_overlays() -> void:
	var lvl: Dictionary = await _level()
	var main: Node = lvl["main"]
	DebugKeys.override = 0
	var overlay: Node = main.get_node("AwarenessOverlay")
	var before: bool = overlay.visible
	overlay._unhandled_input(_key("debug_awareness"))
	assert_eq(overlay.visible, before, "F6 overlay stays as it was")
	DebugKeys.override = 1
	overlay._unhandled_input(_key("debug_awareness"))
	assert_ne(overlay.visible, before, "toggles in a debug build")

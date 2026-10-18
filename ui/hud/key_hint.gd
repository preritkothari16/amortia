class_name KeyHint
extends RefCounted
## The key currently bound to an input action, for HUD hints ("[G]"). Follows rebinding in
## Project Settings > Input Map, so the HUD never shows a stale key.


## "G" for the first key bound to `action`, "?" if none.
static func key(action: StringName) -> String:
	if not InputMap.has_action(action):
		return "?"
	for event: InputEvent in InputMap.action_get_events(action):
		var k: InputEventKey = event as InputEventKey
		if k == null:
			continue
		if k.physical_keycode != KEY_NONE:
			return OS.get_keycode_string(k.physical_keycode)
		if k.keycode != KEY_NONE:
			return OS.get_keycode_string(k.keycode)
	return "?"


## "[G]".
static func tag(action: StringName) -> String:
	return "[%s]" % key(action)

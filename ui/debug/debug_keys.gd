class_name DebugKeys
extends RefCounted
## Developer keys (F1-F10: overlays, next / end / restart wave, ignite) only work in debug builds
## (the editor, or an export with "debug" enabled). A release export ignores them, so a player
## cannot skip or end a wave by accident. `override` is for tests: 1 = on, 0 = off, -1 = automatic.

static var override: int = -1


static func enabled() -> bool:
	if override >= 0:
		return override == 1
	return OS.is_debug_build()

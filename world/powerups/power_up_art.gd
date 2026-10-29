class_name PowerUpArt
extends RefCounted
## The pixel-art icon of every power-up (art_src/powerups/build_powerup_icons.py): 9 x 9 icons for
## the HUD and 15 x 15 tokens (the same icon on a dark round plate) for the pickups on the map.
## One texel = one viewport pixel, drawn at whole-pixel positions with nearest filtering.

const ICON_SIZE: int = 9
const TOKEN_SIZE: int = 15

const ICONS: Dictionary[StringName, Texture2D] = {
	&"heal": preload("res://ui/hud/art/powerup_heal.png"),
	&"shield": preload("res://ui/hud/art/powerup_shield.png"),
	&"haste": preload("res://ui/hud/art/powerup_haste.png"),
	&"rapid": preload("res://ui/hud/art/powerup_rapid.png"),
	&"damage": preload("res://ui/hud/art/powerup_damage.png"),
}
const TOKENS: Dictionary[StringName, Texture2D] = {
	&"heal": preload("res://world/powerups/art/token_heal.png"),
	&"shield": preload("res://world/powerups/art/token_shield.png"),
	&"haste": preload("res://world/powerups/art/token_haste.png"),
	&"rapid": preload("res://world/powerups/art/token_rapid.png"),
	&"damage": preload("res://world/powerups/art/token_damage.png"),
}


static func icon(id: StringName) -> Texture2D:
	return ICONS.get(id)


static func token(id: StringName) -> Texture2D:
	return TOKENS.get(id)

class_name PlayerStatus
extends Control
## Greybox player panel, bottom-left: HP bar, dodge cooldown, HIDDEN (stealth); above it the
## weapon in hand, noise-makers left, shield and temporary power-ups.
## Ammo is not shown because weapons have no ammo yet.

const FONT_SIZE: int = 8
const BAR_SIZE: Vector2 = Vector2(70, 5)
const DODGE_SIZE: Vector2 = Vector2(36, 5)
const MARGIN: float = 4.0
## Distance from the bottom edge to the HP row's baseline.
const BOTTOM_OFFSET: float = 6.0
const COLOR_BACK: Color = Color(0, 0, 0, 0.6)
const COLOR_HP: Color = Color(0.85, 0.25, 0.25)
const COLOR_DODGE_READY: Color = Color(0.5, 0.9, 0.5)
const COLOR_DODGE_WAIT: Color = Color(0.55, 0.55, 0.55)
const COLOR_HIDDEN: Color = Color(0.55, 0.9, 0.75)

var player: Player


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS  # show 0 HP under the Game Over screen (game paused)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if player == null or player.stats == null:
		return
	var font: Font = ThemeDB.fallback_font
	var y: float = size.y - BOTTOM_OFFSET
	var x: float = MARGIN

	# HP: label, bar, numbers.
	x = _text(font, Vector2(x, y), "HP", Color.WHITE) + 3.0
	var hp_ratio: float = clampf(player.health / player.stats.max_health, 0.0, 1.0)
	_bar(Rect2(x, y - BAR_SIZE.y, BAR_SIZE.x, BAR_SIZE.y), hp_ratio, COLOR_HP)
	x += BAR_SIZE.x + 3.0
	x = _text(font, Vector2(x, y), "%d/%d" % [ceili(player.health), roundi(player.stats.max_health)], Color.WHITE)

	# Dodge: fills up while cooling down, green when ready.
	x += 10.0
	x = _text(font, Vector2(x, y), "DODGE", Color.WHITE) + 3.0
	var left: float = player.dodge_cooldown_left
	var is_ready: bool = left <= 0.0
	var ratio: float = 1.0 if is_ready else 1.0 - left / player.stats.dodge_cooldown
	_bar(Rect2(x, y - DODGE_SIZE.y, DODGE_SIZE.x, DODGE_SIZE.y), ratio,
		COLOR_DODGE_READY if is_ready else COLOR_DODGE_WAIT)
	x += DODGE_SIZE.x + 3.0
	x = _text(font, Vector2(x, y), "ready" if is_ready else "%.1f s" % left,
		COLOR_DODGE_READY if is_ready else COLOR_DODGE_WAIT)

	# Stealth (GDD 4.3): hidden in tall grass while walking and not shooting.
	if player.is_concealed():
		_text(font, Vector2(x + 10.0, y), "HIDDEN", COLOR_HIDDEN)

	# Second row: weapon in hand (Q swaps when a spare is carried), shield, temporary power-ups.
	var y2: float = y - 10.0
	var x2: float = MARGIN
	var weapon_data: WeaponStats = WeaponLibrary.get_weapon(player.active_weapon_id())
	if weapon_data != null:
		var tag: String = weapon_data.display_name + (" [Q]" if player.loadout.carried().size() > 1 else "")
		x2 = _text(font, Vector2(x2, y2), tag, Color(0.9, 0.85, 0.6)) + 8.0
	if player.noise_maker != null:
		var count: String = "%d/%d" % [player.noise_makers_left, player.noise_maker.max_carried] 				if player.noise_maker_inventory else "x%d" % player.noise_makers_left
		x2 = _text(font, Vector2(x2, y2), "Noise-maker %s %s" % [KeyHint.tag(&"throw_noise"), count],
				Color(0.6, 0.9, 1.0) if player.noise_makers_left > 0 else COLOR_DODGE_WAIT) + 8.0
	if player.shield > 0.0:
		x2 = _text(font, Vector2(x2, y2), "SHIELD %d" % ceili(player.shield), Color(0.5, 0.8, 1.0)) + 8.0
	for id: StringName in player.modifiers.temporary_ids():
		x2 = _text(font, Vector2(x2, y2), "%s %ds" % [String(id).capitalize(), ceili(player.modifiers.time_left(id))],
				Color(0.6, 1.0, 0.6)) + 8.0


func _bar(rect: Rect2, ratio: float, color: Color) -> void:
	draw_rect(rect.grow(1.0), COLOR_BACK)
	draw_rect(Rect2(rect.position, Vector2(rect.size.x * ratio, rect.size.y)), color)


## Draws outlined text with its baseline at `pos`; returns the x where it ends.
func _text(font: Font, pos: Vector2, text: String, color: Color) -> float:
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, FONT_SIZE, 2, Color.BLACK)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, FONT_SIZE, color)
	return pos.x + font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, FONT_SIZE).x

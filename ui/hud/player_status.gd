class_name PlayerStatus
extends Control
## Left and centre groups of the bottom HUD strip (step 71), drawn over WaveHud's band (positions in
## HudLayout). No avatar and no boxes:
##   heart + segmented blood-red HEALTH bar (a pale chunk drains after a hit) + HP value; low HP pulses
##   the bar and the heart; a hit flashes the group
##   dodge badge + compact blue cooldown bar + "RDY" / seconds, a short glint when it is ready again
##   HIDDEN chip while concealed in tall grass (stealth, GDD 4.3)
##   weapon in hand (art + name, glows briefly after a swap), swap key + spare weapon (only when one
##   is carried)
##   items: noise-maker (key, count, charge pips, flash on a throw), power-ups (only while one runs:
##   the pixel icon of each active effect - up to the 3 the game allows - with a bar draining over
##   its duration; with one running, its shield points / seconds beside it; a new one flashes, one
##   about to run out blinks), samples, scrap
## Weapons have no ammo, so none is shown. Every value is read live from the Player and GameState.
## Text uses MenuStyle's crisp fonts (the default font would be rasterised at 7 px and blown up).

const FONT_SIZE: int = 8
const SMALL_FONT_SIZE: int = 7
const TINY_FONT_SIZE: int = 6
const COLOR_TEXT: Color = MenuStyle.BONE
const COLOR_DIM: Color = Color(0.5, 0.5, 0.52)
const COLOR_HP: Color = Color(0.7, 0.16, 0.15)
const COLOR_HP_LIGHT: Color = Color(0.9, 0.3, 0.26)
const COLOR_HP_LOST: Color = Color(0.9, 0.82, 0.74, 0.7)
const COLOR_DODGE: Color = Color(0.2, 0.42, 0.68)
const COLOR_DODGE_LIGHT: Color = Color(0.5, 0.74, 0.98)
const COLOR_BAR_BACK: Color = Color(0.015, 0.02, 0.03, 0.9)
const COLOR_HIDDEN: Color = Color(0.55, 0.9, 0.72)
const COLOR_LOW: Color = Color(1.0, 0.5, 0.45)
## Health bar notch every this many HP.
const HP_SEGMENT: float = 10.0

const HEART: Texture2D = preload("res://ui/hud/art/icon_heart.png")
const DODGE: Texture2D = preload("res://ui/hud/art/icon_dodge.png")
const NOISE_MAKER: Texture2D = preload("res://ui/hud/art/icon_noise_maker.png")
const SAMPLE: Texture2D = preload("res://ui/hud/art/icon_sample.png")
const SCRAP: Texture2D = preload("res://ui/hud/art/icon_scrap.png")
const WEAPON_ART: Dictionary[StringName, Texture2D] = {
	&"pistol": preload("res://ui/hud/art/weapon_pistol.png"),
	&"shotgun": preload("res://ui/hud/art/weapon_shotgun.png"),
}
## An effect with less time than this left blinks its icon.
const EXPIRING_SECONDS: float = 2.5
## A newly started effect flashes for this long.
const NEW_SECONDS: float = 0.5

var settings: HudSettings = preload("res://data/hud.tres")
## Read only: each power-up's colour and full duration (for the duration bars).
var power_ups: PowerUpSet = preload("res://data/power_up_set.tres")
var player: Player:
	set(value):
		player = value
		if player != null:
			player.damaged.connect(func(_amount: float) -> void: _hurt_left = settings.hurt_flash_seconds)
			player.noise_maker_thrown.connect(func() -> void: _throw_flash = 0.3)

## HP ratio drawn by the drain chunk; it catches up with the real HP after a hit.
var _hp_shown: float = 1.0
var _time: float = 0.0
var _hurt_left: float = 0.0
var _throw_flash: float = 0.0
var _swap_flash: float = 0.0
var _ready_flash: float = 0.0
var _last_weapon: StringName = &""
## Active effect id -> seconds its "new" flash still shows.
var _new_effects: Dictionary = {}
var _seen_effects: Dictionary = {}
var _was_ready: bool = true


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS  # show 0 HP under the Game Over screen (game paused)


func _process(delta: float) -> void:
	_time += delta
	_hurt_left = maxf(_hurt_left - delta, 0.0)
	_throw_flash = maxf(_throw_flash - delta, 0.0)
	_swap_flash = maxf(_swap_flash - delta, 0.0)
	_ready_flash = maxf(_ready_flash - delta, 0.0)
	if player != null and player.stats != null:
		var ratio: float = health_ratio()
		_hp_shown = ratio if ratio >= _hp_shown else move_toward(_hp_shown, ratio, delta * 0.6)
		var weapon: StringName = player.active_weapon_id()
		if _last_weapon != &"" and weapon != _last_weapon:
			_swap_flash = 0.35
		_last_weapon = weapon
		var now: Dictionary = {}
		for e: Dictionary in active_effects():
			now[e["id"]] = true
			if not _seen_effects.has(e["id"]):
				_new_effects[e["id"]] = NEW_SECONDS
		_seen_effects = now
		for id: StringName in _new_effects.keys():
			_new_effects[id] -= delta
			if _new_effects[id] <= 0.0 or not now.has(id):
				_new_effects.erase(id)
		var ready: bool = player.dodge_cooldown_left <= 0.0
		if ready and not _was_ready:
			_ready_flash = 0.3
		_was_ready = ready
	queue_redraw()


func health_ratio() -> float:
	return clampf(player.health / player.stats.max_health, 0.0, 1.0)


func is_low_health() -> bool:
	var ratio: float = health_ratio()
	return ratio > 0.0 and ratio <= settings.low_health_ratio


## Text after the dodge bar: "RDY" when a roll is available, else the seconds left.
func dodge_text() -> String:
	var left: float = player.dodge_cooldown_left
	return "RDY" if left <= 0.0 else "%.1fs" % left


## The carried weapon that is not in hand ("" if only one is carried).
func spare_weapon_id() -> StringName:
	for id: StringName in player.loadout.carried():
		if id != player.active_weapon_id():
			return id
	return &""


## What the power-up cell shows: the shield while it holds, else the timed power-up with the most
## time left. {} when nothing is active. `more` counts the other active ones.
func active_boost() -> Dictionary:
	var ids: Array[StringName] = player.modifiers.temporary_ids()
	var others: int = ids.size()
	if player.shield > 0.0:
		return {"id": &"shield", "text": "%d" % ceili(player.shield), "more": others}
	var best: StringName = &""
	for id: StringName in ids:
		if best == &"" or player.modifiers.time_left(id) > player.modifiers.time_left(best):
			best = id
	if best == &"":
		return {}
	return {"id": best, "text": "%ds" % ceili(player.modifiers.time_left(best)), "more": others - 1}


## Every timed effect running, shield first, then by time left (most first):
## {id, left (s), total (s, the full duration), text (shield points or seconds)}.
func active_effects() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if player.shield > 0.0:
		out.append({"id": &"shield", "left": player.shield_left, "total": _full_duration(&"shield"),
			"text": "%d" % ceili(player.shield)})
	var boosts: Array[Dictionary] = []
	for id: StringName in player.modifiers.temporary_ids():
		var left: float = player.modifiers.time_left(id)
		boosts.append({"id": id, "left": left, "total": _full_duration(id), "text": "%ds" % ceili(left)})
	boosts.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["left"] > b["left"])
	out.append_array(boosts)
	return out


func _full_duration(id: StringName) -> float:
	var t: PowerUpType = power_ups.get_type(id) if power_ups != null else null
	if t == null:
		return 10.0
	return minf(t.duration, power_ups.max_duration)


func _draw() -> void:
	if player == null or player.stats == null:
		return
	var top: Vector2 = Vector2(0, size.y - HudLayout.STRIP_HEIGHT)
	var font: Font = MenuStyle.body_font()
	_draw_health(font, top)
	_draw_dodge(font, top)
	if player.is_concealed():  # stealth (GDD 4.3): hidden in tall grass while walking, not shooting
		var chip: Rect2 = _at(top, HudLayout.HIDDEN_CHIP)
		draw_rect(chip, Color(0.03, 0.12, 0.09, 0.95))
		draw_rect(Rect2(chip.position, Vector2(1, chip.size.y)), COLOR_HIDDEN)
		_text_centered(font, Vector2(chip.get_center().x + 1.0, chip.end.y - 2.0), "HIDDEN", COLOR_HIDDEN, TINY_FONT_SIZE)
	_draw_weapons(font, top)
	_draw_items(font, top)


func _at(top: Vector2, r: Rect2) -> Rect2:
	return Rect2(top + r.position, r.size)


func _draw_health(font: Font, top: Vector2) -> void:
	var ratio: float = health_ratio()
	var low: bool = is_low_health()
	var pulse: float = 0.5 + 0.5 * sin(_time * TAU / 0.9) if low else 0.0
	var hurt: float = _hurt_left / settings.hurt_flash_seconds
	var heart: Rect2 = _at(top, HudLayout.HEART)
	if low:  # the heart beats with the pulse
		heart = heart.grow(roundf(pulse))
	draw_texture_rect(HEART, heart, false, Color(1.0, 1.0, 1.0) if not player.is_dead else Color(0.4, 0.4, 0.4))
	var bar: Rect2 = _at(top, HudLayout.HP_BAR)
	if hurt > 0.0:  # a hit: the bar's rim flashes red for a moment
		draw_rect(bar.grow(2.0), Color(0.95, 0.2, 0.15, 0.7 * hurt))
	draw_rect(bar.grow(1.0), COLOR_BAR_BACK)
	draw_rect(Rect2(bar.position, Vector2(roundf(bar.size.x * _hp_shown), bar.size.y)), COLOR_HP_LOST)
	var fill: Color = COLOR_HP.lerp(COLOR_HP_LIGHT, pulse * 0.8)
	var w: float = roundf(bar.size.x * ratio)
	draw_rect(Rect2(bar.position, Vector2(w, bar.size.y)), fill)
	draw_rect(Rect2(bar.position, Vector2(w, 1.0)), fill.lightened(0.3))
	draw_rect(Rect2(bar.position + Vector2(0, bar.size.y - 1.0), Vector2(w, 1.0)), fill.darkened(0.35))
	var segments: int = int(player.stats.max_health / HP_SEGMENT)
	for i: int in range(1, segments):  # notches every 10 HP
		var x: float = roundf(bar.position.x + bar.size.x * i * HP_SEGMENT / player.stats.max_health)
		draw_rect(Rect2(x, bar.position.y, 1, bar.size.y), Color(0, 0, 0, 0.45))
	if low:  # thin warning line under the bar
		draw_rect(Rect2(bar.position + Vector2(0, bar.size.y + 2.0), Vector2(bar.size.x, 1)), Color(COLOR_HP_LIGHT, 0.25 + 0.5 * pulse))
	var value: String = "%d" % ceili(player.health)
	var value_colour: Color = COLOR_LOW if low or player.is_dead else COLOR_TEXT
	_text(MenuStyle.heading_font(), top + HudLayout.HP_VALUE, value, value_colour.lerp(Color(1.0, 0.35, 0.3), hurt), FONT_SIZE)


func _draw_dodge(font: Font, top: Vector2) -> void:
	var left: float = player.dodge_cooldown_left
	var ready: bool = left <= 0.0
	draw_texture_rect(DODGE, _at(top, HudLayout.DODGE_ICON), false, Color.WHITE if ready else Color(0.55, 0.55, 0.6))
	var gauge: Rect2 = _at(top, HudLayout.DODGE_BAR)
	var amount: float = 1.0 if ready else clampf(1.0 - left / player.stats.dodge_cooldown, 0.0, 1.0)
	draw_rect(gauge.grow(1.0), COLOR_BAR_BACK)
	var colour: Color = COLOR_DODGE if ready else COLOR_DODGE.darkened(0.3)
	draw_rect(Rect2(gauge.position, Vector2(roundf(gauge.size.x * amount), gauge.size.y)), colour)
	draw_rect(Rect2(gauge.position, Vector2(roundf(gauge.size.x * amount), 1.0)), COLOR_DODGE_LIGHT if ready else colour.lightened(0.25))
	if not ready:  # recharging: a bright tick riding the front edge
		draw_rect(Rect2(gauge.position + Vector2(roundf(gauge.size.x * amount), 0), Vector2(1, gauge.size.y)), COLOR_DODGE_LIGHT)
	if _ready_flash > 0.0:  # ready again: a short glint over the bar
		draw_rect(gauge.grow(1.0), Color(COLOR_DODGE_LIGHT, 0.6 * _ready_flash / 0.3))
	_text(font, top + HudLayout.DODGE_TEXT, dodge_text(), COLOR_DODGE_LIGHT if ready else COLOR_DIM, SMALL_FONT_SIZE)


func _draw_weapons(font: Font, top: Vector2) -> void:
	var area: Rect2 = _at(top, HudLayout.WEAPON_ART)
	var inlay: Rect2 = Rect2(area.position - Vector2(2, 1), Vector2(area.size.x + 4, HudLayout.STRIP_HEIGHT - 4.0))
	draw_rect(inlay, Color(0, 0, 0, 0.22))  # a darker inlay, no frame
	if _swap_flash > 0.0:
		draw_rect(inlay, Color(MenuStyle.EMBER, 0.18 * _swap_flash / 0.35))
		draw_rect(Rect2(inlay.position, Vector2(inlay.size.x, 1)), Color(MenuStyle.EMBER, 0.8 * _swap_flash / 0.35))
	var active: StringName = player.active_weapon_id()
	_weapon_art(WEAPON_ART.get(active), area, 0.5, Color.WHITE)
	var data: WeaponStats = WeaponLibrary.get_weapon(active)
	if data != null:
		_text_centered(MenuStyle.heading_font(), Vector2(area.get_center().x, top.y + HudLayout.WEAPON_NAME_BASELINE),
				data.display_name.to_upper(), COLOR_TEXT, SMALL_FONT_SIZE)
	var spare: StringName = spare_weapon_id()
	if spare == &"":
		return  # one weapon carried: no empty spare slot
	var key: Rect2 = _at(top, HudLayout.SWAP_KEY)
	draw_rect(key, Color(MenuStyle.RAISED, 0.95))
	draw_rect(Rect2(key.position.x, key.end.y - 1.0, key.size.x, 1), Color(MenuStyle.STEEL, 0.9))
	_text_centered(font, Vector2(key.get_center().x, key.end.y - 1.5), KeyHint.key(&"swap_weapon"), COLOR_TEXT, TINY_FONT_SIZE)
	_text(font, Vector2(key.end.x + 3.0, key.end.y - 1.5), "SWAP", COLOR_DIM, TINY_FONT_SIZE)
	_weapon_art(WEAPON_ART.get(spare), _at(top, HudLayout.SPARE_ART), 0.3, Color(0.7, 0.7, 0.72, 0.9))


## Weapon art (2x texture) at `art_scale` HUD px per texture px, shrunk further to fit `area`, centred.
func _weapon_art(art: Texture2D, area: Rect2, art_scale: float, tint: Color) -> void:
	if art == null:
		return
	var s: Vector2 = art.get_size() * art_scale
	s *= minf(1.0, minf(area.size.x / s.x, area.size.y / s.y))
	draw_texture_rect(art, Rect2((area.get_center() - s * 0.5).round(), s.round()), false, tint)


func _draw_items(font: Font, top: Vector2) -> void:
	# Noise-maker: icon (key letter on its corner), count, charge pips under the count.
	var r: Rect2 = _at(top, HudLayout.item(0))
	if player.noise_maker != null:
		var left: int = player.noise_makers_left
		if _throw_flash > 0.0:  # thrown: a warm glint under the cell
			draw_rect(Rect2(r.position.x, r.end.y, r.size.x, 1), Color(1.0, 0.8, 0.5, _throw_flash / 0.3))
		var key: Rect2 = Rect2(r.position + Vector2(0, 2), Vector2(6, 7))
		draw_rect(key, Color(MenuStyle.RAISED, 0.95))
		draw_rect(Rect2(key.position.x, key.end.y - 1.0, key.size.x, 1), Color(MenuStyle.STEEL, 0.9))
		_text_centered(font, Vector2(key.get_center().x, key.end.y - 1.5), KeyHint.key(&"throw_noise"), COLOR_TEXT, TINY_FONT_SIZE)
		var icon: Rect2 = _icon(NOISE_MAKER, Rect2(r.position + Vector2(7, 0), r.size - Vector2(7, 0)), left > 0)
		var x: float = icon.end.x + 1.0
		_text(font, Vector2(x, r.position.y + 7.0), "%d" % left, COLOR_TEXT if left > 0 else COLOR_DIM, SMALL_FONT_SIZE)
		var total: int = player.noise_maker.max_carried if player.noise_maker_inventory else left
		for i: int in mini(total, 5):
			draw_rect(Rect2(x + i * 3.0, r.position.y + 10.0, 2, 1), Color(0.86, 0.78, 0.6) if i < left else Color(0.3, 0.3, 0.32))
	# Power-ups: only while one runs (no empty slot).
	_draw_power_ups(font, _at(top, HudLayout.item(1)))
	# Samples (research) and scrap (Safehouse building), the run's collected resources.
	r = _at(top, HudLayout.item(2))
	var x2: float = _icon(SAMPLE, r, GameState.samples > 0).end.x + 2.0
	_text(font, Vector2(x2, r.position.y + 8.0), "%d" % GameState.samples, COLOR_TEXT if GameState.samples > 0 else COLOR_DIM, SMALL_FONT_SIZE)
	r = _at(top, HudLayout.item(3))
	var x3: float = _icon(SCRAP, r, GameState.scrap > 0).end.x + 2.0
	_text(font, Vector2(x3, r.position.y + 8.0), "%d" % GameState.scrap, COLOR_TEXT if GameState.scrap > 0 else COLOR_DIM, SMALL_FONT_SIZE)


## Active effects in the power-up cell: one icon per effect (9 px, 1 px apart), a bar under each
## draining over its duration; with a single effect its points / seconds sit beside it.
func _draw_power_ups(font: Font, r: Rect2) -> void:
	var effects: Array[Dictionary] = active_effects()
	for i: int in mini(effects.size(), 3):
		var e: Dictionary = effects[i]
		var id: StringName = e["id"]
		var at: Vector2 = Vector2(r.position.x + i * (PowerUpArt.ICON_SIZE + 1), r.position.y)
		var t: PowerUpType = power_ups.get_type(id) if power_ups != null else null
		var colour: Color = t.color if t != null else COLOR_TEXT
		var left: float = e["left"]
		var alpha: float = 1.0
		if left < EXPIRING_SECONDS:  # about to run out: the icon blinks softly
			alpha = 0.45 + 0.55 * absf(cos(_time * PI / 0.5))
		if _new_effects.has(id):  # just picked up: a bright plate behind the icon
			draw_rect(Rect2(at - Vector2.ONE, Vector2(11, 11)), Color(colour, 0.5 * _new_effects[id] / NEW_SECONDS))
		var tex: Texture2D = PowerUpArt.icon(id)
		if tex != null:
			draw_texture(tex, at, Color(1, 1, 1, alpha))
		else:
			_text(font, at + Vector2(0, 7), String(id).left(2).to_upper(), Color(colour, alpha), TINY_FONT_SIZE)
		var bar: Rect2 = Rect2(at + Vector2(0, PowerUpArt.ICON_SIZE + 1), Vector2(PowerUpArt.ICON_SIZE, 1))
		draw_rect(bar, COLOR_BAR_BACK)
		var k: float = clampf(left / maxf(float(e["total"]), 0.01), 0.0, 1.0)
		draw_rect(Rect2(bar.position, Vector2(roundf(bar.size.x * k), 1)), colour)
	if effects.size() == 1:
		_text(font, Vector2(r.position.x + PowerUpArt.ICON_SIZE + 2.0, r.position.y + 8.0), effects[0]["text"], COLOR_TEXT, SMALL_FONT_SIZE)


## Icon (2x art) fitted into a cell's left side, at most the cell's height; returns where it went.
func _icon(tex: Texture2D, cell: Rect2, has: bool) -> Rect2:
	var s: Vector2 = tex.get_size() * 0.5
	s *= minf(1.0, cell.size.y / s.y)
	s = s.round()
	var r: Rect2 = Rect2(Vector2(cell.position.x + roundf(maxf(9.0 - s.x, 0.0) * 0.5), roundf(cell.get_center().y - s.y * 0.5)), s)
	draw_texture_rect(tex, r, false, Color.WHITE if has else Color(0.45, 0.45, 0.48, 0.8))
	return Rect2(Vector2(cell.position.x, r.position.y), Vector2(maxf(9.0, s.x), s.y))


func _width(font: Font, text: String, font_size: int = FONT_SIZE) -> float:
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x


## Draws outlined text with its baseline at `pos` (whole pixels); returns the x where it ends.
func _text(font: Font, pos: Vector2, text: String, color: Color, font_size: int = FONT_SIZE) -> float:
	pos = pos.round()
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, 2, Color(0.02, 0.025, 0.035, 0.9))
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)
	return pos.x + _width(font, text, font_size)


func _text_centered(font: Font, pos: Vector2, text: String, color: Color, font_size: int = FONT_SIZE) -> void:
	_text(font, Vector2(pos.x - _width(font, text, font_size) * 0.5, pos.y), text, color, font_size)

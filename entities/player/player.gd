class_name Player
extends CharacterBody2D
## Player: WASD movement with acceleration, aims at the mouse, LMB shoots, Space dodge-rolls
## (brief invulnerability). Runners hit it via take_damage(). AimPivot (with the Muzzle) turns to
## the aim; Body is the upright visual (PlayerVisual) and only reads this script's state.

@export var stats: PlayerStats
@export var weapon: WeaponStats
## Temporary: print dodge state changes and tint the body while invulnerable.
@export var debug_dodge: bool = false
## Noise and stealth rules (data/perception.tres). null = no footsteps, never concealed.
@export var perception: PerceptionSettings
## Throwable noise-maker (data/noise_maker.tres). null = none.
@export var noise_maker: NoiseMakerSettings

## Permanent research + temporary power-up effects, applied on top of the base data (never saved
## into it). See PlayerModifiers.
var modifiers: PlayerModifiers = PlayerModifiers.new()
## The weapons owned / equipped (saved with the campaign) and which slot is in hand.
var loadout: PlayerLoadout = PlayerLoadout.new()
var active_slot: int = 0
## Absorbs damage before health does (power-up), and seconds until it fades.
var shield: float = 0.0
var shield_left: float = 0.0
## Spread of shots: seeded, so a replayed fight fires the same pellets.
var spread_rng: RandomNumberGenerator = RandomNumberGenerator.new()
## Emitted when the weapon in hand changes (swap, loadout).
signal weapon_changed()
## Emitted when a hit removes HP (`amount` = HP actually lost).
signal damaged(amount: float)
## Emitted once when HP reaches 0. The level ends the wave; revive() brings the player back.
signal died()
## B pressed: the player wants a barricade on `cell` (the tile it is facing). The level decides.
signal build_requested(cell: Vector2i)
## Visual hooks (PlayerVisual): once per trigger pull, per noise-maker thrown, and on revive().
signal shot_fired()
signal noise_maker_thrown()
signal revived()

## Current hit points.
var health: float = 0.0
## True from the killing hit until revive(): no moving, shooting or taking damage.
var is_dead: bool = false
## The untouched data resources; research and power-ups are applied to copies of these.
var _base_stats: PlayerStats
var _base_weapon: WeaponStats
## Unit vector from the player towards the mouse.
var aim_direction: Vector2 = Vector2.RIGHT
## The level's terrain (set by the level). Walking speed x the tile's player speed multiplier
## (mud 0.6, tall grass 0.8). null = full speed everywhere.
var terrain_grid: TerrainGrid
## Doors (F) and barricades: set by the level. null = no interaction.
var terrain_health: TerrainHealth
## Seconds since the last shot (stealth: shooting gives you away for a moment).
var seconds_since_shot: float = INF
## Noise-makers carried. Endless / prototype: refilled every wave (refill_throwables). Campaign
## level (Reactive Survival V2): start_level_inventory, refill pickups, Retry restores the count
## the wave started with (mark_wave_inventory / restore_wave_inventory).
var noise_makers_left: int = 0
var _noise_makers_at_wave_start: int = 0
## True in a campaign level (limited inventory with a maximum; HUD shows "n / max").
var noise_maker_inventory: bool = false
## Seconds until the next footstep noise.
var _footstep_left: float = 0.0
## True while the dodge's invulnerability window is open. Damage code will check this.
var is_invulnerable: bool:
	get:
		return _invuln_left > 0.0

## True during the roll's movement burst. For the visuals.
var is_dodging: bool:
	get:
		return _dodge_left > 0.0

## 0 at the start of a roll, towards 1 at its end. For the visuals.
var dodge_progress: float:
	get:
		return 1.0 - _dodge_left / stats.dodge_duration if _dodge_left > 0.0 else 0.0

## Where the current (or last) roll goes. For the visuals.
var dodge_direction: Vector2:
	get:
		return _dodge_direction

## Seconds until the next dodge is allowed (0 = ready). For the HUD.
var dodge_cooldown_left: float:
	get:
		return _dodge_cooldown_left

## Seconds until the weapon can fire again.
var _cooldown_left: float = 0.0
## Seconds left in the current dodge's movement burst (0 = not dodging).
var _dodge_left: float = 0.0
## Seconds left of invulnerability.
var _invuln_left: float = 0.0
## Seconds until the next dodge is allowed. Counts from the start of the dodge.
var _dodge_cooldown_left: float = 0.0
var _dodge_direction: Vector2 = Vector2.ZERO

@onready var _body: Node2D = $Body
@onready var _aim_pivot: Node2D = $AimPivot
@onready var _muzzle: Marker2D = $AimPivot/Muzzle


func _ready() -> void:
	_base_stats = stats
	_base_weapon = weapon
	health = stats.max_health
	modifiers.changed.connect(_rebuild_stats)
	spread_rng.seed = 20261016
	refill_throwables()


func _physics_process(delta: float) -> void:
	if is_dead:
		return
	seconds_since_shot += delta
	modifiers.tick(delta)
	_tick_shield(delta)
	_tick_dodge_timers(delta)
	_move(delta)
	_footsteps(delta)
	_aim()
	_shoot(delta)
	if Input.is_action_just_pressed("interact"):
		interact()
	if Input.is_action_just_pressed("swap_weapon"):
		swap_weapon()
	if Input.is_action_just_pressed("throw_noise"):
		throw_noise_maker(get_global_mouse_position())
	if Input.is_action_just_pressed("build") and terrain_grid != null:
		build_requested.emit(terrain_grid.coords.world_to_cell(global_position + aim_direction * 16.0))


## F: opens or closes the nearest door within one tile (ranged-only rule untouched: doors are
## not attacks). Returns true if something happened.
func interact() -> bool:
	if terrain_health == null or terrain_grid == null:
		return false
	var here: Vector2i = terrain_grid.coords.world_to_cell(global_position)
	var best: Vector2i = Vector2i(-1, -1)
	var best_dist: float = INF
	for dy: int in range(-1, 2):
		for dx: int in range(-1, 2):
			var c: Vector2i = here + Vector2i(dx, dy)
			var t: String = terrain_grid.get_terrain(c)
			if t != "door" and t != "door_open":
				continue
			var d: float = (terrain_grid.coords.cell_to_world(c) - (global_position + aim_direction * 8.0)).length()
			if d < best_dist:
				best_dist = d
				best = c
	if best_dist == INF:
		return false
	if terrain_grid.get_terrain(best) == "door":
		return terrain_health.open_door(best)
	return terrain_health.close_door(best)


## True while the player is hidden from enemies beyond their sense radius (GDD 4.3: walking,
## no shooting, inside tall grass). See Perception.is_concealed.
func is_concealed() -> bool:
	if perception == null or terrain_grid == null:
		return false
	var cell: Vector2i = terrain_grid.coords.world_to_cell(global_position)
	return Perception.is_concealed(terrain_grid.conceals(cell), seconds_since_shot, _dodge_left > 0.0, perception)


## Walking makes noise every footstep_interval, as loud as the tile under the player (grass
## quiet, road normal, mud / shallow water loud). Enemies only learn where it happened.
func _footsteps(delta: float) -> void:
	if perception == null or terrain_grid == null or _dodge_left > 0.0:
		return
	if velocity.length() < stats.move_speed * 0.25:
		_footstep_left = 0.0  # standing still: next step makes noise straight away
		return
	_footstep_left -= delta
	if _footstep_left > 0.0:
		return
	_footstep_left = perception.footstep_interval
	var definition: TerrainDefinition = terrain_grid.get_definition(terrain_grid.coords.world_to_cell(global_position))
	if definition == null:
		return
	var radius: float = Perception.footstep_radius(definition.noise, perception)
	if radius > 0.0:
		EventBus.noise_emitted.emit(global_position, radius)


func _move(delta: float) -> void:
	# get_vector normalises, so diagonals are no faster than straight lines.
	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if Input.is_action_just_pressed("dodge"):
		_try_dodge(input_dir)

	if _dodge_left > 0.0:
		# During the roll, input is ignored and speed is fixed.
		velocity = _dodge_direction * stats.dodge_speed
	elif input_dir != Vector2.ZERO:
		velocity = velocity.move_toward(input_dir * walk_speed(), stats.acceleration * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, stats.friction * delta)
	move_and_slide()


## Top walking speed on the current tile (the dodge roll is not slowed by terrain).
func walk_speed() -> float:
	if terrain_grid == null:
		return stats.move_speed
	return stats.move_speed * terrain_grid.player_speed_multiplier(terrain_grid.coords.world_to_cell(global_position))


func _try_dodge(input_dir: Vector2) -> void:
	if _dodge_cooldown_left > 0.0:
		_debug("dodge blocked, cooldown %.2fs left" % _dodge_cooldown_left)
		return
	# Roll where the player is steering; if no key is held, roll where they are aiming.
	_dodge_direction = input_dir if input_dir != Vector2.ZERO else aim_direction
	_dodge_left = stats.dodge_duration
	_invuln_left = stats.dodge_invulnerable_time
	_dodge_cooldown_left = stats.dodge_cooldown
	_debug("dodge START dir=%s invulnerable=true" % _dodge_direction)
	if perception != null and perception.dodge_noise_radius > 0.0:
		EventBus.noise_emitted.emit(global_position, perception.dodge_noise_radius)


func _tick_dodge_timers(delta: float) -> void:
	if _dodge_left > 0.0:
		_dodge_left = maxf(_dodge_left - delta, 0.0)
		if _dodge_left == 0.0:
			# Leave the roll at walking speed so the player doesn't overshoot.
			velocity = velocity.limit_length(walk_speed())
	if _invuln_left > 0.0:
		_invuln_left = maxf(_invuln_left - delta, 0.0)
		if _invuln_left == 0.0:
			_debug("invulnerability END")
	if _dodge_cooldown_left > 0.0:
		_dodge_cooldown_left = maxf(_dodge_cooldown_left - delta, 0.0)
		if _dodge_cooldown_left == 0.0:
			_debug("dodge READY")
	if debug_dodge:
		_body.modulate = Color(1, 1, 1, 0.4) if is_invulnerable else Color.WHITE


func _debug(message: String) -> void:
	if debug_dodge:
		print("[%.2fs] %s" % [Time.get_ticks_msec() / 1000.0, message])


func _aim() -> void:
	var to_mouse: Vector2 = get_global_mouse_position() - global_position
	if to_mouse.length_squared() > 1.0:
		aim_direction = to_mouse.normalized()
	# Only the muzzle turns; the collision shape and the Body visual stay upright.
	_aim_pivot.rotation = aim_direction.angle()


func _shoot(delta: float) -> void:
	_cooldown_left = maxf(_cooldown_left - delta, 0.0)
	var wants_fire: bool
	if weapon.automatic:
		wants_fire = Input.is_action_pressed("shoot")
	else:
		wants_fire = Input.is_action_just_pressed("shoot")
	if not wants_fire or _cooldown_left > 0.0:
		return
	_cooldown_left = weapon.fire_cooldown

	# One projectile per pellet, fanned over the weapon's spread cone (seeded jitter inside each slice).
	for i: int in weapon.pellets:
		var bullet: Bullet = weapon.projectile_scene.instantiate() as Bullet
		bullet.setup(_pellet_direction(i), weapon.projectile_speed, weapon.damage, weapon.projectile_lifetime)
		bullet.global_position = _muzzle.global_position
		# Bullets live in the level, not under the player, so they don't move with it.
		get_parent().add_child(bullet)
	# Gunshots are loud: enemies in range learn where the player WAS, not where they go next.
	EventBus.noise_emitted.emit(global_position, weapon.noise_radius)
	seconds_since_shot = 0.0
	shot_fired.emit()


# --- Noise-maker ---------------------------------------------------------------------

## Endless / prototype loop: back to the full count (start of every wave, and Retry).
func refill_throwables() -> void:
	noise_makers_left = noise_maker.count_per_area if noise_maker != null else 0


## Campaign level: the count every level starts with.
func start_level_inventory() -> void:
	noise_maker_inventory = true
	noise_makers_left = mini(noise_maker.level_start_count, noise_maker.max_carried) if noise_maker != null else 0
	_noise_makers_at_wave_start = noise_makers_left


## Campaign level: remember the count at the start of a wave (Retry goes back to it).
func mark_wave_inventory() -> void:
	_noise_makers_at_wave_start = noise_makers_left


func restore_wave_inventory() -> void:
	noise_makers_left = _noise_makers_at_wave_start


## A refill pickup: adds up to `amount`, never above max_carried. Returns how many were added.
func add_noise_makers(amount: int) -> int:
	if noise_maker == null:
		return 0
	var added: int = clampi(noise_maker.max_carried - noise_makers_left, 0, amount)
	noise_makers_left += added
	return added


## G: throws a noise-maker towards `target` (at most max_range, stopped by walls). It makes its
## noise where it lands; throwing it is silent and does not break concealment. Returns the
## thrown node, or null if there is none left.
func throw_noise_maker(target: Vector2) -> NoiseMaker:
	if noise_maker == null or noise_makers_left <= 0 or terrain_grid == null:
		return null
	noise_makers_left -= 1
	var landing: Vector2 = NoiseMaker.landing_point(terrain_grid, global_position, target, noise_maker.max_range)
	var thrown: NoiseMaker = NoiseMaker.new()
	thrown.setup(global_position, landing, noise_maker.flight_time, noise_maker.noise_radius)
	get_parent().add_child(thrown)
	noise_maker_thrown.emit()
	return thrown


# --- Health --------------------------------------------------------------------------

## Called by enemy attacks. Returns the HP actually removed: 0 while dodging (invulnerable)
## or dead, and never more than the HP left (overkill doesn't count for enemy fitness).
func take_damage(amount: float) -> float:
	if is_dead or is_invulnerable or amount <= 0.0:
		return 0.0
	if shield > 0.0:  # the shield soaks first; only what gets through counts as damage dealt
		var soaked: float = minf(shield, amount)
		shield -= soaked
		amount -= soaked
		if amount <= 0.0:
			return 0.0
	var dealt: float = minf(amount, health)
	health -= dealt
	_body.modulate = Color(1.0, 0.3, 0.3)
	create_tween().tween_property(_body, "modulate", Color.WHITE, 0.15)
	damaged.emit(dealt)
	if health <= 0.0:
		health = 0.0
		is_dead = true
		velocity = Vector2.ZERO
		_body.modulate = Color(0.4, 0.4, 0.4, 0.6)
		died.emit()
	return dealt


## Full HP and control again (called at the start of every wave).
func revive() -> void:
	is_dead = false
	health = stats.max_health
	shield = 0.0
	shield_left = 0.0
	modifiers.clear_temporary()  # temporary effects don't survive a lost attempt
	_invuln_left = 0.0
	_body.modulate = Color.WHITE
	revived.emit()


# --- Stats ---------------------------------------------------------------------------

## Rebuilds stats and weapon from the base data + permanent research + temporary effects, so a
## change takes effect on the next frame. Extra max health is also added to current health.
func _rebuild_stats() -> void:
	var old_max: float = stats.max_health
	stats = modifiers.apply(_base_stats, StatModifier.Target.PLAYER) as PlayerStats
	weapon = modifiers.apply(_base_weapon, StatModifier.Target.WEAPON) as WeaponStats
	health = minf(health + maxf(stats.max_health - old_max, 0.0), stats.max_health)


# --- Weapons, research, power-ups ----------------------------------------------------------

## Direction of pellet `index` of the current shot: an even fan across the spread cone plus a
## small seeded jitter inside the pellet's slice. A single pellet with no spread flies straight.
func _pellet_direction(index: int) -> Vector2:
	if weapon.spread_degrees <= 0.0:
		return aim_direction
	var slice: float = weapon.spread_degrees / weapon.pellets
	var centre: float = -weapon.spread_degrees * 0.5 + slice * (index + 0.5)
	var jitter: float = spread_rng.randf_range(-0.5, 0.5) * slice
	return aim_direction.rotated(deg_to_rad(centre + jitter))


## Takes this loadout (weapons owned / equipped) and puts the first slot in hand.
func apply_loadout(new_loadout: PlayerLoadout) -> void:
	loadout = new_loadout
	active_slot = 0
	_equip_active()


## Q: switch to the other carried weapon. It needs its draw time before it can fire.
func swap_weapon() -> void:
	var carried: Array[StringName] = loadout.carried()
	if carried.size() < 2:
		return
	active_slot = 1 - active_slot
	if loadout.equipped[active_slot] == &"":
		active_slot = 1 - active_slot
	_equip_active()
	_cooldown_left = maxf(_cooldown_left, WeaponLibrary.get_weapon(loadout.equipped[active_slot]).draw_time)


func active_weapon_id() -> StringName:
	return loadout.equipped[active_slot]


func _equip_active() -> void:
	var data: WeaponStats = WeaponLibrary.get_weapon(loadout.equipped[active_slot])
	_base_weapon = data if data != null else _base_weapon
	_rebuild_stats()
	weapon_changed.emit()


## Permanent research effects (from ResearchState), on top of the base stats. Extra max health is
## added to current health.
func set_research(mods: Array[StatModifier]) -> void:
	modifiers.set_research(mods)


## Instant heal, never above max health. Returns the HP restored.
func heal(amount: float) -> float:
	if is_dead or amount <= 0.0:
		return 0.0
	var restored: float = minf(amount, stats.max_health - health)
	health += restored
	return restored


## Power-up shield: absorbs up to `amount` damage for `seconds`. A shield already up is refreshed to
## at least this much, never added to (no stacking).
func add_shield(amount: float, seconds: float) -> void:
	shield = maxf(shield, amount)
	shield_left = maxf(shield_left, seconds)


func _tick_shield(delta: float) -> void:
	if shield > 0.0:
		shield_left -= delta
		if shield_left <= 0.0:
			shield = 0.0
			shield_left = 0.0


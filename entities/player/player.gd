class_name Player
extends CharacterBody2D
## Greybox player: WASD movement with acceleration, body turns to face the mouse,
## LMB shoots, Space dodge-rolls (movement only, no damage).

@export var stats: PlayerStats
@export var weapon: WeaponStats
## Temporary: print dodge state changes and tint the body while invulnerable.
@export var debug_dodge: bool = true

## Unit vector from the player towards the mouse.
var aim_direction: Vector2 = Vector2.RIGHT
## True while the dodge's invulnerability window is open. Damage code will check this.
var is_invulnerable: bool:
	get:
		return _invuln_left > 0.0

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
@onready var _muzzle: Marker2D = $Body/Muzzle


func _physics_process(delta: float) -> void:
	_tick_dodge_timers(delta)
	_move(delta)
	_aim()
	_shoot(delta)


func _move(delta: float) -> void:
	# get_vector normalises, so diagonals are no faster than straight lines.
	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if Input.is_action_just_pressed("dodge"):
		_try_dodge(input_dir)

	if _dodge_left > 0.0:
		# During the roll, input is ignored and speed is fixed.
		velocity = _dodge_direction * stats.dodge_speed
	elif input_dir != Vector2.ZERO:
		velocity = velocity.move_toward(input_dir * stats.move_speed, stats.acceleration * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, stats.friction * delta)
	move_and_slide()


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


func _tick_dodge_timers(delta: float) -> void:
	if _dodge_left > 0.0:
		_dodge_left = maxf(_dodge_left - delta, 0.0)
		if _dodge_left == 0.0:
			# Leave the roll at walking speed so the player doesn't overshoot.
			velocity = velocity.limit_length(stats.move_speed)
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
	# Only the visual turns; the collision shape stays upright.
	_body.rotation = aim_direction.angle()


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

	var bullet: Bullet = weapon.projectile_scene.instantiate() as Bullet
	bullet.setup(aim_direction, weapon.projectile_speed, weapon.damage, weapon.projectile_lifetime)
	bullet.global_position = _muzzle.global_position
	# Bullets live in the level, not under the player, so they don't move with it.
	get_parent().add_child(bullet)

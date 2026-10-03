class_name Player
extends CharacterBody2D
## Greybox player: WASD movement with acceleration, body turns to face the mouse,
## LMB shoots, Space dodge-rolls (movement only, no damage).

@export var stats: PlayerStats
@export var weapon: WeaponStats
## XP curve and enemy XP values (data/progression.tres).
@export var progression_settings: ProgressionSettings
## The skill nodes the player can buy (data/skill_tree.tres).
@export var skill_tree: SkillTree
## Temporary: print dodge state changes and tint the body while invulnerable.
@export var debug_dodge: bool = true

## XP, level and skill points. Lives on the player, so it carries over between waves.
var progression: PlayerProgression
## Bought skill nodes. `stats` and `weapon` are rebuilt from the base data whenever this changes.
var skills: PlayerSkills
## Current hit points. Nothing damages the player yet.
var health: float = 0.0
## The untouched data resources; skills are applied to copies of these.
var _base_stats: PlayerStats
var _base_weapon: WeaponStats
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


func _ready() -> void:
	progression = PlayerProgression.new(progression_settings)
	progression.leveled_up.connect(_on_leveled_up)
	_base_stats = stats
	_base_weapon = weapon
	health = stats.max_health
	skills = PlayerSkills.new(skill_tree, progression)
	skills.changed.connect(_apply_skills)
	EventBus.enemy_killed.connect(_on_enemy_killed)


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
	# Gunshots are loud: enemies in range learn where the player WAS, not where they go next.
	EventBus.noise_emitted.emit(global_position, weapon.noise_radius)


# --- Skills --------------------------------------------------------------------------

## Rebuilds stats and weapon from the base data + every owned skill, so a purchase takes
## effect on the next frame. Extra max health is also added to current health.
func _apply_skills() -> void:
	var old_max: float = stats.max_health
	stats = skills.apply(_base_stats, SkillNode.Target.PLAYER) as PlayerStats
	weapon = skills.apply(_base_weapon, SkillNode.Target.WEAPON) as WeaponStats
	health = minf(health + maxf(stats.max_health - old_max, 0.0), stats.max_health)


# --- XP ------------------------------------------------------------------------------

## Every kill gives XP; enemies with more stat points (later, more evolved waves) give a bit more.
func _on_enemy_killed(enemy: Node2D) -> void:
	var genome: Genome = enemy.get("genome") as Genome
	var stat_total: float = genome.stat_total() if genome != null else progression_settings.reference_stat_total
	progression.add_xp(progression_settings.enemy_xp(stat_total))


func _on_leveled_up(new_level: int) -> void:
	print("[XP] level up -> %d  (skill points %d, total XP %d)" % [
		new_level, progression.skill_points, progression.total_xp])

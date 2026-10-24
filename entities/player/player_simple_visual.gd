class_name PlayerSimpleVisual
extends Node2D
## Deadline player look (visual only): one static full-body pose per aim quarter (E, S, W, N),
## animated with transforms instead of frames: walk bob tied to distance, idle breath, recoil kick
## and muzzle flash on Player.shot_fired, hurt jitter, dodge squash with afterimages, death fall.
## Used by PlayerVisual while the layered rig art is missing. Own RNG; reads the player only.

const PIVOT: Vector2 = Vector2(40, 72)
const ART_SCALE: float = 0.5
## Recoil kick (world px) and how fast it settles (px/s).
const RECOIL: float = 1.5
const RECOIL_RETURN: float = 14.0
const GHOST_EVERY: float = 0.05

var _player: Player
var _settings: PlayerVisualSettings
var _sprite: Sprite2D
var _flash: Sprite2D
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _t: float = 0.0
var _walked: float = 0.0
var _since_shot: float = INF
var _since_hurt: float = INF
var _recoil: Vector2 = Vector2.ZERO
var _fall: float = 0.0
var _ghost_left: float = 0.0


func setup(player: Player, settings: PlayerVisualSettings) -> void:
	_player = player
	_settings = settings
	_rng.seed = 4242
	var shadow: GroundShadow = GroundShadow.new()
	shadow.name = "Shadow"
	shadow.radius = Vector2(7, 2.5)
	add_child(shadow)
	_sprite = Sprite2D.new()
	_sprite.name = "Pose"
	_sprite.texture = settings.simple_poses
	_sprite.hframes = 4
	_sprite.centered = false
	_sprite.offset = -PIVOT
	_sprite.scale = Vector2(ART_SCALE, ART_SCALE)
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_sprite)
	_flash = Sprite2D.new()
	_flash.name = "MuzzleFlash"
	_flash.texture = settings.simple_flash
	_flash.hframes = 3
	_flash.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var additive: CanvasItemMaterial = CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_flash.material = additive
	_flash.visible = false
	add_child(_flash)
	player.shot_fired.connect(_on_shot)
	player.damaged.connect(func(_amount: float) -> void: _since_hurt = 0.0)


func _on_shot() -> void:
	_since_shot = 0.0
	_recoil = -_player.aim_direction * RECOIL


func step(delta: float, aim: float) -> void:
	_t += delta
	_since_shot += delta
	_since_hurt += delta
	_sprite.frame = PlayerVisual.sector4(aim)
	var dead: bool = _player.is_dead
	_fall = move_toward(_fall, 1.0 if dead else 0.0, delta * (4.0 if dead else 8.0))
	var bob: float = 0.0
	var speed: float = _player.velocity.length()
	if dead:
		pass
	elif speed >= _settings.walk_threshold:
		_walked += speed * delta
		# Two steps per stride: the body rises on each step.
		bob = absf(sin(_walked / _settings.stride_length * TAU)) * 1.0
	else:
		# Idle breath in the 0 / 1 / 2 / 1 rhythm of the torso loop (half world px per step).
		bob = [0.0, 0.5, 0.5, 0.0][posmod(floori(_t * _settings.idle_fps), 4)]
	_recoil = _recoil.move_toward(Vector2.ZERO, RECOIL_RETURN * delta)
	var jitter: Vector2 = Vector2.ZERO
	if _since_hurt < 0.15 and not dead:
		jitter = Vector2(_rng.randf_range(-0.6, 0.6), _rng.randf_range(-0.4, 0.4))
	var offset: Vector2 = Vector2(0.0, -bob) + _recoil + jitter + Vector2(0.0, _fall * 2.0)
	_sprite.position = (offset * 2.0).round() / 2.0  # half world px = one art pixel
	_sprite.rotation = _fall * PI / 2.0 * (1.0 if cos(aim) >= 0.0 else -1.0)
	if _player.is_dodging and not dead:
		_sprite.scale = Vector2(ART_SCALE * 1.08, ART_SCALE * 0.86)
		_ghost_left -= delta
		if _ghost_left <= 0.0:
			_ghost_left = GHOST_EVERY
			_spawn_ghost()
	else:
		_sprite.scale = Vector2(ART_SCALE, ART_SCALE)
		_ghost_left = 0.0
	_update_flash(aim, dead)


func _update_flash(aim: float, dead: bool) -> void:
	var frames: float = 3.0 / _settings.flash_fps
	if dead or _since_shot >= frames or _settings.simple_flash == null:
		_flash.visible = false
		return
	var muzzle: Node2D = _player.get_node_or_null("AimPivot/Muzzle") as Node2D
	if muzzle != null:
		_flash.global_position = muzzle.global_position
	_flash.frame = mini(floori(_since_shot * _settings.flash_fps), 2)
	var big: bool = _player.weapon != null and _player.weapon.pellets > 1
	_flash.scale = Vector2.ONE * ART_SCALE * (1.7 if big else 1.0)
	_flash.rotation = aim
	_flash.visible = true


## A fading copy of the current pose left behind during a dodge roll.
func _spawn_ghost() -> void:
	var world: Node = _player.get_parent()
	if world == null:
		return
	var ghost: Sprite2D = Sprite2D.new()
	ghost.texture = _sprite.texture
	ghost.hframes = _sprite.hframes
	ghost.frame = _sprite.frame
	ghost.centered = false
	ghost.offset = _sprite.offset
	ghost.scale = _sprite.scale
	ghost.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ghost.modulate = Color(0.75, 0.35, 0.3, 0.45)
	world.add_child(ghost)
	ghost.global_position = _sprite.global_position
	var fade: Tween = ghost.create_tween()
	fade.tween_property(ghost, "modulate:a", 0.0, 0.2)
	fade.tween_callback(ghost.queue_free)

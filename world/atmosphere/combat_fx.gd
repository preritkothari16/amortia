class_name CombatFx
extends Node2D
## Combat feedback (visual only): sparks where bullets hit walls, blood where they hit enemies,
## a splat + fading corpse + burst when an enemy dies, muzzle light and small camera shakes.
## Own RNG; reads gameplay signals, never changes gameplay.

const PIXEL: Vector2i = Vector2i(1, 1)

var _atmosphere: Atmosphere
var _player: Node2D
var _camera: Camera2D
var _settings: VisualFxSettings
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _pixel: ImageTexture
var _shake_amp: float = 0.0
var _shake_left: float = 0.0
var _blood: Gradient
var _sparks: Gradient
var _spores: Gradient
var _dust: Gradient
var _splinters: Gradient


func setup(atmosphere: Atmosphere, player: Node2D, settings: VisualFxSettings) -> void:
	_atmosphere = atmosphere
	_player = player
	_settings = settings
	_camera = player.get_node_or_null("Camera2D") as Camera2D
	_rng.seed = 7331
	add_to_group(&"combat_fx")
	var img: Image = Image.create(PIXEL.x, PIXEL.y, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	_pixel = ImageTexture.create_from_image(img)
	_blood = _gradient([Color(0.62, 0.06, 0.05), Color(0.3, 0.02, 0.03, 0.0)])
	_sparks = _gradient([Color(1, 0.95, 0.7), Color(1, 0.55, 0.2), Color(0.4, 0.1, 0.05, 0.0)])
	_spores = _gradient([Color(1, 0.7, 0.35), Color(0.85, 0.25, 0.12, 0.0)])
	_dust = _gradient([Color(0.62, 0.6, 0.56, 0.7), Color(0.4, 0.38, 0.36, 0.35), Color(0.3, 0.28, 0.27, 0.0)])
	_splinters = _gradient([Color(0.62, 0.48, 0.32), Color(0.36, 0.25, 0.16, 0.0)])
	EventBus.enemy_killed.connect(_on_enemy_killed)
	EventBus.terrain_hit.connect(_on_terrain_hit)
	if player.has_signal("shot_fired"):
		player.shot_fired.connect(_on_shot)
		player.damaged.connect(_on_player_damaged)


## Called by EnemySprite when its enemy takes a hit.
func blood_spray(at: Vector2) -> void:
	_burst(at, _blood, 7, 25.0, 70.0, 0.35, 1.0, 1.5)


func _on_shot() -> void:
	var muzzle: Node2D = _player.get_node_or_null("AimPivot/Muzzle") as Node2D
	if muzzle != null:
		_atmosphere.flash(muzzle.global_position)
	var weapon: WeaponStats = _player.weapon as WeaponStats
	_shake(_settings.shake_shotgun if weapon != null and weapon.pellets > 1 else _settings.shake_shot)


func _on_player_damaged(_amount: float) -> void:
	_shake(_settings.shake_hurt)
	_atmosphere.hurt_pulse()


func _on_terrain_hit(at: Vector2, _damage: float) -> void:
	_burst(at, _sparks, 6, 30.0, 90.0, 0.22, 1.0, 1.0)


## A fence / door / barricade broke (TerrainView forwards TerrainHealth.tile_destroyed): a dust
## cloud, flying splinters and rubble left on the cell. Look only; the grid already changed.
func tile_broken(rect: Rect2, terrain: String) -> void:
	var at: Vector2 = rect.get_center()
	_burst(at, _dust, 18, 6.0, 26.0, 1.1, 1.0, 3.0)
	_burst(at, _splinters, 12, 40.0, 110.0, 0.35, 1.0, 2.0)
	_shake(_settings.shake_shotgun * 0.6)
	if _atmosphere.decals != null and is_instance_valid(_atmosphere.decals):
		_atmosphere.decals.add_rubble(rect, terrain, _rng)


func _on_enemy_killed(enemy: Node2D) -> void:
	var at: Vector2 = enemy.global_position
	if _atmosphere.decals != null and is_instance_valid(_atmosphere.decals):
		_atmosphere.decals.add_splat(at, _rng)
	_burst(at, _blood, 14, 20.0, 80.0, 0.5, 1.0, 2.0)
	_burst(at, _spores, 8, 8.0, 30.0, 0.9, 1.0, 1.0)
	_leave_corpse(enemy)


## A darkened copy of the enemy's sprite, knocked over, that fades out. Under the map's decals
## node, so it is lit like the ground and removed with the area.
func _leave_corpse(enemy: Node2D) -> void:
	var sprite: Sprite2D = enemy.get_node_or_null("Body/Sprite") as Sprite2D
	if sprite == null or _atmosphere.decals == null or not is_instance_valid(_atmosphere.decals):
		return
	var corpse: Sprite2D = Sprite2D.new()
	corpse.texture = sprite.texture
	corpse.hframes = sprite.hframes
	corpse.frame = 0
	corpse.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	corpse.material = _atmosphere.ground_material
	corpse.scale = sprite.global_scale
	corpse.rotation = sprite.global_rotation + _rng.randf_range(-0.6, 0.6)
	corpse.modulate = sprite.modulate.darkened(0.45)
	_atmosphere.decals.add_child(corpse)
	corpse.global_position = enemy.global_position
	var fade: Tween = corpse.create_tween()
	fade.tween_interval(_settings.corpse_seconds)
	fade.tween_property(corpse, "modulate:a", 0.0, 1.5)
	fade.tween_callback(corpse.queue_free)


func _shake(amount: float) -> void:
	_shake_amp = maxf(_shake_amp * (_shake_left / _settings.shake_time), amount)
	_shake_left = _settings.shake_time


func _process(delta: float) -> void:
	if _camera == null:
		return
	if _shake_left <= 0.0:
		_camera.offset = Vector2.ZERO
		return
	_shake_left = maxf(_shake_left - delta, 0.0)
	var k: float = _shake_left / _settings.shake_time
	_camera.offset = Vector2(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1)) * _shake_amp * k


func _burst(at: Vector2, colours: Gradient, amount: int, speed_min: float, speed_max: float,
		life: float, size_min: float, size_max: float) -> void:
	var p: CPUParticles2D = CPUParticles2D.new()
	p.texture = _pixel
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = amount
	p.lifetime = life
	p.spread = 180.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = speed_min
	p.initial_velocity_max = speed_max
	p.damping_min = speed_max * 1.5
	p.damping_max = speed_max * 2.5
	p.scale_amount_min = size_min
	p.scale_amount_max = size_max
	p.color_ramp = colours
	p.local_coords = false
	p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	p.position = at
	p.finished.connect(p.queue_free)
	add_child(p)
	p.emitting = true


func _gradient(colours: Array) -> Gradient:
	var offsets: PackedFloat32Array = PackedFloat32Array()
	var points: PackedColorArray = PackedColorArray()
	for i: int in colours.size():
		offsets.append(float(i) / maxf(colours.size() - 1, 1))
		points.append(colours[i])
	var g: Gradient = Gradient.new()
	g.offsets = offsets
	g.colors = points
	return g

class_name PlayerVisual
extends Node2D
## Layered sprite rig for the Forsaken Scientist, on the Player's Body node. Body never rotates:
## the art picks a direction-specific frame instead (legs by movement, torso by aim sector, gun
## arm by one of 16 aim angles). It only READS the player; bullets still spawn at AimPivot/Muzzle.
## Body.modulate (hit flash, death grey, debug dodge tint) tints every layer as before.
## Until the required sheets are set in data/player_visual.tres it shows the simple static-pose
## look (PlayerSimpleVisual, if simple_poses is set), else the greybox shape.

const FRAME: int = 80
## Feet centre inside every frame.
const PIVOT: Vector2 = Vector2(40, 72)
## Art is drawn at twice the world density: 2 art px = 1 world px.
const ART_SCALE: float = 0.5
const ARM_ANGLES: int = 16
## [columns, rows] of every sheet. Must match art_src/forsaken_scientist/scripts/spec.py.
const LAYOUT: Dictionary = {
	&"legs_idle": Vector2i(1, 8),
	&"legs_walk": Vector2i(6, 8),
	&"torso_idle": Vector2i(4, 8),
	&"torso_walk": Vector2i(6, 8),
	&"torso_throw": Vector2i(4, 8),
	&"torso_hurt": Vector2i(2, 8),
	&"gunarm": Vector2i(4, 16),
	&"gunarm_glow": Vector2i(4, 16),
	&"muzzle_flash": Vector2i(3, 16),
	&"muzzle_flash_shotgun": Vector2i(3, 16),
	&"roll": Vector2i(6, 8),
	&"death": Vector2i(8, 4),
	&"shadow": Vector2i(1, 1),
}
const REQUIRED: Array[StringName] = [&"legs_walk", &"torso_idle", &"gunarm"]

@export var settings: PlayerVisualSettings

## Sheets that passed the size check (name -> texture). Missing / wrong-sized ones are left out.
var _sheets: Dictionary = {}
var _has_art: bool = false
## Distance walked, signed (negative while walking backwards), drives the stride.
var _stride: float = 0.0
var _idle_time: float = 0.0
## Seconds since the last shot / throw / hit / death (INF = not happening).
var _since_shot: float = INF
var _since_throw: float = INF
var _since_hurt: float = INF
var _since_death: float = INF
var _death_row: int = 0

var _player: Player
@onready var _greybox: Node2D = $Greybox
var _shadow: Sprite2D
var _legs: Sprite2D
var _torso: Sprite2D
var _arm_group: Node2D
var _arm: Sprite2D
var _glow: Sprite2D
var _flash: Sprite2D
var _full: Sprite2D
var _simple: PlayerSimpleVisual


func _ready() -> void:
	_player = get_parent() as Player
	_shadow = _make_layer("Shadow", self)
	_legs = _make_layer("Legs", self)
	_arm_group = Node2D.new()
	_arm_group.name = "GunArm"
	add_child(_arm_group)
	_arm = _make_layer("Arm", _arm_group)
	_glow = _make_layer("Glow", _arm_group)
	_torso = _make_layer("Torso", self)
	_flash = _make_layer("Flash", self)
	_full = _make_layer("FullBody", self)
	if _player != null:
		_player.shot_fired.connect(func() -> void: _since_shot = 0.0)
		_player.noise_maker_thrown.connect(func() -> void: _since_throw = 0.0)
		_player.damaged.connect(func(_amount: float) -> void: _since_hurt = 0.0)
		_player.died.connect(_on_died)
		_player.revived.connect(func() -> void: _since_death = INF)
	reload_art()


func _process(delta: float) -> void:
	step(delta)


## True when the required sheets are present and the layered art is drawn.
func has_art() -> bool:
	return _has_art


## True when the simple static-pose look is drawn instead (no layered art yet).
func has_simple_art() -> bool:
	return _simple != null and _simple.visible


## Re-reads the sheets from `settings` (call after assigning new ones).
func reload_art() -> void:
	_sheets.clear()
	if settings != null:
		for sheet: StringName in LAYOUT:
			var texture: Texture2D = settings.get(sheet) as Texture2D
			if texture == null:
				continue
			var want: Vector2i = LAYOUT[sheet] * FRAME
			if Vector2i(texture.get_size()) != want:
				push_warning("player art '%s' is %s, expected %s; ignored" % [sheet, Vector2i(texture.get_size()), want])
				continue
			_sheets[sheet] = texture
	_has_art = REQUIRED.all(func(sheet: StringName) -> bool: return _sheets.has(sheet))
	var use_simple: bool = not _has_art and settings != null and settings.simple_poses != null and _player != null
	if use_simple and _simple == null:
		_simple = PlayerSimpleVisual.new()
		_simple.name = "Simple"
		add_child(_simple)
		_simple.setup(_player, settings)
	if _simple != null:
		_simple.visible = use_simple
	_greybox.visible = not _has_art and not use_simple
	for layer: Sprite2D in [_shadow, _legs, _arm, _glow, _torso, _flash, _full]:
		layer.visible = false


## Advances the animation clocks and picks this frame's sprites.
func step(delta: float) -> void:
	if _player == null:
		return
	_since_shot += delta
	_since_throw += delta
	_since_hurt += delta
	_since_death += delta
	_idle_time += delta
	var aim: float = _player.aim_direction.angle()
	if not _has_art:
		if has_simple_art():
			_simple.step(delta, aim)
		else:
			_greybox.rotation = aim
		return
	_show(_shadow, &"shadow", 0, 0)
	if _player.is_dead:
		_draw_dead(aim)
		return
	if _player.is_dodging and _sheets.has(&"roll"):
		var roll_frame: int = mini(floori(_player.dodge_progress * 6.0), 5)
		_draw_full(&"roll", sector8(_player.dodge_direction.angle()), roll_frame)
		return
	_full.visible = false
	_draw_legs(delta, aim)
	_draw_torso(aim)
	_draw_arm(aim)


func _draw_dead(aim: float) -> void:
	_flash.visible = false
	if not _sheets.has(&"death"):
		_full.visible = false
		_draw_torso(aim)  # no death sheet yet: stand still, greyed by Body.modulate
		_show(_legs, &"legs_idle" if _sheets.has(&"legs_idle") else &"legs_walk", 0, sector8(aim))
		_draw_arm(aim)
		return
	_draw_full(&"death", _death_row, mini(floori(_since_death * settings.death_fps), 7))


func _draw_full(sheet: StringName, row: int, col: int) -> void:
	for layer: Sprite2D in [_legs, _torso, _arm, _glow, _flash]:
		layer.visible = false
	_show(_full, sheet, col, row)


func _draw_legs(delta: float, aim: float) -> void:
	var velocity: Vector2 = _player.velocity
	if velocity.length() < settings.walk_threshold:
		if _sheets.has(&"legs_idle"):
			_show(_legs, &"legs_idle", 0, sector8(aim))
		else:
			_show(_legs, &"legs_walk", 0, sector8(aim))
		return
	var legs: Vector2i = leg_row(velocity.angle(), aim)
	_stride += velocity.length() * delta * legs.y
	_show(_legs, &"legs_walk", walk_frame(_stride, settings.stride_length, 6), legs.x)


func _draw_torso(aim: float) -> void:
	var row: int = sector8(aim)
	var moving: bool = _player.velocity.length() >= settings.walk_threshold and not _player.is_dead
	if _sheets.has(&"torso_hurt") and _since_hurt < 2.0 / settings.hurt_fps:
		_show(_torso, &"torso_hurt", floori(_since_hurt * settings.hurt_fps), row)
	elif _sheets.has(&"torso_throw") and _since_throw < 4.0 / settings.throw_fps:
		_show(_torso, &"torso_throw", floori(_since_throw * settings.throw_fps), row)
	elif moving and _sheets.has(&"torso_walk"):
		_show(_torso, &"torso_walk", walk_frame(_stride, settings.stride_length, 6), row)
	else:
		_show(_torso, &"torso_idle", floori(_idle_time * settings.idle_fps) % 4, row)


func _draw_arm(aim: float) -> void:
	var row: int = arm_row(aim)
	# Frames 1..3 (fire, recoil, settle) play once after each shot; frame 0 is the rest pose.
	var col: int = 0
	if _since_shot < 3.0 / settings.gun_fps:
		col = 1 + floori(_since_shot * settings.gun_fps)
	_show(_arm, &"gunarm", col, row)
	if _sheets.has(&"gunarm_glow"):
		_show(_glow, &"gunarm_glow", col, row)
	# The gun arm is drawn in front of the torso or behind it, depending on the aim.
	# Moving it to the torso's index puts it just after the torso when it was before, and just
	# before it when it was after.
	if arm_in_front(row) != (_arm_group.get_index() > _torso.get_index()):
		move_child(_arm_group, _torso.get_index())
	var flash: StringName = &"muzzle_flash"
	if _player.weapon != null and _player.weapon.pellets > 1 and _sheets.has(&"muzzle_flash_shotgun"):
		flash = &"muzzle_flash_shotgun"
	if _sheets.has(flash) and _since_shot < 3.0 / settings.flash_fps and not _player.is_dead:
		_show(_flash, flash, floori(_since_shot * settings.flash_fps), row)
	else:
		_flash.visible = false


func _show(layer: Sprite2D, sheet: StringName, col: int, row: int) -> void:
	if not _sheets.has(sheet):
		layer.visible = false
		return
	var size: Vector2i = LAYOUT[sheet]
	if layer.texture != _sheets[sheet]:
		layer.texture = _sheets[sheet]
		layer.hframes = size.x
		layer.vframes = size.y
	layer.frame = row * size.x + clampi(col, 0, size.x - 1)
	layer.visible = true


func _on_died() -> void:
	_since_death = 0.0
	_death_row = sector4(_player.aim_direction.angle())


func _make_layer(layer_name: String, parent: Node) -> Sprite2D:
	var layer: Sprite2D = Sprite2D.new()
	layer.name = layer_name
	layer.centered = false
	layer.offset = -PIVOT
	layer.scale = Vector2(ART_SCALE, ART_SCALE)
	layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	layer.visible = false
	parent.add_child(layer)
	return layer


# --- Direction maths (pure, unit-tested) -------------------------------------------------

## 8-direction row for an angle (Godot angles, y down): 0 E, 1 SE, 2 S, ... 6 N, 7 NE.
## Row s covers [45 s - 22.5, 45 s + 22.5) deg; floor(x + 0.5), not round(), so boundaries fall
## the same way on both sides of 0 and agree with arm_row().
static func sector8(angle: float) -> int:
	return posmod(floori(angle / (PI / 4.0) + 0.5), 8)


## Death sheet row: 0 E, 1 S, 2 W, 3 N.
static func sector4(angle: float) -> int:
	return posmod(floori(angle / (PI / 2.0) + 0.5), 4)


## Gun-arm row: row k is drawn pointing at 11.25 + 22.5 k degrees and is used for aims in
## [22.5 k, 22.5 (k + 1)). Each 45 deg torso sector therefore holds exactly two arm rows.
static func arm_row(angle: float) -> int:
	return posmod(floori(angle / (TAU / ARM_ANGLES)), ARM_ANGLES)


## The gun is his RIGHT arm. His right shoulder sits at aim + 90 deg; the arm is in front of the
## torso when shoulder + barrel lean towards the camera (down the screen): cos a + sin a > 0,
## i.e. aims from -45 to 135 deg (rows 14, 15, 0..5). Aiming W through N it goes behind him.
static func arm_in_front(row: int) -> bool:
	var a: float = deg_to_rad(11.25 + 22.5 * row)
	return cos(a) + sin(a) > 0.0


## Legs row and stride direction (+1 forward, -1 backward). Walking more than 90 deg away from
## the aim, the legs face the aim side instead and the stride plays backwards (no crossed feet).
static func leg_row(move_angle: float, aim_angle: float) -> Vector2i:
	if absf(angle_difference(aim_angle, move_angle)) > PI / 2.0 + 0.01:
		return Vector2i(sector8(move_angle + PI), -1)
	return Vector2i(sector8(move_angle), 1)


## Walk frame for `distance` walked: one loop of `frames` per `stride` px.
static func walk_frame(distance: float, stride: float, frames: int) -> int:
	return posmod(floori(distance / stride * frames), frames)

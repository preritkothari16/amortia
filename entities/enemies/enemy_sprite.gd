class_name EnemySprite
extends Sprite2D
## Runner art on the enemy's Body (visual only). Turns smoothly to Enemy.facing, swings its arms
## by distance walked, flashes white when Enemy.take_damage tweens the Body colour, sprays blood,
## and shows the genome: Speed reddens the skin, Health greys it (bulk = Body.scale, as before),
## Vision brightens the bloom. Apex bosses get the purple boss tint.

const RULES: GenomeRules = preload("res://data/genome_rules.tres")
## World px walked per arm swing.
const STRIDE: float = 9.0
const TURN_RATE: float = 12.0

var _enemy: Enemy
var _body: Polygon2D
var _last_position: Vector2
var _walked: float = 0.0
## Smoothed facing angle; the walk sway is added on top of it.
var _heading: float = 0.0
var _styled: bool = false
var _boss_styled: bool = false
var _flashing: bool = false
## Apex boss only: a bigger magenta copy of the sprite behind it (reads as an outline) and a
## pulsing ground ring, so it stands out from the swarm and the dark floor.
var _halo: Sprite2D
var _aura: BossAura


func _ready() -> void:
	_body = get_parent() as Polygon2D
	_enemy = _body.get_parent() as Enemy if _body != null else null
	material = material.duplicate()  # per-enemy tint and flash
	if _enemy != null:
		_last_position = _enemy.global_position


func _process(delta: float) -> void:
	if _enemy == null or _enemy.stats == null:
		return
	if not _styled:
		_styled = true
		_apply_genome_look()
	if _enemy.is_boss and not _boss_styled:
		_boss_styled = true
		modulate = Color.WHITE.lerp(_enemy.stats.color, 0.3).lightened(0.2)
		_add_boss_halo()
	if _enemy.facing != Vector2.ZERO:
		_heading = lerp_angle(_heading, _enemy.facing.angle(), 1.0 - exp(-TURN_RATE * delta))
	var moved: float = _enemy.global_position.distance_to(_last_position)
	_last_position = _enemy.global_position
	var sway: float = 0.0
	if _enemy.velocity.length() > 8.0:
		_walked += moved
		frame = 1 + posmod(floori(_walked / STRIDE), 2)
		sway = sin(_walked / STRIDE * PI) * 0.12  # shoulders roll with the arm swing
	else:
		frame = 0
	rotation = _heading + sway
	if _halo != null:
		_halo.rotation = rotation
		_halo.frame = frame
	_update_flash()


func _add_boss_halo() -> void:
	_aura = BossAura.new()
	_aura.name = "BossAura"
	_body.add_child(_aura)
	_body.move_child(_aura, get_index())
	_halo = Sprite2D.new()
	_halo.name = "BossHalo"
	_halo.texture = texture
	_halo.hframes = hframes
	_halo.texture_filter = texture_filter
	_halo.scale = scale * 1.28
	_halo.modulate = Color(1.0, 0.25, 0.85, 0.75)
	_body.add_child(_halo)
	_body.move_child(_halo, get_index())


## Enemy.take_damage sets Body.color to white and tweens it back to stats.color in 0.12 s.
func _update_flash() -> void:
	var base: Color = _enemy.stats.color
	var span: float = Vector3(1.0 - base.r, 1.0 - base.g, 1.0 - base.b).length()
	var now: Color = _body.color
	var amount: float = 0.0  # 1 = fully white (just hit), 0 = back to the base colour
	if span > 0.01:
		amount = clampf(Vector3(now.r - base.r, now.g - base.g, now.b - base.b).length() / span, 0.0, 1.0)
	(material as ShaderMaterial).set_shader_parameter("flash", amount * 0.85)
	if amount > 0.8 and not _flashing:
		var fx: Node = get_tree().get_first_node_in_group(&"combat_fx")
		if fx != null:
			fx.blood_spray(_enemy.global_position)
	_flashing = amount > 0.8


func _apply_genome_look() -> void:
	var m: ShaderMaterial = material as ShaderMaterial
	var g: Genome = _enemy.genome
	if g == null:
		return
	var speed: float = inverse_lerp(RULES.stat_min, RULES.stat_max, g.speed)
	var health: float = inverse_lerp(RULES.stat_min, RULES.stat_max, g.health)
	var vision: float = inverse_lerp(RULES.stat_min, RULES.stat_max, g.vision)
	var tint: Color = Color(1, 1, 1).lerp(Color(1.35, 0.85, 0.78), clampf(speed, 0.0, 1.0))
	tint = tint.lerp(Color(0.8, 0.82, 0.86), clampf(health, 0.0, 1.0) * 0.6)
	m.set_shader_parameter("skin_tint", tint)
	m.set_shader_parameter("bloom_boost", lerpf(0.85, 1.6, clampf(vision, 0.0, 1.0)))

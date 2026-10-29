class_name AmbientLights
extends Node2D
## Broken lamps and emergency lights (visual only): a few dithered pools of light on walkable
## cells just south of buildings and walls, flickering (the Labs' emergency lights blink red),
## and smouldering fires inside burned ruins.
## Additive and faint, drawn under the units, so it never hides an enemy or an objective.
## Placement is seeded per area; the flicker uses its own clock, never the gameplay RNG.

const FIRE_RADIUS: int = 22
const FIRE_COLOR: Color = Color(1.0, 0.5, 0.18)

var _lamps: Array = []  # [Vector2 position, float phase, float speed]
var _fires: Array = []  # [Vector2 position, float phase]
var _fire_pool: ImageTexture
var _smoke: Node2D
var _pool: ImageTexture
var _color: Color = Color.WHITE
var _strength: float = 0.2
var _radius: int = 36
var _blink: bool = false
var _time: float = 0.0


func setup(grid: TerrainGrid, settings: VisualFxSettings, zone: int, seed_value: int) -> void:
	var additive: CanvasItemMaterial = CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = additive
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_radius = settings.lamp_radius
	_strength = settings.lamp_strength
	_blink = zone == 3
	if zone < settings.zone_lamp_color.size():
		_color = settings.zone_lamp_color[zone]
	_pool = _make_pool(_radius)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var spots: Array[Vector2] = []
	for y: int in grid.height:
		for x: int in grid.width:
			var cell: Vector2i = Vector2i(x, y)
			var d: TerrainDefinition = grid.get_definition(cell)
			var above: String = grid.get_terrain(cell + Vector2i.UP)
			if d != null and d.player_passable and (above == "house" or above == "wall"):
				spots.append(grid.coords.cell_rect(cell).position + Vector2(8, 1))
	# Seeded shuffle, then keep spots far enough apart.
	for i: int in range(spots.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: Vector2 = spots[i]
		spots[i] = spots[j]
		spots[j] = tmp
	for spot: Vector2 in spots:
		if _lamps.size() >= settings.lamp_count:
			break
		if _lamps.any(func(l: Array) -> bool: return (l[0] as Vector2).distance_to(spot) < settings.lamp_spacing):
			continue
		_lamps.append([spot, rng.randf() * 10.0, rng.randf_range(0.7, 1.4)])


func lamp_count() -> int:
	return _lamps.size()


## Smouldering fires in burned ruins: a small, fast-flickering orange pool with embers rising,
## and a thin smoke trail drawn with normal blending (smoke darkens, light adds).
func add_fires(spots: Array[Vector2]) -> void:
	_fires.clear()
	for spot: Vector2 in spots:
		_fires.append([spot, fmod(spot.x * 0.37 + spot.y * 0.11, 10.0)])
	if _fire_pool == null:
		_fire_pool = _make_pool(FIRE_RADIUS)
	if _smoke == null:
		_smoke = Node2D.new()
		_smoke.name = "Smoke"
		_smoke.use_parent_material = false
		_smoke.material = CanvasItemMaterial.new()
		add_child(_smoke)
		_smoke.draw.connect(_draw_smoke)


func fire_count() -> int:
	return _fires.size()


func _process(delta: float) -> void:
	if _lamps.is_empty() and _fires.is_empty():
		return
	_time += delta
	queue_redraw()
	if _smoke != null:
		_smoke.queue_redraw()


func _draw_smoke() -> void:
	for fire: Array in _fires:
		var at: Vector2 = fire[0]
		for i: int in 4:
			var t: float = fmod(_time * 0.35 + i * 0.25 + fire[1], 1.0)
			var p: Vector2 = at + Vector2(sin(t * 5.0 + fire[1]) * 2.0 + t * 6.0, -t * 26.0)
			var s: float = 2.0 + t * 4.0
			_smoke.draw_rect(Rect2((p - Vector2(s, s) / 2.0).floor(), Vector2(s, s).floor()), Color(0.1, 0.09, 0.09, 0.32 * (1.0 - t)))


func _draw() -> void:
	var r: Vector2 = Vector2(_radius, _radius)
	for lamp: Array in _lamps:
		var at: Vector2 = lamp[0]
		var level: float = _level(lamp[1], lamp[2])
		draw_texture_rect(_pool, Rect2(at - r, r * 2.0), false, Color(_color, _strength * level))
		draw_rect(Rect2(at - Vector2(1, 1), Vector2(3, 1)), Color(_color, 0.35 + 0.5 * level))  # the fixture
	var f: Vector2 = Vector2(FIRE_RADIUS, FIRE_RADIUS)
	for fire: Array in _fires:
		var at: Vector2 = fire[0]
		var flicker: float = 0.7 + 0.2 * sin(_time * 11.0 + fire[1]) + 0.1 * sin(_time * 23.0 + fire[1] * 3.0)
		draw_texture_rect(_fire_pool, Rect2(at - f, f * 2.0), false, Color(FIRE_COLOR, 0.42 * flicker))
		for i: int in 3:  # embers drifting up out of the ruin
			var t: float = fmod(_time * 0.8 + i * 0.33 + fire[1], 1.0)
			var p: Vector2 = at + Vector2(sin(t * 7.0 + i) * 3.0, -t * 18.0)
			draw_rect(Rect2(p.floor(), Vector2.ONE), Color(1.0, 0.55, 0.2, 0.9 * (1.0 - t)))


## Brightness 0..1 at this moment: a slow hum with sudden drop-outs, or a slow emergency blink.
func _level(phase: float, speed: float) -> float:
	var t: float = _time * speed + phase
	if _blink:
		return 0.2 + 0.8 * float(fmod(t * 0.6, 1.0) < 0.55)
	var hum: float = 0.85 + 0.15 * sin(t * 3.0)
	var tick: float = floorf(t * 9.0)
	var roll: float = fmod(absf(sin(tick * 12.9898 + phase) * 43758.5453), 1.0)
	return hum * (0.2 if roll > 0.94 else 1.0)


## White disc fading out in 4 dithered steps (pixel art, no smooth gradient).
func _make_pool(radius: int) -> ImageTexture:
	var bayer: Array[int] = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]
	var img: Image = Image.create(radius * 2, radius * 2, false, Image.FORMAT_RGBA8)
	for y: int in radius * 2:
		for x: int in radius * 2:
			var d: float = Vector2(x + 0.5 - radius, (y + 0.5 - radius) * 1.25).length() / radius
			var v: float = clampf(1.0 - d, 0.0, 1.0)
			v = v * v
			var lit: float = floorf(v * 4.0 + bayer[(y % 4) * 4 + x % 4] / 16.0) / 4.0
			img.set_pixel(x, y, Color(1, 1, 1, clampf(lit, 0.0, 1.0)))
	return ImageTexture.create_from_image(img)

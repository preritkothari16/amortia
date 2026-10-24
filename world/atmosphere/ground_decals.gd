class_name GroundDecals
extends Node2D
## Flat ground detail drawn in one pass (cracks, debris, leaves, bones, stains) plus blood splats
## added during play. Purely visual; uses the ground material so it is lit and graded like the
## tiles. Lives under the map, so it goes away with the area.

## Each entry: [Rect2 (world px), Color].
var _rects: Array = []
var _splats: Array = []
var _max_splats: int = 80


## Scatters detail over the walkable cells of `grid`. Seeded from the map, so an area always looks
## the same; uses its own RNG (never the global one, which gameplay may use).
func scatter(grid: TerrainGrid, density: float, seed_value: int, max_splats: int) -> void:
	_max_splats = max_splats
	_rects.clear()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	for y: int in grid.height:
		for x: int in grid.width:
			var cell: Vector2i = Vector2i(x, y)
			var id: String = grid.get_terrain(cell)
			if rng.randf() > density:
				continue
			var r: Rect2 = grid.coords.cell_rect(cell)
			var o: Vector2 = r.position.floor()
			match id:
				"road", "bridge":
					_road_detail(rng, o)
				"grass":
					_grass_detail(rng, o)
				"tall_grass":
					_tufts(rng, o, Color(0.42, 0.55, 0.3), 3)
				"mud", "shallow_water":
					_blob(rng, o, Color(0.16, 0.11, 0.08, 0.55), 3)
				"ash":
					_specks(rng, o, Color(0.85, 0.35, 0.12), 3)
					_specks(rng, o, Color(0.12, 0.11, 0.11), 6)
	queue_redraw()


func add_splat(at: Vector2, rng: RandomNumberGenerator) -> void:
	var drops: Array = []
	var dark: Color = Color(0.32, 0.03, 0.04, 0.9)
	var wet: Color = Color(0.5, 0.06, 0.06, 0.9)
	var c: Vector2 = to_local(at).floor()
	for i: int in rng.randi_range(7, 12):
		var off: Vector2 = Vector2(rng.randf_range(-5, 5), rng.randf_range(-4, 4)).floor()
		var size: Vector2 = Vector2(rng.randi_range(1, 3), rng.randi_range(1, 2))
		drops.append([Rect2(c + off, size), dark if rng.randf() < 0.6 else wet])
	for i: int in rng.randi_range(2, 5):  # flung drops further out
		var dir: Vector2 = Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(6, 10)
		drops.append([Rect2((c + dir).floor(), Vector2.ONE), dark])
	_splats.append(drops)
	if _splats.size() > _max_splats:
		_splats.pop_front()
	queue_redraw()


func _draw() -> void:
	for entry: Array in _rects:
		draw_rect(entry[0], entry[1])
	for splat: Array in _splats:
		for entry: Array in splat:
			draw_rect(entry[0], entry[1])


func _road_detail(rng: RandomNumberGenerator, o: Vector2) -> void:
	var roll: float = rng.randf()
	if roll < 0.45:  # crack: a short jagged 1 px line
		var p: Vector2 = o + Vector2(rng.randi_range(2, 12), rng.randi_range(2, 12))
		for i: int in rng.randi_range(4, 8):
			_rects.append([Rect2(p, Vector2.ONE), Color(0.1, 0.1, 0.1, 0.8)])
			p += Vector2(rng.randi_range(0, 1), rng.randi_range(-1, 1))
	elif roll < 0.75:
		_specks(rng, o, Color(0.3, 0.28, 0.26), 4)  # gravel and debris
		_specks(rng, o, Color(0.55, 0.5, 0.42), 2)
	elif roll < 0.92:
		_blob(rng, o, Color(0.08, 0.08, 0.09, 0.6), 4)  # oil stain
	else:
		_blob(rng, o, Color(0.3, 0.03, 0.04, 0.75), 3)  # old blood


func _grass_detail(rng: RandomNumberGenerator, o: Vector2) -> void:
	var roll: float = rng.randf()
	if roll < 0.55:
		_tufts(rng, o, Color(0.2, 0.3, 0.16), 3)
	elif roll < 0.85:
		_specks(rng, o, Color(0.55, 0.32, 0.14), 3)  # dead leaves
		_specks(rng, o, Color(0.4, 0.22, 0.1), 2)
	elif roll < 0.95:
		var p: Vector2 = o + Vector2(rng.randi_range(3, 11), rng.randi_range(3, 12))  # bone
		_rects.append([Rect2(p, Vector2(3, 1)), Color(0.78, 0.74, 0.66)])
		_rects.append([Rect2(p + Vector2(-1, -1), Vector2.ONE), Color(0.78, 0.74, 0.66)])
		_rects.append([Rect2(p + Vector2(3, 1), Vector2.ONE), Color(0.78, 0.74, 0.66)])
	else:
		_blob(rng, o, Color(0.3, 0.03, 0.04, 0.7), 3)


func _tufts(rng: RandomNumberGenerator, o: Vector2, colour: Color, count: int) -> void:
	for i: int in count:
		var p: Vector2 = o + Vector2(rng.randi_range(1, 14), rng.randi_range(2, 14))
		_rects.append([Rect2(p, Vector2(1, 2)), colour])
		_rects.append([Rect2(p + Vector2(1, 1), Vector2(1, 1)), colour])


func _specks(rng: RandomNumberGenerator, o: Vector2, colour: Color, count: int) -> void:
	for i: int in count:
		_rects.append([Rect2(o + Vector2(rng.randi_range(0, 15), rng.randi_range(0, 15)), Vector2.ONE), colour])


func _blob(rng: RandomNumberGenerator, o: Vector2, colour: Color, size: int) -> void:
	var c: Vector2 = o + Vector2(rng.randi_range(3, 12), rng.randi_range(3, 12))
	_rects.append([Rect2(c - Vector2(size, 1), Vector2(size * 2, 2)), colour])
	_rects.append([Rect2(c - Vector2(size - 1, 2), Vector2(size * 2 - 2, 4)), colour])

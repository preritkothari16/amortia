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
func scatter(grid: TerrainGrid, density: float, seed_value: int, max_splats: int, zone: int = 0) -> void:
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
			if _zone_detail(zone, id, rng, o):
				continue
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
	_blood_trails(grid, rng)
	queue_redraw()


## A few dried drag trails: drops in a line that thin out, stopping before anything solid.
func _blood_trails(grid: TerrainGrid, rng: RandomNumberGenerator) -> void:
	var count: int = rng.randi_range(2, 4) + int(grid.width * grid.height / 600.0)
	for t: int in count:
		var start: Vector2i = Vector2i(rng.randi_range(1, grid.width - 2), rng.randi_range(1, grid.height - 2))
		var id: String = grid.get_terrain(start)
		if id != "road" and id != "grass":
			continue
		var p: Vector2 = grid.coords.cell_rect(start).position + Vector2(8, 8)
		var dir: Vector2 = Vector2.from_angle(rng.randf() * TAU)
		var steps: int = rng.randi_range(10, 22)
		for i: int in steps:
			var d: TerrainDefinition = grid.get_definition(grid.coords.world_to_cell(p))
			if d == null or not d.player_passable:
				break
			var thick: float = 2.0 if i < steps / 2.0 else 1.0
			_rects.append([Rect2(p.floor(), Vector2(thick, thick)), Color(0.3, 0.04, 0.05, 0.7 - 0.4 * i / steps)])
			dir = dir.rotated(rng.randf_range(-0.25, 0.25))
			p += dir * rng.randf_range(2.0, 3.5)
		_blob(rng, grid.coords.cell_rect(start).position.floor(), Color(0.28, 0.03, 0.04, 0.75), 3)


## Broken tile left behind: splinters / chunks scattered in its cell, flat and dim so it reads
## as walkable floor and never hides what stands on it.
func add_rubble(rect: Rect2, terrain: String, rng: RandomNumberGenerator) -> void:
	var o: Vector2 = to_local(rect.position).floor()
	# Light colours: the ground material darkens everything away from the player's light.
	var light: Color = Color(0.82, 0.66, 0.46)
	var dark: Color = Color(0.36, 0.25, 0.15)
	if terrain == "door":
		light = Color(0.6, 0.44, 0.3)
	var drops: Array = []
	for i: int in 3:  # dust settling in the cell
		drops.append([Rect2(o + Vector2(rng.randi_range(1, 10), rng.randi_range(1, 11)), Vector2(5, 3)), Color(0.55, 0.52, 0.48, 0.3)])
	for i: int in rng.randi_range(4, 6):  # broken planks lying flat
		var size: Vector2 = Vector2(rng.randi_range(3, 6), 1) if rng.randf() < 0.6 else Vector2(1, rng.randi_range(3, 5))
		var p: Vector2 = o + Vector2(rng.randi_range(0, 10), rng.randi_range(1, 15 - int(size.y)))  # shadow included, inside the cell
		drops.append([Rect2(p + Vector2(0, 1), size), Color(0, 0, 0, 0.35)])  # its shadow
		drops.append([Rect2(p, size), light if rng.randf() < 0.6 else dark])
	for i: int in rng.randi_range(6, 9):  # splinters and nails
		drops.append([Rect2(o + Vector2(rng.randi_range(0, 15), rng.randi_range(0, 15)), Vector2.ONE), light if rng.randf() < 0.5 else Color(0.5, 0.5, 0.52)])
	_splats.append(drops)
	if _splats.size() > _max_splats:
		_splats.pop_front()
	queue_redraw()


## Extra, zone-specific clutter on road / grass cells (about half of the chosen cells get one).
## True when it drew something, so the generic detail is skipped for that cell.
func _zone_detail(zone: int, id: String, rng: RandomNumberGenerator, o: Vector2) -> bool:
	if id != "road" and id != "grass" and id != "tall_grass":
		return false
	if rng.randf() < 0.5:
		return false
	var p: Vector2 = o + Vector2(rng.randi_range(2, 10), rng.randi_range(2, 12))
	match zone:
		0:  # Maple Hollow: litter, old tyres, bin bags, a lost shoe
			var roll: float = rng.randf()
			if roll < 0.15:
				var tyre: Color = Color(0.12, 0.12, 0.13, 0.85)  # a ring, ground showing through
				_rects.append([Rect2(p + Vector2(1, 0), Vector2(2, 1)), tyre])
				_rects.append([Rect2(p + Vector2(1, 3), Vector2(2, 1)), tyre])
				_rects.append([Rect2(p + Vector2(0, 1), Vector2(1, 2)), tyre])
				_rects.append([Rect2(p + Vector2(3, 1), Vector2(1, 2)), tyre])
			elif roll < 0.3:
				_rects.append([Rect2(p, Vector2(3, 2)), Color(0.1, 0.13, 0.11)])  # bin bag
				_rects.append([Rect2(p + Vector2(1, 0), Vector2.ONE), Color(0.25, 0.3, 0.27)])
			elif roll < 0.38:
				_rects.append([Rect2(p, Vector2(2, 1)), Color(0.55, 0.2, 0.18)])  # shoe
			else:
				_specks(rng, o, Color(0.75, 0.72, 0.66), 2)  # paper, cans
		1:  # Lowtide: puddles, driftwood, shells, seaweed
			var roll: float = rng.randf()
			if roll < 0.45:
				_blob(rng, o, Color(0.3, 0.62, 0.7, 0.6), 4)
				_rects.append([Rect2(o + Vector2(5, 6), Vector2(3, 1)), Color(0.75, 0.92, 0.95, 0.55)])
			elif roll < 0.65:
				_rects.append([Rect2(p, Vector2(6, 1)), Color(0.5, 0.38, 0.26)])
				_rects.append([Rect2(p + Vector2(1, 1), Vector2(4, 1)), Color(0.32, 0.24, 0.17)])
			elif roll < 0.85:
				_specks(rng, o, Color(0.92, 0.88, 0.8), 3)
			else:
				_tufts(rng, o, Color(0.12, 0.38, 0.28), 3)
		2:  # Greywood: moss, ferns, mushrooms, roots
			var roll: float = rng.randf()
			if roll < 0.4:
				_blob(rng, o, Color(0.2, 0.5, 0.16, 0.75), 4)
			elif roll < 0.7:
				_tufts(rng, o, Color(0.22, 0.58, 0.2), 4)
			elif roll < 0.85:
				_rects.append([Rect2(p, Vector2(2, 1)), Color(0.85, 0.25, 0.2)])  # mushroom
				_rects.append([Rect2(p + Vector2(0, 1), Vector2(1, 1)), Color(0.9, 0.85, 0.75)])
			else:
				_rects.append([Rect2(p, Vector2(7, 1)), Color(0.3, 0.2, 0.12)])  # root
				_rects.append([Rect2(p + Vector2(2, 1), Vector2(1, 2)), Color(0.3, 0.2, 0.12)])
		3:  # Sunnyseed Labs: hazard stripes, infection stains, cables, status lights
			var roll: float = rng.randf()
			if roll < 0.3 and id == "road":
				for i: int in 4:
					_rects.append([Rect2(o + Vector2(2 + i * 3, 6), Vector2(2, 3)), Color(0.9, 0.72, 0.1) if i % 2 == 0 else Color(0.1, 0.1, 0.1)])
			elif roll < 0.55:
				_blob(rng, o, Color(0.62, 0.05, 0.1, 0.7), 3)  # infection
			elif roll < 0.65:
				_rects.append([Rect2(p, Vector2(2, 2)), Color(0.82, 0.8, 0.74)])  # dropped papers
				_rects.append([Rect2(p + Vector2(3, 1), Vector2(2, 1)), Color(0.82, 0.8, 0.74)])
				_rects.append([Rect2(p + Vector2(1, 3), Vector2.ONE), Color(0.55, 0.85, 0.9)])  # broken vial
			elif roll < 0.8:
				_rects.append([Rect2(p, Vector2(8, 1)), Color(0.08, 0.09, 0.11)])  # cable
			else:
				_rects.append([Rect2(p, Vector2.ONE), Color(1.0, 0.2, 0.2)])  # warning light
	return true


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

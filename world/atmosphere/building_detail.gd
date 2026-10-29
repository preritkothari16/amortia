class_name BuildingDetail
extends Node2D
## World detail drawn over the map (visual only): every building baked as standing, weathered
## architecture of its district (FacadeBuilder / BuildingArchetypes: houses, shops, apartments,
## hospitals, warehouses, cabins, labs...), cracked walls with exposed brick, curbs and faded road
## markings, a little debris by the walls, and the shadows solid cells cast to the south-east.
## Everything solid stays inside solid cells and everything on walkable cells is flat and small,
## so nothing reads as a route that isn't one (or a wall that isn't one).
## Rebuilt from the TerrainGrid when the terrain changes (fire, living walls, broken fences,
## opened gates). Lives under the map with the ground material, so it is lit like the tiles.

const CHARCOAL: Color = Color("#111419")
const BLOOD: Color = Color("#6d252a")
const BONE: Color = Color("#d6cdbd")
const WOOD: Color = Color(0.36, 0.25, 0.16)

## Solid terrains that cast a shadow, and how far (world px) it falls (buildings bake their own,
## longer the taller they are).
const SHADOW_LENGTH: Dictionary[String, int] = {
	"wall": 3, "tree": 4, "fence": 2, "door": 3, "barricade": 2,
	"living_wall": 3, "vent": 1, "gate": 2}
## Buildings are baked only when something is rendered (a headless test or experiment run has no
## screen; baking every building there only costs time). Tests that check them turn it on.
static var bake_buildings: bool = DisplayServer.get_name() != "headless"

## The district dressing this map: which building types stand here and how far gone they are
## (data/architecture.tres). Null in setup() = the zone's first district.
var district: DistrictStyle

var _grid: TerrainGrid
var _zone: int = 0
var _seed: int = 0
## Each entry: [Rect2 (world px), Color].
var _rects: Array = []
var _dirty: bool = false
## Baked buildings: top-left cell -> [ImageTexture, Vector2 world position, Array[Vector2] fires,
## StringName type, Vector2i size in cells]; drawn north to south (`_order`).
var _baked: Dictionary[Vector2i, Array] = {}
var _order: Array[Vector2i] = []
var _types: Dictionary[Vector2i, StringName] = {}


## `zone` is the palette index (0-3).
func setup(grid: TerrainGrid, zone: int, seed_value: int, district_style: DistrictStyle = null) -> void:
	_grid = grid
	_zone = clampi(zone, 0, 3)
	_seed = seed_value
	district = district_style
	if district == null:
		var architecture: ArchitectureSettings = load(ArchitectureSettings.PATH) as ArchitectureSettings
		if architecture != null:
			district = architecture.district_for("", _zone + 1)
	grid.terrain_changed.connect(_on_terrain_changed)
	rebuild()


func _on_terrain_changed(_cells: Array[Vector2i], _affects_cost: bool) -> void:
	_dirty = true


func _process(_delta: float) -> void:
	if _dirty:
		_dirty = false
		rebuild()


## Number of rects drawn (tests / profiling).
func rect_count() -> int:
	return _rects.size()


## Recomputes every detail from the grid. Seeded, so the same map always looks the same.
func rebuild() -> void:
	_rects.clear()
	if _grid == null:
		return
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = _seed
	_shadows()
	_roads(rng)
	_buildings()
	if _zone == 0:
		_utility_poles(rng)
	for y: int in _grid.height:
		for x: int in _grid.width:
			var cell: Vector2i = Vector2i(x, y)
			match _grid.get_terrain(cell):
				"wall":
					_wall(cell, rng)
				"tree":
					_tree(cell, rng)
				_:
					if _walkable(cell):
						_rubble(cell, rng)
	queue_redraw()


func _draw() -> void:
	for entry: Array in _rects:
		draw_rect(entry[0], entry[1])
	for lo: Vector2i in _order:
		draw_texture(_baked[lo][0], _baked[lo][1])


# --- helpers ---------------------------------------------------------------------------------

func _add(rect: Rect2, colour: Color) -> void:
	_rects.append([rect, colour])


func _origin(cell: Vector2i) -> Vector2:
	return _grid.coords.cell_rect(cell).position.floor()


func _is(cell: Vector2i, id: String) -> bool:
	return _grid.get_terrain(cell) == id


func _walkable(cell: Vector2i) -> bool:
	var d: TerrainDefinition = _grid.get_definition(cell)
	return d != null and d.player_passable


## 4-connected groups of `id` cells, row-major order (deterministic).
func _components(id: String) -> Array:
	var seen: Dictionary[Vector2i, bool] = {}
	var out: Array = []
	for y: int in _grid.height:
		for x: int in _grid.width:
			var start: Vector2i = Vector2i(x, y)
			if seen.has(start) or not _is(start, id):
				continue
			var group: Array[Vector2i] = []
			var stack: Array[Vector2i] = [start]
			seen[start] = true
			while not stack.is_empty():
				var c: Vector2i = stack.pop_back()
				group.append(c)
				for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
					var n: Vector2i = c + d
					if not seen.has(n) and _is(n, id):
						seen[n] = true
						stack.append(n)
			out.append(group)
	return out


# --- shadows ---------------------------------------------------------------------------------

## Solid cells darken the top / left strip of the walkable cell south / east of them.
func _shadows() -> void:
	for y: int in _grid.height:
		for x: int in _grid.width:
			var cell: Vector2i = Vector2i(x, y)
			var length: int = SHADOW_LENGTH.get(_grid.get_terrain(cell), 0)
			if length == 0:
				continue
			var south: Vector2i = cell + Vector2i.DOWN
			var east: Vector2i = cell + Vector2i.RIGHT
			if _walkable(south):
				var o: Vector2 = _origin(south)
				_add(Rect2(o, Vector2(16, length)), Color(0, 0, 0, 0.3))
				_add(Rect2(o + Vector2(0, length), Vector2(16, 1)), Color(0, 0, 0, 0.14))
			if _walkable(east):
				var o: Vector2 = _origin(east)
				_add(Rect2(o + Vector2(0, 2), Vector2(maxi(length - 2, 1), 14)), Color(0, 0, 0, 0.22))


# --- buildings -------------------------------------------------------------------------------

## Every building (each rectangle of house cells) is baked once by FacadeBuilder as the type its
## district gives it and drawn as one texture over its footprint (cached by its top-left cell).
func _buildings() -> void:
	if not bake_buildings:
		return
	var rects: Array[Rect2i] = []
	for group: Array[Vector2i] in _components("house"):
		rects.append_array(_rects_of(group))
	if _types.is_empty() and not rects.is_empty():
		_assign_types(rects)
	var keep: Dictionary[Vector2i, Array] = {}
	for r: Rect2i in rects:
		var lo: Vector2i = r.position
		if _baked.has(lo) and _baked[lo][4] == r.size:
			keep[lo] = _baked[lo]
			continue
		var type: StringName = _types.get(lo, BuildingArchetypes.fallback(r.size))
		var seed_value: int = hash(lo) ^ _seed
		var builder: FacadeBuilder = FacadeBuilder.new()
		var img: Image = builder.bake(r.size, type, _zone, _look(seed_value), seed_value, _blocked_around(r))
		var at: Vector2 = _origin(lo) - Vector2(FacadeBuilder.MARGIN, FacadeBuilder.MARGIN)
		var world_fires: Array[Vector2] = []
		for f: Vector2 in builder.fires:
			world_fires.append(at + f)
		keep[lo] = [ImageTexture.create_from_image(img), at, world_fires, type, r.size]
	_baked = keep
	_order = _baked.keys()
	_order.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))


## Splits a group of house cells into rectangles (one building each), top-left first.
func _rects_of(group: Array[Vector2i]) -> Array[Rect2i]:
	var left: Dictionary[Vector2i, bool] = {}
	for c: Vector2i in group:
		left[c] = true
	var out: Array[Rect2i] = []
	while not left.is_empty():
		var lo: Vector2i = left.keys()[0]
		for c: Vector2i in left:
			if c.y < lo.y or (c.y == lo.y and c.x < lo.x):
				lo = c
		var w: int = 1
		while left.has(lo + Vector2i(w, 0)):
			w += 1
		var h: int = 1
		var full: bool = true
		while full:
			for x: int in w:
				if not left.has(lo + Vector2i(x, h)):
					full = false
					break
			if full:
				h += 1
		for y: int in h:
			for x: int in w:
				left.erase(lo + Vector2i(x, y))
		out.append(Rect2i(lo, Vector2i(w, h)))
	return out


## Building types for the area: the district's landmark on its biggest building that fits it,
## the rest dealt in reading order from a seeded, shuffled deck of the district's types (a type
## the footprint can't hold is skipped; the same type twice in a row is avoided).
func _assign_types(rects: Array[Rect2i]) -> void:
	var pool: Array[StringName] = [&"house"]
	if district != null and not district.archetypes.is_empty():
		pool = district.archetypes
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = _seed + 3
	if district != null and district.landmark != &"":
		var best: int = -1
		for i: int in rects.size():
			if BuildingArchetypes.fits(district.landmark, rects[i].size) \
					and (best < 0 or rects[i].get_area() > rects[best].get_area()):
				best = i
		if best >= 0:
			_types[rects[best].position] = district.landmark
	var order: Array[Rect2i] = rects.duplicate()
	order.sort_custom(func(a: Rect2i, b: Rect2i) -> bool:
		return a.position.y < b.position.y or (a.position.y == b.position.y and a.position.x < b.position.x))
	var deck: Array[StringName] = []
	var prev: StringName = &""
	for r: Rect2i in order:
		if _types.has(r.position):
			prev = _types[r.position]
			continue
		var pick: int = _deal(deck, r.size, prev)
		if pick < 0:  # nothing left in the deck fits this footprint: a fresh shuffle
			deck = pool.duplicate()
			for i: int in range(deck.size() - 1, 0, -1):
				var j: int = rng.randi_range(0, i)
				var tmp: StringName = deck[i]
				deck[i] = deck[j]
				deck[j] = tmp
			pick = _deal(deck, r.size, prev)
		var type: StringName = BuildingArchetypes.fallback(r.size)
		if pick >= 0:
			type = deck[pick]
			deck.remove_at(pick)
		_types[r.position] = type
		prev = type


## Index of the first type in `deck` that fits `size`, preferring one that isn't `prev` (-1: none).
func _deal(deck: Array[StringName], size: Vector2i, prev: StringName) -> int:
	for pass_index: int in 2:
		for i: int in deck.size():
			if BuildingArchetypes.fits(deck[i], size) and (pass_index == 1 or deck[i] != prev):
				return i
	return -1


## This building's share of the district's look (seeded per building, so the damage varies).
func _look(seed_value: int) -> Dictionary:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value + 5
	var d: DistrictStyle = district if district != null else DistrictStyle.new()
	return {
		"decay": clampf(d.decay + rng.randf_range(-0.15, 0.15), 0.0, 1.0),
		"infection": clampf(d.infection * rng.randf_range(0.6, 1.3), 0.0, 1.0),
		"overgrowth": clampf(d.overgrowth * rng.randf_range(0.5, 1.4), 0.0, 1.0),
		"flood": d.flood,
		"burned": rng.randf() < d.burn_share,
		"collapse": rng.randf() < d.collapse_share,
	}


## Cells round `r` (relative to its top-left) that are not walkable: nothing is drawn over them.
func _blocked_around(r: Rect2i) -> Dictionary:
	var out: Dictionary = {}
	for y: int in range(-1, r.size.y + 1):
		for x: int in range(-1, r.size.x + 1):
			if x >= 0 and y >= 0 and x < r.size.x and y < r.size.y:
				continue
			if not _walkable(r.position + Vector2i(x, y)):
				out[Vector2i(x, y)] = true
	return out


## World positions of smouldering fires in burned buildings (for flickering fire light).
func fire_spots() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for entry: Array in _baked.values():
		out.append_array(entry[2])
	return out


## Type of every building, by its top-left cell (tests, captures).
func types() -> Dictionary[Vector2i, StringName]:
	var out: Dictionary[Vector2i, StringName] = {}
	for lo: Vector2i in _baked:
		out[lo] = _baked[lo][3]
	return out


# --- walls, trees ----------------------------------------------------------------------------

func _wall(cell: Vector2i, rng: RandomNumberGenerator) -> void:
	var o: Vector2 = _origin(cell)
	if not _is(cell + Vector2i.UP, "wall"):
		_add(Rect2(o, Vector2(16, 1)), Color(BONE, 0.12))
	if not _is(cell + Vector2i.DOWN, "wall"):
		_add(Rect2(o + Vector2(0, 14), Vector2(16, 2)), Color(CHARCOAL, 0.5))
	var roll: float = rng.randf()
	if roll < 0.3:  # a crack running down the wall
		var p: Vector2 = o + Vector2(rng.randi_range(3, 12), 1)
		for i: int in rng.randi_range(5, 10):
			_add(Rect2(p, Vector2.ONE), Color(CHARCOAL, 0.8))
			p += Vector2(rng.randi_range(-1, 1), 1)
	elif roll < 0.45:  # render fallen away, bricks showing
		var p: Vector2 = o + Vector2(rng.randi_range(2, 8), rng.randi_range(2, 8))
		var brick: Color = [Color(0.56, 0.3, 0.22), Color(0.36, 0.4, 0.38), Color(0.34, 0.27, 0.18), Color(0.5, 0.47, 0.45)][_zone]
		for by: int in 3:
			_add(Rect2(p + Vector2((by % 2) * 2, by * 2), Vector2(4, 1)), Color(brick, 0.6))
			_add(Rect2(p + Vector2((by % 2) * 2, by * 2 + 1), Vector2(4, 1)), Color(0, 0, 0, 0.25))
	elif roll < 0.55:  # bullet pocks
		for i: int in 3:
			_add(Rect2(o + Vector2(rng.randi_range(2, 13), rng.randi_range(2, 12)), Vector2.ONE), CHARCOAL)
	elif roll < 0.58:  # old blood smeared sideways along the wall
		var p: Vector2 = o + Vector2(rng.randi_range(1, 8), rng.randi_range(3, 9))
		_add(Rect2(p, Vector2(rng.randi_range(5, 7), 2)), Color(BLOOD, 0.6))
		_add(Rect2(p + Vector2(1, 2), Vector2(1, 2)), Color(BLOOD, 0.5))
		_add(Rect2(p + Vector2(4, 2), Vector2(1, 3)), Color(BLOOD, 0.5))


func _tree(cell: Vector2i, rng: RandomNumberGenerator) -> void:
	var o: Vector2 = _origin(cell)
	# Canopy edge: dark where the crown ends, a highlight on its north-west side.
	if not _is(cell + Vector2i.DOWN, "tree"):
		_add(Rect2(o + Vector2(1, 14), Vector2(14, 2)), Color(0, 0, 0, 0.35))
	if not _is(cell + Vector2i.UP, "tree"):
		_add(Rect2(o + Vector2(3, 1), Vector2(rng.randi_range(4, 8), 1)), Color(0.6, 0.7, 0.45, 0.2))
	if rng.randf() < 0.4:
		_add(Rect2(o + Vector2(rng.randi_range(3, 10), rng.randi_range(3, 10)), Vector2(3, 2)), Color(0.55, 0.65, 0.4, 0.18))


# --- ground ----------------------------------------------------------------------------------

## Debris and glass against the walls, a fallen beam now and then; only a little by the buildings
## (they are standing, not bombed). Flat and small.
func _rubble(cell: Vector2i, rng: RandomNumberGenerator) -> void:
	var near_up: bool = _is(cell + Vector2i.UP, "house") or _is(cell + Vector2i.UP, "wall")
	var near_side: bool = _is(cell + Vector2i.LEFT, "house") or _is(cell + Vector2i.RIGHT, "house") \
			or _is(cell + Vector2i.LEFT, "wall") or _is(cell + Vector2i.RIGHT, "wall")
	var by_wall: bool = _is(cell + Vector2i.UP, "wall") or _is(cell + Vector2i.LEFT, "wall") or _is(cell + Vector2i.RIGHT, "wall")
	if not (near_up or near_side) or rng.randf() > (0.45 if by_wall else 0.15):
		return
	var o: Vector2 = _origin(cell)
	var chunk: Color = [Color(0.48, 0.3, 0.24), Color(0.4, 0.44, 0.44), Color(0.36, 0.3, 0.22), Color(0.55, 0.56, 0.58)][_zone]
	for i: int in rng.randi_range(2, 5):
		var p: Vector2 = o + Vector2(rng.randi_range(1, 14), rng.randi_range(1, 4) if near_up else rng.randi_range(2, 13))
		_add(Rect2(p, Vector2(rng.randi_range(1, 2), 1)), chunk if rng.randf() < 0.6 else chunk.darkened(0.4))
	if near_up and rng.randf() < 0.35:  # glass from the windows above
		_add(Rect2(o + Vector2(rng.randi_range(2, 13), rng.randi_range(1, 3)), Vector2.ONE), Color(0.6, 0.7, 0.72, 0.6))
	if by_wall and rng.randf() < 0.12:  # a fallen beam lying along the wall
		var p: Vector2 = o + Vector2(rng.randi_range(1, 8), rng.randi_range(2, 5))
		_add(Rect2(p, Vector2(7, 1)), WOOD)
		_add(Rect2(p + Vector2(0, 1), Vector2(7, 1)), Color(0, 0, 0, 0.35))


## Kerbs where road meets grass, and faded centre lines on straight road bands (no paint on
## Greywood's dirt tracks; lab floors get floor guide lines instead).
func _roads(rng: RandomNumberGenerator) -> void:
	var paint: Color = [Color(0.72, 0.62, 0.34, 0.42), Color(0.75, 0.78, 0.76, 0.3), Color(0, 0, 0, 0), Color(0.75, 0.62, 0.2, 0.32)][_zone]
	for y: int in _grid.height:
		for x: int in _grid.width:
			var cell: Vector2i = Vector2i(x, y)
			if not _is(cell, "road"):
				continue
			var o: Vector2 = _origin(cell)
			if _zone != 3:
				for side: Array in [[Vector2i.UP, Rect2(0, 0, 16, 1)], [Vector2i.DOWN, Rect2(0, 15, 16, 1)],
						[Vector2i.LEFT, Rect2(0, 0, 1, 16)], [Vector2i.RIGHT, Rect2(15, 0, 1, 16)]]:
					var n: String = _grid.get_terrain(cell + side[0])
					if n == "grass" or n == "tall_grass" or n == "mud":
						var r: Rect2 = side[1]
						_add(Rect2(o + r.position, r.size), Color(0.62, 0.6, 0.56, 0.3))
			if paint.a <= 0.0:
				continue
			# Centre line: this cell is the middle of a road band 2-5 cells wide and long the other way.
			var up: int = _run(cell, Vector2i.UP)
			var down: int = _run(cell, Vector2i.DOWN)
			var left: int = _run(cell, Vector2i.LEFT)
			var right: int = _run(cell, Vector2i.RIGHT)
			var band_y: int = up + down + 1
			var band_x: int = left + right + 1
			if band_y >= 2 and band_y <= 5 and band_x >= band_y * 3 and up == floori(band_y / 2.0):
				var line_y: float = 0.0 if band_y % 2 == 0 else 7.0
				for seg: int in 2:
					if rng.randf() < 0.75:  # worn away in places
						_add(Rect2(o + Vector2(seg * 8 + 1, line_y), Vector2(5, 1)), paint)
			elif band_x >= 2 and band_x <= 5 and band_y >= band_x * 3 and left == floori(band_x / 2.0):
				var line_x: float = 0.0 if band_x % 2 == 0 else 7.0
				for seg: int in 2:
					if rng.randf() < 0.75:
						_add(Rect2(o + Vector2(line_x, seg * 8 + 1), Vector2(1, 5)), paint)


## Maple Hollow: a few utility poles knocked down onto the verges, lying along the road with
## their cross-arm and a snapped wire. On grass only and flat (1-2 px), so they never look like a
## barrier across a route.
func _utility_poles(rng: RandomNumberGenerator) -> void:
	var placed: int = 0
	for y: int in range(1, _grid.height - 1):
		for x: int in range(1, _grid.width - 1):
			var cell: Vector2i = Vector2i(x, y)
			if placed >= 3 or not _is(cell, "grass") or rng.randf() > 0.03:
				continue
			var along_x: bool = _is(cell + Vector2i.UP, "road") or _is(cell + Vector2i.DOWN, "road")
			var along_y: bool = _is(cell + Vector2i.LEFT, "road") or _is(cell + Vector2i.RIGHT, "road")
			if not (along_x or along_y):
				continue
			var step: Vector2i = Vector2i.RIGHT if along_x else Vector2i.DOWN
			if not (_is(cell + step, "grass") and _is(cell + step * 2, "grass")):
				continue
			var o: Vector2 = _origin(cell) + (Vector2(0, 7) if along_x else Vector2(7, 0))
			var length: Vector2 = Vector2(38, 2) if along_x else Vector2(2, 38)
			_add(Rect2(o + Vector2(1, 1), length), Color(0, 0, 0, 0.4))  # its shadow
			_add(Rect2(o, length), Color(0.3, 0.22, 0.15))
			_add(Rect2(o, Vector2(38, 1) if along_x else Vector2(1, 38)), Color(0.42, 0.32, 0.22))
			var arm: Vector2 = o + (Vector2(31, -3) if along_x else Vector2(-3, 31))
			_add(Rect2(arm, Vector2(2, 8) if along_x else Vector2(8, 2)), Color(0.26, 0.19, 0.13))
			for i: int in 6:  # the snapped wire trailing off
				_add(Rect2(arm + (Vector2(-i * 3, 7 + i % 2) if along_x else Vector2(7 + i % 2, -i * 3)), Vector2.ONE), Color(0.08, 0.08, 0.09))
			placed += 1


## Road cells in a row from `cell` going `dir` (not counting `cell`).
func _run(cell: Vector2i, dir: Vector2i) -> int:
	var n: int = 0
	var c: Vector2i = cell + dir
	while _is(c, "road") and n < 12:
		n += 1
		c += dir
	return n

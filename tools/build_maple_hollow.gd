extends SceneTree
## One-off builder for the greybox Maple Hollow map. Hand-designed layout, not procedural.
## Run:  godot --headless --path . -s res://tools/build_maple_hollow.gd
## Writes the tileset and the map scene. After that, edit the map in the TileMap editor;
## re-running this script overwrites those edits.

const TILESET_PATH: String = "res://world/tilesets/greybox_tileset.tres"
const SCENE_PATH: String = "res://world/zones/maple_hollow/maple_hollow.tscn"
const ZONE_MAP_SCRIPT: String = "res://world/zones/zone_map.gd"
const TILE: int = 16
const MAP_SIZE: Vector2i = Vector2i(60, 34)

## Atlas column = index in this list. "solid" tiles get collision on physics layer 1 (world).
const TERRAINS: Array[Dictionary] = [
	{"name": "road", "char": ".", "color": Color(0.64, 0.62, 0.58), "solid": false},
	{"name": "grass", "char": ",", "color": Color(0.45, 0.68, 0.4), "solid": false},
	{"name": "tall_grass", "char": "*", "color": Color(0.2, 0.45, 0.24), "solid": false},
	{"name": "fence", "char": "F", "color": Color(0.94, 0.9, 0.78), "solid": true},
	{"name": "wall", "char": "#", "color": Color(0.2, 0.22, 0.2), "solid": true},
	{"name": "house", "char": "H", "color": Color(0.88, 0.6, 0.66), "solid": true},
]

## Player spawn in the middle of the crossroads; enemy spawns around the edges (all >= 15 tiles away).
const PLAYER_SPAWN: Vector2i = Vector2i(30, 17)
const ENEMY_SPAWNS: Array[Vector2i] = [
	Vector2i(2, 2), Vector2i(57, 2), Vector2i(2, 31), Vector2i(57, 31),
	Vector2i(1, 16), Vector2i(58, 17), Vector2i(29, 1), Vector2i(30, 32),
]

var _grid: Array[PackedStringArray] = []


func _initialize() -> void:
	_paint_layout()
	_print_preview()
	_check_reachability()
	var tileset: TileSet = _build_tileset()
	ResourceSaver.save(tileset, TILESET_PATH)
	tileset = ResourceLoader.load(TILESET_PATH, "", ResourceLoader.CACHE_MODE_REPLACE)
	_save_scene(tileset)
	quit()


# --- Layout -------------------------------------------------------------------------

func _paint_layout() -> void:
	for y: int in MAP_SIZE.y:
		var row: PackedStringArray = PackedStringArray()
		row.resize(MAP_SIZE.x)
		row.fill(",")
		_grid.append(row)

	# Border: trees / walls all round.
	_rect(0, 0, MAP_SIZE.x, 1, "#")
	_rect(0, MAP_SIZE.y - 1, MAP_SIZE.x, 1, "#")
	_rect(0, 0, 1, MAP_SIZE.y, "#")
	_rect(MAP_SIZE.x - 1, 0, 1, MAP_SIZE.y, "#")

	# Roads: main street (E-W), cross street (N-S), two side lanes.
	_rect(1, 16, 58, 2, ".")
	_rect(29, 1, 2, 32, ".")
	_rect(1, 7, 28, 1, ".")
	_rect(45, 18, 2, 15, ".")

	# Houses (solid blocks).
	_rect(3, 2, 6, 4, "H")
	_rect(14, 2, 6, 4, "H")
	_rect(3, 9, 7, 5, "H")
	_rect(22, 9, 5, 5, "H")
	_rect(34, 3, 8, 5, "H")
	_rect(47, 2, 7, 4, "H")
	_rect(48, 9, 6, 5, "H")
	_rect(4, 20, 6, 5, "H")
	_rect(15, 21, 8, 4, "H")
	_rect(5, 27, 5, 4, "H")
	_rect(34, 20, 7, 5, "H")
	_rect(50, 21, 6, 4, "H")
	_rect(35, 27, 6, 4, "H")
	_rect(50, 27, 6, 4, "H")

	# Fences with gates: they turn straight lines into detours (gates marked by the "." after).
	_rect(13, 18, 1, 15, "F")      # SW long fence (west yards vs. centre)
	_rect(13, 25, 1, 2, ",")       #   gate
	_rect(43, 19, 1, 13, "F")      # SE fence beside the lane
	_rect(43, 26, 1, 1, ",")       #   gate
	_rect(47, 25, 12, 1, "F")      # SE back yards
	_rect(52, 25, 1, 1, ",")       #   gate
	_rect(31, 12, 14, 1, "F")      # NE garden fence
	_rect(38, 12, 1, 1, ",")       #   gate
	_rect(12, 6, 10, 1, "F")       # NW front yard along the lane
	_rect(17, 6, 1, 1, ",")        #   gate
	_rect(24, 14, 5, 1, "F")       # short fences framing the crossroads
	_rect(31, 14, 5, 1, "F")
	_rect(24, 19, 5, 1, "F")
	_rect(31, 19, 5, 1, "F")

	# Tall grass / bushes (cover, no collision).
	_rect(2, 13, 1, 2, "*")
	_rect(23, 2, 4, 3, "*")
	_rect(36, 9, 6, 2, "*")
	_rect(52, 14, 5, 1, "*")
	_rect(16, 27, 6, 3, "*")
	_rect(47, 19, 3, 2, "*")
	_rect(24, 22, 4, 4, "*")
	_rect(10, 2, 2, 3, "*")


func _rect(x: int, y: int, w: int, h: int, c: String) -> void:
	for yy: int in range(y, y + h):
		for xx: int in range(x, x + w):
			_grid[yy][xx] = c


func _print_preview() -> void:
	for y: int in MAP_SIZE.y:
		var line: String = ""
		for x: int in MAP_SIZE.x:
			var cell: Vector2i = Vector2i(x, y)
			if cell == PLAYER_SPAWN:
				line += "P"
			elif ENEMY_SPAWNS.has(cell):
				line += "E"
			else:
				line += _grid[y][x]
		print(line)


## Sanity check: every walkable cell and every enemy spawn can reach the player spawn on foot
## (fences counted as blocked, like for the player).
func _check_reachability() -> void:
	var seen: Dictionary = {PLAYER_SPAWN: true}
	var frontier: Array[Vector2i] = [PLAYER_SPAWN]
	while not frontier.is_empty():
		var cell: Vector2i = frontier.pop_back()
		for step: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = cell + step
			if seen.has(next) or not _walkable(next):
				continue
			seen[next] = true
			frontier.append(next)
	var walkable: int = 0
	for y: int in MAP_SIZE.y:
		for x: int in MAP_SIZE.x:
			if _walkable(Vector2i(x, y)):
				walkable += 1
	print("walkable cells: %d, reachable from player spawn: %d" % [walkable, seen.size()])
	for spawn: Vector2i in ENEMY_SPAWNS:
		assert(_walkable(spawn), "enemy spawn on solid tile: %s" % spawn)
		print("enemy spawn %s reachable: %s, distance %.1f tiles" % [spawn, seen.has(spawn), Vector2(spawn - PLAYER_SPAWN).length()])


func _walkable(cell: Vector2i) -> bool:
	if cell.x < 0 or cell.y < 0 or cell.x >= MAP_SIZE.x or cell.y >= MAP_SIZE.y:
		return false
	return _grid[cell.y][cell.x] in [".", ",", "*"]


# --- Resources ----------------------------------------------------------------------

func _build_tileset() -> TileSet:
	var tileset: TileSet = TileSet.new()
	tileset.tile_size = Vector2i(TILE, TILE)
	tileset.add_physics_layer()
	tileset.set_physics_layer_collision_layer(0, 1)   # layer 1 = world
	tileset.set_physics_layer_collision_mask(0, 0)
	tileset.add_custom_data_layer()
	tileset.set_custom_data_layer_name(0, ZoneMap.TERRAIN_DATA_LAYER)
	tileset.set_custom_data_layer_type(0, TYPE_STRING)

	var source: TileSetAtlasSource = TileSetAtlasSource.new()
	source.texture = ImageTexture.create_from_image(_build_atlas_image())
	source.texture_region_size = Vector2i(TILE, TILE)
	tileset.add_source(source, 0)

	var half: float = TILE / 2.0
	var square: PackedVector2Array = PackedVector2Array([
		Vector2(-half, -half), Vector2(half, -half), Vector2(half, half), Vector2(-half, half)])
	for i: int in TERRAINS.size():
		var coords: Vector2i = Vector2i(i, 0)
		source.create_tile(coords)
		var data: TileData = source.get_tile_data(coords, 0)
		data.set_custom_data(ZoneMap.TERRAIN_DATA_LAYER, TERRAINS[i]["name"])
		if TERRAINS[i]["solid"]:
			data.add_collision_polygon(0)
			data.set_collision_polygon_points(0, 0, square)
	return tileset


## One 16x16 flat-colour tile per terrain, with a small pattern so types read apart.
func _build_atlas_image() -> Image:
	var img: Image = Image.create(TILE * TERRAINS.size(), TILE, false, Image.FORMAT_RGBA8)
	for i: int in TERRAINS.size():
		var base: Color = TERRAINS[i]["color"]
		var name: String = TERRAINS[i]["name"]
		for y: int in TILE:
			for x: int in TILE:
				var c: Color = base
				match name:
					"grass":
						if (x * 7 + y * 3) % 11 == 0:
							c = base.lightened(0.12)
					"tall_grass":
						if (x + y * 2) % 4 == 0:
							c = base.lightened(0.25)
					"fence":
						# Pickets on a darker rail.
						if y == 5 or y == 11:
							c = Color(0.55, 0.42, 0.3)
						elif x % 4 == 3:
							c = base.darkened(0.35)
					"house", "wall":
						if x == 0 or y == 0 or x == TILE - 1 or y == TILE - 1:
							c = base.darkened(0.3)
				img.set_pixel(i * TILE + x, y, c)
	return img


func _save_scene(tileset: TileSet) -> void:
	var root: Node2D = Node2D.new()
	root.name = "MapleHollow"
	root.set_script(load(ZONE_MAP_SCRIPT))

	var layer: TileMapLayer = TileMapLayer.new()
	layer.name = "Terrain"
	layer.tile_set = tileset
	root.add_child(layer)
	layer.owner = root
	for y: int in MAP_SIZE.y:
		for x: int in MAP_SIZE.x:
			var atlas_x: int = _terrain_index(_grid[y][x])
			layer.set_cell(Vector2i(x, y), 0, Vector2i(atlas_x, 0))

	var player_spawn: Marker2D = Marker2D.new()
	player_spawn.name = "PlayerSpawn"
	player_spawn.position = _cell_center(PLAYER_SPAWN)
	root.add_child(player_spawn)
	player_spawn.owner = root

	var spawns: Node2D = Node2D.new()
	spawns.name = "EnemySpawns"
	root.add_child(spawns)
	spawns.owner = root
	for i: int in ENEMY_SPAWNS.size():
		var marker: Marker2D = Marker2D.new()
		marker.name = "Spawn%d" % (i + 1)
		marker.position = _cell_center(ENEMY_SPAWNS[i])
		spawns.add_child(marker)
		marker.owner = root

	var packed: PackedScene = PackedScene.new()
	packed.pack(root)
	DirAccess.make_dir_recursive_absolute(SCENE_PATH.get_base_dir())
	var err: Error = ResourceSaver.save(packed, SCENE_PATH)
	print("saved %s: %s" % [SCENE_PATH, error_string(err)])
	root.free()


func _terrain_index(c: String) -> int:
	for i: int in TERRAINS.size():
		if TERRAINS[i]["char"] == c:
			return i
	return 1


func _cell_center(cell: Vector2i) -> Vector2:
	return Vector2(cell * TILE) + Vector2(TILE, TILE) / 2.0

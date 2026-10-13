extends SceneTree
## One-off builder for the greybox Maple Hollow map. Hand-designed layout, not procedural.
## Run:  godot --headless --path . -s res://tools/build_maple_hollow.gd
## Writes the tileset and the map scene. After that, edit the map in the TileMap editor;
## re-running this script overwrites those edits.
## Tileset only (after changing data/terrain_costs.tres; leaves the map scene alone):
##       godot --headless --path . -s res://tools/build_maple_hollow.gd -- --tileset-only
##
## The tileset has one tile per TerrainDefinition, in the rulebook's order (atlas column =
## index in TerrainCosts.definitions), coloured, patterned and given collision from the
## definition, so the look and physics of a tile can't drift from its rules.

const TILESET_PATH: String = "res://world/tilesets/greybox_tileset.tres"
const SCENE_PATH: String = "res://world/zones/maple_hollow/maple_hollow.tscn"
const ZONE_MAP_SCRIPT: String = "res://world/zones/zone_map.gd"
const RULES_PATH: String = "res://data/terrain_costs.tres"
const TILE: int = 16
const MAP_SIZE: Vector2i = Vector2i(60, 34)
## Physics layer bits for the tileset's two physics layers (project layer names 1 and 7).
const WORLD_LAYER_BIT: int = 1
const WATER_LAYER_BIT: int = 1 << 6

## Layout characters -> terrain id. Look and collision come from the rulebook.
const CHARS: Dictionary[String, String] = {
	".": "road", ",": "grass", "*": "tall_grass", "F": "fence", "#": "wall", "H": "house",
}

## Player spawn in the middle of the crossroads; enemy spawns around the edges (all >= 15 tiles away).
const PLAYER_SPAWN: Vector2i = Vector2i(30, 17)
const ENEMY_SPAWNS: Array[Vector2i] = [
	Vector2i(2, 2), Vector2i(57, 2), Vector2i(2, 31), Vector2i(57, 31),
	Vector2i(1, 16), Vector2i(58, 17), Vector2i(29, 1), Vector2i(30, 32),
]

var _grid: Array[PackedStringArray] = []
var _definitions: Array[TerrainDefinition] = []


func _initialize() -> void:
	_definitions = (load(RULES_PATH) as TerrainCosts).definitions
	var tileset: TileSet = _build_tileset()
	print("saved %s: %s" % [TILESET_PATH, error_string(ResourceSaver.save(tileset, TILESET_PATH))])
	if OS.get_cmdline_user_args().has("--tileset-only"):
		quit()
		return
	_paint_layout()
	_print_preview()
	_check_reachability()
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


## Walkable for the player (no tile collision), per the rulebook.
func _walkable(cell: Vector2i) -> bool:
	if cell.x < 0 or cell.y < 0 or cell.x >= MAP_SIZE.x or cell.y >= MAP_SIZE.y:
		return false
	return _definitions[_terrain_index(_grid[cell.y][cell.x])].player_passable


# --- Resources ----------------------------------------------------------------------

func _build_tileset() -> TileSet:
	var tileset: TileSet = TileSet.new()
	tileset.tile_size = Vector2i(TILE, TILE)
	tileset.add_physics_layer()
	tileset.set_physics_layer_collision_layer(0, WORLD_LAYER_BIT)   # SOLID tiles
	tileset.set_physics_layer_collision_mask(0, 0)
	tileset.add_physics_layer()
	tileset.set_physics_layer_collision_layer(1, WATER_LAYER_BIT)   # WATER tiles
	tileset.set_physics_layer_collision_mask(1, 0)
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
	for i: int in _definitions.size():
		var d: TerrainDefinition = _definitions[i]
		var coords: Vector2i = Vector2i(i, 0)
		source.create_tile(coords)
		var data: TileData = source.get_tile_data(coords, 0)
		data.set_custom_data(ZoneMap.TERRAIN_DATA_LAYER, d.id)
		match d.collision:
			TerrainDefinition.Collision.SOLID:
				data.add_collision_polygon(0)
				data.set_collision_polygon_points(0, 0, square)
			TerrainDefinition.Collision.WATER:
				data.add_collision_polygon(1)
				data.set_collision_polygon_points(1, 0, square)
	return tileset


## One 16x16 tile per terrain: the definition's colour plus a small pattern so types read
## apart at native resolution.
func _build_atlas_image() -> Image:
	var img: Image = Image.create(TILE * _definitions.size(), TILE, false, Image.FORMAT_RGBA8)
	for i: int in _definitions.size():
		for y: int in TILE:
			for x: int in TILE:
				img.set_pixel(i * TILE + x, y, _pattern_pixel(_definitions[i], x, y))
	return img


func _pattern_pixel(d: TerrainDefinition, x: int, y: int) -> Color:
	var base: Color = d.color
	var edge: bool = x == 0 or y == 0 or x == TILE - 1 or y == TILE - 1
	match d.pattern:
		TerrainDefinition.Pattern.SPECKLE:
			if (x * 7 + y * 3) % 11 == 0:
				return base.lightened(0.12)
		TerrainDefinition.Pattern.BLADES:
			if (x + y * 2) % 4 == 0:
				return base.lightened(0.25)
		TerrainDefinition.Pattern.PICKETS:  # pickets on a darker rail
			if y == 5 or y == 11:
				return Color(0.55, 0.42, 0.3)
			if x % 4 == 3:
				return base.darkened(0.35)
		TerrainDefinition.Pattern.OUTLINE:
			if edge:
				return base.darkened(0.3)
		TerrainDefinition.Pattern.BRICK:
			if y % 4 == 3 or x % 8 == (7 if (y / 4) % 2 == 0 else 3):
				return base.darkened(0.3)
		TerrainDefinition.Pattern.WAVES:  # short light crests
			if y % 4 == 1 and (x + (y / 4) * 3) % 8 < 3:
				return base.lightened(0.3)
		TerrainDefinition.Pattern.RIPPLES:
			if (x * 3 + y * 5) % 13 == 0:
				return base.lightened(0.35)
		TerrainDefinition.Pattern.PLANKS:  # boards with dark seams
			if y % 4 == 3:
				return base.darkened(0.35)
			if edge:
				return base.darkened(0.2)
		TerrainDefinition.Pattern.GRATE:  # slots in a metal frame
			if edge:
				return base.darkened(0.2)
			if y % 3 == 1 and x >= 2 and x <= TILE - 3:
				return base.darkened(0.55)
		TerrainDefinition.Pattern.CROSSHATCH:  # X of boards
			if absi(x - y) <= 1 or absi(x + y - (TILE - 1)) <= 1:
				return base.darkened(0.35)
			if edge:
				return base.darkened(0.2)
		TerrainDefinition.Pattern.BLOBS:
			if Vector2(x - 4, y - 5).length_squared() < 5.0 or Vector2(x - 11, y - 10).length_squared() < 6.0 \
					or Vector2(x - 12, y - 3).length_squared() < 3.0:
				return base.darkened(0.25)
		TerrainDefinition.Pattern.CANOPY:  # round crown on dark ground
			if Vector2(x - 7.5, y - 7.5).length() > 7.2:
				return base.darkened(0.5)
			if (x * 5 + y * 3) % 7 == 0:
				return base.lightened(0.2)
		TerrainDefinition.Pattern.DOTS:
			if (x % 4 == 1 and y % 4 == 1) or (x % 4 == 3 and y % 4 == 3):
				return base.darkened(0.1)
		TerrainDefinition.Pattern.FLAMES:
			if (x + y) % 5 == 0 or (x * 2 + 15 - y) % 7 == 0:
				return Color(1.0, 0.85, 0.25)
	return base


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


## Atlas column of a layout character = index of its terrain in the rulebook.
func _terrain_index(c: String) -> int:
	for i: int in _definitions.size():
		if _definitions[i].id == CHARS[c]:
			return i
	assert(false, "unknown layout character '%s'" % c)
	return 0


func _cell_center(cell: Vector2i) -> Vector2:
	return Vector2(cell * TILE) + Vector2(TILE, TILE) / 2.0

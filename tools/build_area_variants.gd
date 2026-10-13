extends SceneTree
## Builds the three hand-made Maple Hollow AREA variants used by wave-to-wave progression
## (expansion phase 5): the player enters on the left, the exit gate is on the right.
## Run:  godot --headless --path . -s res://tools/build_area_variants.gd
## Writes world/zones/maple_hollow/areas/area_<n>.tscn (re-running overwrites editor edits).
##
## Each area: 60 x 34 tiles, wall border, entry at the left (x 1-2, y 16-17), exit gate
## ("gate" tiles in the right border, x 59, y 15-18), 8 enemy spawns >= 15 tiles from the entry,
## 2 "behind" spawns near the left edge (part of later waves arrives from there).

const TILESET_PATH: String = "res://world/tilesets/greybox_tileset.tres"
const RULES_PATH: String = "res://data/terrain_costs.tres"
const OUT_DIR: String = "res://world/zones/maple_hollow/areas/"
const ZONE_MAP_SCRIPT: String = "res://world/zones/zone_map.gd"
const TILE: int = 16
const SIZE: Vector2i = Vector2i(60, 34)
const ENTRY: Vector2i = Vector2i(2, 16)
const CHARS: Dictionary[String, String] = {
	".": "road", ",": "grass", "*": "tall_grass", "F": "fence", "#": "wall", "H": "house",
	"T": "tree", "G": "gate", "m": "mud",
}

var _grid: Array[PackedStringArray] = []
var _definitions: Array[TerrainDefinition] = []


func _initialize() -> void:
	_definitions = (load(RULES_PATH) as TerrainCosts).definitions
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var tileset: TileSet = load(TILESET_PATH)
	for n: int in [1, 2, 3]:
		_base()
		call("_layout_%d" % n)
		var spawns: Array[Vector2i] = _spawns(n)
		var behind: Array[Vector2i] = [Vector2i(6, 2), Vector2i(6, 31)]
		_check(n, spawns + behind)
		_save(n, tileset, spawns, behind)
	quit()


# --- Layouts ------------------------------------------------------------------------

func _base() -> void:
	_grid.clear()
	for y: int in SIZE.y:
		var row: PackedStringArray = PackedStringArray()
		row.resize(SIZE.x)
		row.fill(",")
		_grid.append(row)
	_rect(0, 0, SIZE.x, 1, "#")
	_rect(0, SIZE.y - 1, SIZE.x, 1, "#")
	_rect(0, 0, 1, SIZE.y, "#")
	_rect(SIZE.x - 1, 0, 1, SIZE.y, "#")
	_rect(1, 16, 4, 2, ".")              # entry road
	_rect(54, 15, 5, 4, ".")             # exit apron
	_rect(SIZE.x - 1, 15, 1, 4, "G")     # exit gate (opens when the wave is done)


## Area 1 "Main Street": one long E-W street, houses either side, side yards behind fences.
func _layout_1() -> void:
	_rect(1, 16, 58, 2, ".")
	_rect(14, 1, 2, 32, ".")
	_rect(38, 1, 2, 32, ".")
	for x: int in [4, 20, 28, 44]:
		_rect(x, 4, 7, 5, "H")
		_rect(x, 24, 7, 5, "H")
	_rect(3, 12, 10, 1, "F")
	_rect(7, 12, 1, 1, ",")
	_rect(41, 20, 12, 1, "F")
	_rect(46, 20, 1, 1, ",")
	_rect(18, 11, 18, 1, "F")
	_rect(26, 11, 2, 1, ",")
	_rect(22, 19, 1, 4, "*")
	_rect(48, 10, 6, 3, "*")
	_rect(5, 21, 6, 2, "*")
	_rect(32, 29, 4, 3, "T")


## Area 2 "Backyards": the road zig-zags; fences cut the yards into pockets (climbers shine).
func _layout_2() -> void:
	_rect(1, 16, 12, 2, ".")
	_rect(11, 6, 2, 12, ".")
	_rect(11, 6, 20, 2, ".")
	_rect(29, 6, 2, 22, ".")
	_rect(29, 26, 20, 2, ".")
	_rect(47, 15, 2, 13, ".")
	_rect(47, 15, 12, 2, ".")
	_rect(3, 19, 5, 3, "H")
	_rect(16, 10, 9, 5, "H")
	_rect(34, 10, 9, 6, "H")
	_rect(16, 22, 8, 6, "H")
	_rect(52, 3, 5, 6, "H")
	_rect(52, 24, 5, 6, "H")
	_rect(20, 1, 1, 5, "F")
	_rect(14, 18, 14, 1, "F")
	_rect(20, 18, 1, 1, ",")
	_rect(32, 18, 12, 1, "F")
	_rect(38, 18, 1, 1, ",")
	_rect(44, 8, 1, 10, "F")
	_rect(44, 12, 1, 1, ",")
	_rect(33, 21, 1, 4, "F")
	_rect(3, 24, 6, 6, "*")
	_rect(36, 2, 6, 3, "*")
	_rect(40, 29, 6, 3, "m")
	_rect(4, 9, 3, 3, "T")


## Area 3 "Cul-de-sac": a ring road round a planted circle; two ways to the exit.
func _layout_3() -> void:
	_rect(1, 16, 14, 2, ".")
	_rect(14, 5, 2, 24, ".")
	_rect(14, 5, 32, 2, ".")
	_rect(14, 27, 32, 2, ".")
	_rect(44, 5, 2, 24, ".")
	_rect(44, 16, 15, 2, ".")
	_rect(20, 11, 20, 12, "*")
	_rect(26, 14, 8, 6, "T")
	_rect(18, 1, 6, 3, "H")
	_rect(28, 1, 6, 3, "H")
	_rect(38, 1, 5, 3, "H")
	_rect(18, 30, 6, 3, "H")
	_rect(28, 30, 6, 3, "H")
	_rect(38, 30, 5, 3, "H")
	_rect(49, 4, 7, 5, "H")
	_rect(49, 24, 7, 5, "H")
	_rect(16, 9, 26, 1, "F")
	_rect(29, 9, 2, 1, ",")
	_rect(16, 24, 26, 1, "F")
	_rect(23, 24, 1, 1, ",")
	_rect(3, 3, 8, 8, "*")
	_rect(4, 22, 5, 5, "T")


func _spawns(n: int) -> Array[Vector2i]:
	match n:
		1: return [Vector2i(30, 2), Vector2i(30, 31), Vector2i(47, 2), Vector2i(47, 31),
				Vector2i(56, 10), Vector2i(56, 23), Vector2i(36, 16), Vector2i(22, 2)]
		2: return [Vector2i(30, 2), Vector2i(26, 31), Vector2i(48, 2), Vector2i(45, 31),
				Vector2i(57, 11), Vector2i(57, 21), Vector2i(39, 23), Vector2i(23, 3)]
		_: return [Vector2i(30, 7), Vector2i(30, 26), Vector2i(46, 2), Vector2i(46, 31),
				Vector2i(57, 10), Vector2i(57, 22), Vector2i(36, 25), Vector2i(20, 7)]


func _rect(x: int, y: int, w: int, h: int, c: String) -> void:
	for yy: int in range(y, y + h):
		for xx: int in range(x, x + w):
			_grid[yy][xx] = c


# --- Checks -------------------------------------------------------------------------

## Entry reaches the exit and every spawn on foot (gate counted open, fences closed); every
## main spawn is >= 15 tiles from the entry.
func _check(n: int, spawns: Array[Vector2i]) -> void:
	var seen: Dictionary = {ENTRY: true}
	var frontier: Array[Vector2i] = [ENTRY]
	while not frontier.is_empty():
		var cell: Vector2i = frontier.pop_back()
		for step: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = cell + step
			if seen.has(next) or not _walkable(next):
				continue
			seen[next] = true
			frontier.append(next)
	assert(seen.has(Vector2i(SIZE.x - 1, 16)), "area %d: exit unreachable" % n)
	for i: int in spawns.size():
		var s: Vector2i = spawns[i]
		assert(seen.has(s), "area %d: spawn %s unreachable" % [n, s])
		if i < 8:
			assert(Vector2(s - ENTRY).length() >= 15.0, "area %d: spawn %s too close" % [n, s])
	print("area %d ok: %d reachable cells" % [n, seen.size()])


func _walkable(cell: Vector2i) -> bool:
	if cell.x < 0 or cell.y < 0 or cell.x >= SIZE.x or cell.y >= SIZE.y:
		return false
	var c: String = _grid[cell.y][cell.x]
	return c == "G" or _definition(c).player_passable


func _definition(c: String) -> TerrainDefinition:
	for d: TerrainDefinition in _definitions:
		if d.id == CHARS[c]:
			return d
	assert(false, "unknown char " + c)
	return null


# --- Scene --------------------------------------------------------------------------

func _save(n: int, tileset: TileSet, spawns: Array[Vector2i], behind: Array[Vector2i]) -> void:
	var root: Node2D = Node2D.new()
	root.name = "Area%d" % n
	root.set_script(load(ZONE_MAP_SCRIPT))
	var layer: TileMapLayer = TileMapLayer.new()
	layer.name = "Terrain"
	layer.tile_set = tileset
	root.add_child(layer)
	layer.owner = root
	for y: int in SIZE.y:
		for x: int in SIZE.x:
			layer.set_cell(Vector2i(x, y), 0, Vector2i(_definitions.find(_definition(_grid[y][x])), 0))
	_marker(root, root, "PlayerSpawn", ENTRY)
	_marker(root, root, "Exit", Vector2i(SIZE.x - 2, 16))
	for group: Array in [["EnemySpawns", spawns], ["BehindSpawns", behind]]:
		var parent: Node2D = Node2D.new()
		parent.name = group[0]
		root.add_child(parent)
		parent.owner = root
		for i: int in (group[1] as Array).size():
			_marker(root, parent, "Spawn%d" % (i + 1), group[1][i])
	var packed: PackedScene = PackedScene.new()
	packed.pack(root)
	var path: String = OUT_DIR + "area_%d.tscn" % n
	print("saved %s: %s" % [path, error_string(ResourceSaver.save(packed, path))])
	root.free()


func _marker(root: Node, parent: Node, marker_name: String, cell: Vector2i) -> void:
	var m: Marker2D = Marker2D.new()
	m.name = marker_name
	m.position = Vector2(cell * TILE) + Vector2(TILE, TILE) / 2.0
	parent.add_child(m)
	m.owner = root

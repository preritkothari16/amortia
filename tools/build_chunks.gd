extends SceneTree
## Builds the Maple Hollow room-chunk library for the CSP level generator (GDD 4.6).
## Run:  godot --headless --path . -s res://tools/build_chunks.gd
## Writes data/chunks/maple_hollow_chunks.tres.
##
## Every chunk is 16 x 16, hand-designed below as a list of rectangles on a grass field:
##   - a solid border (wall) with a 2-tile road opening in the middle of each edge it exits
##   - roads joining its exits through the centre (rows / columns 7-8)
##   - houses, fences, trees, tall grass, ponds, spills as listed
## The tool checks each chunk: border solid except openings, every exit reachable from every
## other on foot (player rules), spawn cells walkable. Exits and tags are derived, not typed.

const OUT_PATH: String = "res://data/chunks/maple_hollow_chunks.tres"
const RULES_PATH: String = "res://data/terrain_costs.tres"
const SIZE: int = 16
const LEGEND: Dictionary[String, String] = {
	".": "road", ",": "grass", "*": "tall_grass", "F": "fence", "#": "wall", "H": "house",
	"T": "tree", "m": "mud", "s": "shallow_water", "~": "deep_water", "x": "toxic_pool",
}

## id, exits ("NESW" letters), feature rects [x, y, w, h, char], spawn cells, chokepoint.
const DESIGNS: Array = [
	["crossroads", "NESW", [[2, 2, 4, 3, "H"], [10, 2, 4, 3, "H"], [2, 11, 4, 3, "H"], [10, 11, 4, 3, "H"], [11, 6, 3, 1, "*"]], [Vector2i(1, 6), Vector2i(14, 9)], false],
	["main_street", "EW", [[2, 2, 5, 4, "H"], [9, 2, 5, 4, "H"], [2, 10, 5, 4, "H"], [9, 10, 5, 4, "H"], [1, 6, 5, 1, "F"]], [Vector2i(7, 3), Vector2i(8, 12)], false],
	["avenue", "NS", [[2, 2, 4, 5, "H"], [10, 2, 4, 5, "H"], [2, 9, 4, 5, "H"], [10, 9, 4, 5, "H"]], [Vector2i(3, 8), Vector2i(12, 7)], false],
	["corner_ne", "NE", [[2, 2, 4, 4, "H"], [2, 10, 5, 4, "H"], [10, 10, 4, 4, "H"], [10, 2, 4, 3, "*"]], [Vector2i(3, 8), Vector2i(12, 4)], false],
	["corner_es", "ES", [[2, 2, 5, 4, "H"], [10, 2, 4, 4, "H"], [2, 10, 4, 4, "H"], [11, 11, 3, 3, "T"]], [Vector2i(3, 8), Vector2i(12, 6)], false],
	["corner_sw", "SW", [[2, 2, 4, 4, "H"], [10, 2, 4, 4, "H"], [10, 10, 4, 4, "H"], [2, 11, 3, 3, "*"]], [Vector2i(3, 12), Vector2i(12, 7)], false],
	["corner_wn", "WN", [[10, 2, 4, 4, "H"], [2, 10, 4, 4, "H"], [10, 10, 4, 4, "H"], [2, 2, 3, 3, "T"]], [Vector2i(2, 6), Vector2i(12, 8)], false],
	["t_new", "NEW", [[2, 10, 4, 4, "H"], [10, 10, 4, 4, "H"], [2, 2, 4, 4, "H"], [11, 2, 3, 3, "*"]], [Vector2i(12, 3), Vector2i(7, 12)], false],
	["t_esw", "ESW", [[2, 2, 4, 4, "H"], [10, 2, 4, 4, "H"], [2, 10, 4, 4, "H"], [11, 11, 3, 3, "*"]], [Vector2i(7, 3), Vector2i(12, 12)], false],
	["t_nes", "NES", [[2, 2, 4, 4, "H"], [2, 10, 4, 4, "H"], [10, 10, 4, 4, "H"], [10, 2, 4, 3, "T"]], [Vector2i(12, 6), Vector2i(3, 8)], false],
	["t_nsw", "NSW", [[10, 2, 4, 4, "H"], [10, 10, 4, 4, "H"], [2, 2, 4, 4, "H"], [2, 11, 3, 3, "*"]], [Vector2i(3, 12), Vector2i(12, 8)], false],
	["fenced_pass_ew", "EW", [[5, 1, 1, 14, "F"], [10, 1, 1, 14, "F"], [5, 7, 1, 2, "."], [10, 7, 1, 2, "."], [1, 1, 3, 3, "*"], [12, 12, 3, 3, "*"]], [Vector2i(2, 2), Vector2i(13, 13)], true],
	["fenced_pass_ns", "NS", [[1, 5, 14, 1, "F"], [1, 10, 14, 1, "F"], [7, 5, 2, 1, "."], [7, 10, 2, 1, "."], [1, 1, 3, 3, "*"], [12, 12, 3, 3, "*"]], [Vector2i(2, 2), Vector2i(13, 13)], true],
	["pond_ew", "EW", [[3, 2, 10, 4, "s"], [5, 3, 6, 2, "~"], [10, 11, 3, 2, "x"]], [Vector2i(2, 12), Vector2i(13, 12)], false],
	["spill_ns", "NS", [[2, 3, 4, 3, "x"], [10, 9, 4, 4, "s"], [11, 10, 2, 2, "~"]], [Vector2i(3, 12), Vector2i(12, 3)], false],
	["spill_plaza", "NESW", [[2, 2, 3, 3, "x"], [11, 11, 3, 3, "x"], [11, 2, 3, 3, "*"], [2, 11, 3, 3, "*"]], [Vector2i(12, 4), Vector2i(4, 12)], false],
]

var _rules: TerrainCosts


func _initialize() -> void:
	_rules = load(RULES_PATH)
	var library: RoomChunkLibrary = RoomChunkLibrary.new()
	library.legend = LEGEND
	var chunks: Array[RoomChunk] = []
	for d: Array in DESIGNS:
		chunks.append(_build(d))
	library.chunks = chunks
	DirAccess.make_dir_recursive_absolute(OUT_PATH.get_base_dir())
	print("saved %s (%d chunks): %s" % [OUT_PATH, chunks.size(), error_string(ResourceSaver.save(library, OUT_PATH))])
	quit()


func _build(design: Array) -> RoomChunk:
	var grid: Array[PackedStringArray] = []
	for y: int in SIZE:
		var row: PackedStringArray = PackedStringArray()
		row.resize(SIZE)
		row.fill(",")
		grid.append(row)
	for i: int in SIZE:  # solid border
		grid[0][i] = "#"
		grid[SIZE - 1][i] = "#"
		grid[i][0] = "#"
		grid[i][SIZE - 1] = "#"
	var letters: String = design[1]
	var exits: int = 0
	for letter: String in letters:
		var dir: int = {"N": RoomChunk.N, "E": RoomChunk.E, "S": RoomChunk.S, "W": RoomChunk.W}[letter]
		exits |= dir
		_road_to_centre(grid, dir)
	for r: Array in design[2]:
		for y: int in range(r[1], r[1] + r[3]):
			for x: int in range(r[0], r[0] + r[2]):
				grid[y][x] = r[4]
	var chunk: RoomChunk = RoomChunk.new()
	chunk.id = design[0]
	chunk.exits = exits
	chunk.chokepoint = design[4]
	var cells: PackedStringArray = PackedStringArray()
	for row: PackedStringArray in grid:
		cells.append("".join(row))
	chunk.cells = cells
	var spawns: Array[Vector2i] = []
	spawns.assign(design[3])
	chunk.spawn_cells = spawns
	for row: String in cells:
		for c: String in row:
			var def: TerrainDefinition = _rules.get_definition(LEGEND[c])
			chunk.hazard = chunk.hazard or def.hazard != TerrainDefinition.Hazard.NONE or def.id == "deep_water"
	_validate(chunk)
	return chunk


## Road from the edge opening to the centre square (7..8, 7..8).
func _road_to_centre(grid: Array[PackedStringArray], dir: int) -> void:
	for i: int in range(0, 9):
		for k: int in [7, 8]:
			match dir:
				RoomChunk.N: grid[i][k] = "."
				RoomChunk.S: grid[SIZE - 1 - i][k] = "."
				RoomChunk.W: grid[k][i] = "."
				RoomChunk.E: grid[k][SIZE - 1 - i] = "."


func _validate(chunk: RoomChunk) -> void:
	for i: int in SIZE:
		for cell: Vector2i in [Vector2i(i, 0), Vector2i(i, SIZE - 1), Vector2i(0, i), Vector2i(SIZE - 1, i)]:
			var is_opening: bool = false
			for dir: int in [RoomChunk.N, RoomChunk.E, RoomChunk.S, RoomChunk.W]:
				if chunk.has_exit(dir) and RoomChunk.opening_cells(dir).has(cell):
					is_opening = true
			assert(_walkable(chunk.char_at(cell)) == is_opening, "%s: border cell %s" % [chunk.id, cell])
	var start: Vector2i = Vector2i(7, 7)
	var seen: Dictionary = {start: true}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		for d: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
			var n: Vector2i = c + d
			if n.x < 0 or n.y < 0 or n.x >= SIZE or n.y >= SIZE or seen.has(n) or not _walkable(chunk.char_at(n)):
				continue
			seen[n] = true
			queue.append(n)
	for dir: int in [RoomChunk.N, RoomChunk.E, RoomChunk.S, RoomChunk.W]:
		if chunk.has_exit(dir):
			for c: Vector2i in RoomChunk.opening_cells(dir):
				assert(seen.has(c), "%s: exit %d not connected" % [chunk.id, dir])
	for s: Vector2i in chunk.spawn_cells:
		assert(_walkable(chunk.char_at(s)), "%s: spawn %s not walkable" % [chunk.id, s])
	print("chunk %-16s exits %2d choke %s hazard %s ok" % [chunk.id, chunk.exits, chunk.chokepoint, chunk.hazard])


func _walkable(c: String) -> bool:
	return _rules.get_definition(LEGEND[c]).player_passable

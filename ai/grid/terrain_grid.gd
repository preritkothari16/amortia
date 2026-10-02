class_name TerrainGrid
extends RefCounted
## The level as plain data for the AI: one movement cost per tile.
## No Node dependencies, so A*, the flow field and tests can use it headless.
##
## Cells are Vector2i(x, y) with (0, 0) at the top-left. Costs are stored in one flat
## array, index = y * width + x, which is faster than an array of arrays.

## Moving diagonally covers sqrt(2) times the distance of a straight step.
const DIAGONAL_FACTOR: float = 1.41421356

## The 4 straight neighbour offsets, then the 4 diagonals.
const STRAIGHT_DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const DIAGONAL_DIRS: Array[Vector2i] = [Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]

var width: int = 0
var height: int = 0
## Tile size in pixels, used only for world <-> cell conversion.
var tile_size: int = 16

var _costs: TerrainCosts
var _terrain: PackedStringArray = PackedStringArray()
var _cost: PackedFloat32Array = PackedFloat32Array()


## Builds a grid from terrain names row by row (rows[y][x]), e.g. ZoneMap.get_terrain_rows().
static func from_rows(rows: Array[PackedStringArray], costs: TerrainCosts, tile_px: int = 16) -> TerrainGrid:
	var grid: TerrainGrid = TerrainGrid.new()
	grid._costs = costs
	grid.tile_size = tile_px
	grid.height = rows.size()
	grid.width = rows[0].size() if grid.height > 0 else 0
	grid._terrain.resize(grid.width * grid.height)
	grid._cost.resize(grid.width * grid.height)
	for y: int in grid.height:
		assert(rows[y].size() == grid.width, "TerrainGrid: row %d has the wrong length" % y)
		for x: int in grid.width:
			grid.set_terrain(Vector2i(x, y), rows[y][x])
	return grid


func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < width and cell.y < height


## Cost of stepping into this cell. INF = cannot enter (wall, house, outside the map).
func get_cost(cell: Vector2i) -> float:
	if not in_bounds(cell):
		return INF
	return _cost[_index(cell)]


func is_walkable(cell: Vector2i) -> bool:
	return get_cost(cell) < INF


func get_terrain(cell: Vector2i) -> String:
	if not in_bounds(cell):
		return ""
	return _terrain[_index(cell)]


## Changes one cell at runtime (later: fire, broken fences, barricades) and updates its cost.
func set_terrain(cell: Vector2i, terrain: String) -> void:
	var i: int = _index(cell)
	_terrain[i] = terrain
	_cost[i] = _costs.cost_of(terrain)


## Walkable cells next to `cell`. With diagonals on, a diagonal step is only allowed when
## both straight cells beside it are walkable, so units never cut through a wall corner.
func get_neighbors(cell: Vector2i, allow_diagonal: bool = true) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for dir: Vector2i in STRAIGHT_DIRS:
		if is_walkable(cell + dir):
			result.append(cell + dir)
	if allow_diagonal:
		for dir: Vector2i in DIAGONAL_DIRS:
			var side_a: Vector2i = cell + Vector2i(dir.x, 0)
			var side_b: Vector2i = cell + Vector2i(0, dir.y)
			if is_walkable(cell + dir) and is_walkable(side_a) and is_walkable(side_b):
				result.append(cell + dir)
	return result


## Edge cost for search algorithms: cost of entering `to`, times sqrt(2) for a diagonal step.
## Assumes `to` is a neighbour of `from` (from get_neighbors).
func get_step_cost(from: Vector2i, to: Vector2i) -> float:
	var cost: float = get_cost(to)
	if from.x != to.x and from.y != to.y:
		cost *= DIAGONAL_FACTOR
	return cost


func world_to_cell(world_pos: Vector2) -> Vector2i:
	return Vector2i(floori(world_pos.x / tile_size), floori(world_pos.y / tile_size))


## Centre of the cell in world pixels.
func cell_to_world(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * tile_size


func _index(cell: Vector2i) -> int:
	return cell.y * width + cell.x

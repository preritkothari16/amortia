class_name TerrainGrid
extends RefCounted
## The level as plain data for the AI: which terrain is in every tile.
## No Node dependencies, so A*, Greedy, the flow field and tests can all use it headless.
##
## Cells are Vector2i(x, y) with (0, 0) at the top-left. Each cell stores a terrain id in
## one flat array, index = y * width + x (faster than an array of arrays).
## Costs are NOT stored per cell: they come from a TerrainCostProfile, so the same grid
## answers "what does this cost a normal Runner?" and "...a climber?" without copying.
## Every query takes an optional profile; leaving it out uses base_profile.
## World <-> cell conversion lives in `coords` (GridCoords), not here.

## Moving diagonally covers sqrt(2) times the distance of a straight step.
const DIAGONAL_FACTOR: float = 1.41421356

## The 4 straight neighbour offsets, then the 4 diagonals.
const STRAIGHT_DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const DIAGONAL_DIRS: Array[Vector2i] = [Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]

var width: int = 0
var height: int = 0
var coords: GridCoords
## Costs with no terrain genes (GDD table 4.2).
var base_profile: TerrainCostProfile

var _rules: TerrainCosts
## Terrain id -> name, and the reverse. Ids match TerrainCostProfile ids.
var _names: PackedStringArray = PackedStringArray()
var _id_by_name: Dictionary[String, int] = {}
## Terrain id per cell; -1 = unknown terrain (impassable).
var _terrain_ids: PackedInt32Array = PackedInt32Array()


## Builds a grid from terrain names row by row (rows[y][x]), e.g. ZoneMap.get_terrain_rows().
static func from_rows(rows: Array[PackedStringArray], rules: TerrainCosts, grid_coords: GridCoords = null) -> TerrainGrid:
	var grid: TerrainGrid = TerrainGrid.new()
	grid._rules = rules
	grid.coords = grid_coords if grid_coords != null else GridCoords.new()
	grid._names = rules.get_terrain_names()
	for id: int in grid._names.size():
		grid._id_by_name[grid._names[id]] = id
	grid.base_profile = TerrainCostProfile.create(rules)

	grid.height = rows.size()
	grid.width = rows[0].size() if grid.height > 0 else 0
	grid._terrain_ids.resize(grid.width * grid.height)
	for y: int in grid.height:
		assert(rows[y].size() == grid.width, "TerrainGrid: row %d has the wrong length" % y)
		for x: int in grid.width:
			grid.set_terrain(Vector2i(x, y), rows[y][x])
	return grid


## Convenience: a cost profile for these terrain genes, e.g. {"climber": 0.8}.
func make_profile(genes: Dictionary[String, float], label: String = "") -> TerrainCostProfile:
	return TerrainCostProfile.create(_rules, genes, label if label != "" else str(genes))


func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < width and cell.y < height


## Terrain name of the cell, or "" outside the map / unknown terrain.
func get_terrain(cell: Vector2i) -> String:
	if not in_bounds(cell):
		return ""
	var id: int = _terrain_ids[_index(cell)]
	return _names[id] if id >= 0 else ""


## Changes one cell at runtime (later: fire, broken fences, barricades).
func set_terrain(cell: Vector2i, terrain: String) -> void:
	assert(in_bounds(cell), "TerrainGrid: set_terrain outside the map %s" % cell)
	if not _id_by_name.has(terrain):
		push_warning("TerrainGrid: unknown terrain '%s' at %s, treated as impassable" % [terrain, cell])
	_terrain_ids[_index(cell)] = _id_by_name.get(terrain, -1)


## Cost of stepping into this cell. INF = cannot enter (wall, house, outside the map).
func get_cost(cell: Vector2i, profile: TerrainCostProfile = null) -> float:
	if not in_bounds(cell):
		return INF
	return _profile_or_base(profile).cost_of_id(_terrain_ids[_index(cell)])


func is_walkable(cell: Vector2i, profile: TerrainCostProfile = null) -> bool:
	return get_cost(cell, profile) < INF


## Walkable cells next to `cell`. With diagonals on, a diagonal step is only allowed when
## both straight cells beside it are walkable, so units never cut through a wall corner.
func get_neighbors(cell: Vector2i, allow_diagonal: bool = true, profile: TerrainCostProfile = null) -> Array[Vector2i]:
	var p: TerrainCostProfile = _profile_or_base(profile)
	var result: Array[Vector2i] = []
	for dir: Vector2i in STRAIGHT_DIRS:
		if is_walkable(cell + dir, p):
			result.append(cell + dir)
	if allow_diagonal:
		for dir: Vector2i in DIAGONAL_DIRS:
			var side_a: Vector2i = cell + Vector2i(dir.x, 0)
			var side_b: Vector2i = cell + Vector2i(0, dir.y)
			if is_walkable(cell + dir, p) and is_walkable(side_a, p) and is_walkable(side_b, p):
				result.append(cell + dir)
	return result


## Edge cost for search algorithms: cost of entering `to`, times sqrt(2) for a diagonal step.
## Assumes `to` is a neighbour of `from` (from get_neighbors).
func get_step_cost(from: Vector2i, to: Vector2i, profile: TerrainCostProfile = null) -> float:
	var cost: float = get_cost(to, profile)
	if from.x != to.x and from.y != to.y:
		cost *= DIAGONAL_FACTOR
	return cost


func _profile_or_base(profile: TerrainCostProfile) -> TerrainCostProfile:
	if profile == null:
		return base_profile
	assert(profile.source == _rules, "TerrainGrid: profile was built from different TerrainCosts")
	return profile


func _index(cell: Vector2i) -> int:
	return cell.y * width + cell.x

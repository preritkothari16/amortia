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
## Terrain id -> 1 if it blocks line of sight.
var _blocks_vision_by_id: PackedByteArray = PackedByteArray()


## Builds a grid from terrain names row by row (rows[y][x]), e.g. ZoneMap.get_terrain_rows().
static func from_rows(rows: Array[PackedStringArray], rules: TerrainCosts, grid_coords: GridCoords = null) -> TerrainGrid:
	var grid: TerrainGrid = TerrainGrid.new()
	grid._rules = rules
	grid.coords = grid_coords if grid_coords != null else GridCoords.new()
	grid._names = rules.get_terrain_names()
	for id: int in grid._names.size():
		grid._id_by_name[grid._names[id]] = id
	grid.base_profile = TerrainCostProfile.create(rules)
	grid._blocks_vision_by_id.resize(grid._names.size())
	for id: int in grid._names.size():
		grid._blocks_vision_by_id[id] = 1 if rules.blocks_vision.has(grid._names[id]) else 0

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


## Every cell's cost in one flat array (index = y * width + x), for hot loops such as the
## flow field that would be slowed down by calling get_cost per neighbour.
func build_cost_array(profile: TerrainCostProfile = null) -> PackedFloat32Array:
	var p: TerrainCostProfile = _profile_or_base(profile)
	var costs: PackedFloat32Array = PackedFloat32Array()
	costs.resize(_terrain_ids.size())
	for i: int in _terrain_ids.size():
		costs[i] = p.cost_of_id(_terrain_ids[i])
	return costs


## True if this cell blocks line of sight (vision-blocking terrain, unknown terrain, off the map).
func blocks_vision(cell: Vector2i) -> bool:
	if not in_bounds(cell):
		return true
	var id: int = _terrain_ids[_index(cell)]
	return id < 0 or _blocks_vision_by_id[id] == 1


## Line of sight between two world positions over the grid. Walks every cell the straight
## line passes through (Amanatides & Woo grid traversal) and fails on the first cell that
## blocks vision. The start cell is ignored (you can always see out of your own tile).
func has_line_of_sight(from_world: Vector2, to_world: Vector2) -> bool:
	var tile: float = float(coords.tile_size)
	var a: Vector2 = (from_world - coords.origin) / tile  # positions in cell units
	var b: Vector2 = (to_world - coords.origin) / tile
	var cell: Vector2i = Vector2i(floori(a.x), floori(a.y))
	var end: Vector2i = Vector2i(floori(b.x), floori(b.y))
	var dir: Vector2 = b - a
	var step: Vector2i = Vector2i(signi(int(signf(dir.x))), signi(int(signf(dir.y))))
	# t_max: how far along the line (0..1) until the next vertical / horizontal cell border.
	# t_delta: how far along the line one whole cell is, in x and in y.
	var t_max: Vector2 = Vector2(INF, INF)
	var t_delta: Vector2 = Vector2(INF, INF)
	if dir.x != 0.0:
		var next_x: float = cell.x + (1 if step.x > 0 else 0)
		t_max.x = (next_x - a.x) / dir.x
		t_delta.x = absf(1.0 / dir.x)
	if dir.y != 0.0:
		var next_y: float = cell.y + (1 if step.y > 0 else 0)
		t_max.y = (next_y - a.y) / dir.y
		t_delta.y = absf(1.0 / dir.y)
	while cell != end:
		# Step into whichever neighbouring cell the line reaches first.
		if t_max.x < t_max.y:
			cell.x += step.x
			t_max.x += t_delta.x
		else:
			cell.y += step.y
			t_max.y += t_delta.y
		if blocks_vision(cell):
			return false
		if t_max.x > 1.0 and t_max.y > 1.0 and cell != end:
			break  # numerical safety: the line has ended
	return true


func _profile_or_base(profile: TerrainCostProfile) -> TerrainCostProfile:
	if profile == null:
		return base_profile
	assert(profile.source == _rules, "TerrainGrid: profile was built from different TerrainCosts")
	return profile


func _index(cell: Vector2i) -> int:
	return cell.y * width + cell.x

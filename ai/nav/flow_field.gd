class_name FlowField
extends RefCounted
## Shared flow field (GDD 6.2): one Dijkstra / Uniform Cost Search outward from the target
## (the player's cell) gives every tile on the map
##   - its integration cost: total cost of the cheapest walk from that tile to the target
##   - its next cell: the neighbour to step into to follow that cheapest walk
## Any number of enemies then just read the arrow under their feet - no per-enemy search.
##
## The search runs backwards (from the target) but enemies walk forwards, so when the
## search reaches tile A from tile B it pays get_step_cost(A -> B): the cost of ENTERING B.
##
## Speed: the field is rebuilt every time the player enters a new tile, so build() works on
## flat integer indices and a precomputed cost array instead of calling
## TerrainGrid.get_neighbors() (which allocates an array per call). The neighbour rules are
## the same as TerrainGrid's; tests check the result matches A* from every cell.

const SQRT2: float = 1.41421356
## The 8 neighbour offsets: 4 straight, then 4 diagonal.
const OFFSETS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1),
]

var grid: TerrainGrid
## Cell the field leads to. Only valid after build().
var target: Vector2i = Vector2i.ZERO
## Whose terrain costs the field was built with.
var profile: TerrainCostProfile
## Cells finalised by the last build (for stats / experiment N1).
var last_expanded: int = 0

## Per cell (index = y * width + x): integration cost (INF = cannot reach the target)...
var _cost: PackedFloat32Array = PackedFloat32Array()
## ...and the index of the next cell to step into (-1 = none: target or unreachable).
var _next: PackedInt32Array = PackedInt32Array()
var _built: bool = false


func _init(terrain_grid: TerrainGrid) -> void:
	grid = terrain_grid


## Runs Dijkstra from `target_cell` over the whole grid. Call again when the target moves
## to a new cell or the terrain changes.
func build(target_cell: Vector2i, cost_profile: TerrainCostProfile = null) -> void:
	target = target_cell
	profile = cost_profile if cost_profile != null else grid.base_profile
	last_expanded = 0
	var cell_count: int = grid.width * grid.height
	_cost.resize(cell_count)
	_cost.fill(INF)
	_next.resize(cell_count)
	_next.fill(-1)
	_built = true
	if not grid.is_walkable(target, profile):
		return  # the target is inside a wall: nothing can reach it

	var w: int = grid.width
	var h: int = grid.height
	var tile_cost: PackedFloat32Array = grid.build_cost_array(profile)  # INF = wall
	var done: PackedByteArray = PackedByteArray()
	done.resize(cell_count)  # all 0 = not finalised yet
	var open: MinHeap = MinHeap.new()  # holds cell indices
	var target_index: int = _index(target)
	_cost[target_index] = 0.0
	open.push(target_index, 0.0)

	while not open.is_empty():
		var b: int = open.pop()
		if done[b] == 1:
			continue  # stale entry: b was already finalised with a cheaper cost
		done[b] = 1
		last_expanded += 1
		var bx: int = b % w
		var by: int = b / w

		# Every walkable neighbour a of b could step into b.
		for offset: Vector2i in OFFSETS:
			var ax: int = bx + offset.x
			var ay: int = by + offset.y
			if ax < 0 or ay < 0 or ax >= w or ay >= h:
				continue
			var a: int = ay * w + ax
			if done[a] == 1 or tile_cost[a] == INF:
				continue
			var step: float = tile_cost[b]  # stepping from a into b pays b's terrain cost
			if offset.x != 0 and offset.y != 0:
				# Diagonal: no corner cutting, both cells beside the step must be walkable.
				if tile_cost[by * w + ax] == INF or tile_cost[ay * w + bx] == INF:
					continue
				step *= SQRT2
			var new_cost: float = _cost[b] + step
			if new_cost < _cost[a]:
				_cost[a] = new_cost
				_next[a] = b  # a's arrow points at b
				open.push(a, new_cost)


func is_built() -> bool:
	return _built


## Total cost from `cell` to the target. INF if unreachable, a wall, or outside the map.
func get_cost(cell: Vector2i) -> float:
	if not _built or not grid.in_bounds(cell):
		return INF
	return _cost[_index(cell)]


func is_reachable(cell: Vector2i) -> bool:
	return get_cost(cell) < INF


## The neighbour to step into from `cell`. Returns `cell` itself at the target or when
## there is no way to the target (check is_reachable to tell these apart).
func get_next_cell(cell: Vector2i) -> Vector2i:
	if not _built or not grid.in_bounds(cell):
		return cell
	var next_index: int = _next[_index(cell)]
	if next_index < 0:
		return cell
	return Vector2i(next_index % grid.width, next_index / grid.width)


## Unit vector from `cell` towards its next cell. ZERO at the target or if unreachable.
func get_direction(cell: Vector2i) -> Vector2:
	return Vector2(get_next_cell(cell) - cell).normalized()


## Same as get_direction, for a world position (what an enemy will call each frame).
func get_direction_at(world_pos: Vector2) -> Vector2:
	return get_direction(grid.coords.world_to_cell(world_pos))


## The cells you visit by following the arrows from `cell` to the target, both included.
## Empty if `cell` cannot reach the target. Mainly for tests and debugging.
func get_path_from(cell: Vector2i) -> Array[Vector2i]:
	if not is_reachable(cell):
		return []
	var path: Array[Vector2i] = [cell]
	while path[-1] != target:
		path.append(get_next_cell(path[-1]))
		assert(path.size() <= grid.width * grid.height, "FlowField: arrows form a loop")
	return path


func _index(cell: Vector2i) -> int:
	return cell.y * grid.width + cell.x

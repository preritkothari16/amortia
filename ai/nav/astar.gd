class_name AStar
extends RefCounted
## Hand-written A* search over a TerrainGrid (GDD 6.4). Finds the cheapest path between two
## cells, counting terrain costs, with 8-way movement and an octile heuristic.
##
## Each cell n is ranked by f(n) = g(n) + h(n):
##   g(n) = cheapest known cost from the start to n
##   h(n) = octile estimate of the cost from n to the goal (never too high, so the path is optimal)
## The open list is a MinHeap ordered by f. Instead of updating a cell already in the heap,
## a cheaper route pushes it again; the old entry is skipped when popped ("lazy deletion").

## sqrt(2) - 2: turns a straight step into a diagonal one in the octile formula.
const OCTILE_DIAGONAL_EXTRA: float = 1.41421356 - 2.0

var grid: TerrainGrid

## Stats from the last find_path call, for debugging and experiment N2.
## Cost of the returned path (INF if none was found).
var last_cost: float = INF
## How many cells were taken off the open list and expanded.
var last_expanded: int = 0


func _init(terrain_grid: TerrainGrid) -> void:
	grid = terrain_grid


## Cheapest path from start to goal as grid cells, both ends included.
## Returns [] when there is no path (blocked start/goal, or the goal is walled off).
## `profile` = whose terrain costs to use (null = the grid's base profile).
func find_path(start: Vector2i, goal: Vector2i, profile: TerrainCostProfile = null) -> Array[Vector2i]:
	last_cost = INF
	last_expanded = 0
	if profile == null:
		profile = grid.base_profile
	if not grid.is_walkable(start, profile) or not grid.is_walkable(goal, profile):
		return []

	var min_cost: float = profile.get_min_cost()
	var g_cost: Dictionary[Vector2i, float] = {start: 0.0}
	var came_from: Dictionary[Vector2i, Vector2i] = {}
	var closed: Dictionary[Vector2i, bool] = {}
	var open: MinHeap = MinHeap.new()
	open.push(start, octile(start, goal) * min_cost)

	while not open.is_empty():
		var current: Vector2i = open.pop()
		if closed.has(current):
			continue  # stale entry: this cell was already expanded via a cheaper route
		if current == goal:
			last_cost = g_cost[goal]
			return _rebuild_path(came_from, goal)
		closed[current] = true
		last_expanded += 1

		for next: Vector2i in grid.get_neighbors(current, true, profile):
			if closed.has(next):
				continue
			var new_g: float = g_cost[current] + grid.get_step_cost(current, next, profile)
			if not g_cost.has(next) or new_g < g_cost[next]:
				g_cost[next] = new_g
				came_from[next] = current
				open.push(next, new_g + octile(next, goal) * min_cost)

	return []  # open list ran out: the goal cannot be reached


## Octile distance: cost of the shortest 8-way walk on open ground with step cost 1.
## Take min(dx, dy) diagonal steps (sqrt 2 each), then straight steps for the rest.
static func octile(a: Vector2i, b: Vector2i) -> float:
	var dx: int = absi(a.x - b.x)
	var dy: int = absi(a.y - b.y)
	return (dx + dy) + OCTILE_DIAGONAL_EXTRA * mini(dx, dy)


## Walk the came_from links back from the goal, then reverse so the path runs start -> goal.
func _rebuild_path(came_from: Dictionary[Vector2i, Vector2i], goal: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = [goal]
	var cell: Vector2i = goal
	while came_from.has(cell):
		cell = came_from[cell]
		path.append(cell)
	path.reverse()
	return path

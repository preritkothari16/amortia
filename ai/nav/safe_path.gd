class_name SafePath
extends RefCounted
## Threat-aware A* for the Escort survivor (Reactive Survival V1). Same walking rules as the
## player (no fences, no water; the exit gate counts as walkable because it opens), 4-way steps.
##
## Every step into a cell costs 1 plus a danger penalty from the enemies the survivor knows about:
##   step_cost(c) = 1 + threat_weight * danger(c)
##   danger(c)    = sum over threats t of max(0, 1 - dist(c, t) / threat_radius_cells)
## so a cell next to an enemy costs a lot, a cell threat_radius_cells away costs nothing extra.
## With no threats this is a plain shortest walk. With threats it detours when a detour exists,
## and when none does it still goes through - as little as possible (never "no path" because of
## danger alone).
## Heuristic: Manhattan distance. Every step costs at least 1, so it never overestimates and the
## path is the cheapest one. Open list = MinHeap with lazy deletion, like AStar.

## Danger reach of one enemy, in cells.
var threat_radius_cells: float = 4.0
## How many extra steps a cell right next to an enemy is worth.
var threat_weight: float = 8.0

## Stats from the last find() call (debugging, tests).
var last_cost: float = INF
var last_expanded: int = 0

const STEPS: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.UP, Vector2i.LEFT]


## Danger of `cell` from `threats` (enemy cells), 0 = safe.
static func danger(cell: Vector2i, threats: Array[Vector2i], radius_cells: float) -> float:
	var total: float = 0.0
	if radius_cells <= 0.0:
		return total
	for t: Vector2i in threats:
		total += maxf(0.0, 1.0 - Vector2(cell - t).length() / radius_cells)
	return total


## Can the survivor stand on `cell`? (player rules, gate allowed)
static func walkable(grid: TerrainGrid, cell: Vector2i) -> bool:
	var t: TerrainDefinition = grid.get_definition(cell)
	return t != null and (t.player_passable or t.id == "gate")


## Cheapest walk from start to goal, both ends included. [] if the goal can't be reached.
func find(grid: TerrainGrid, start: Vector2i, goal: Vector2i, threats: Array[Vector2i]) -> Array[Vector2i]:
	last_cost = INF
	last_expanded = 0
	if not walkable(grid, start) or not walkable(grid, goal):
		return []
	var g_cost: Dictionary[Vector2i, float] = {start: 0.0}
	var came_from: Dictionary[Vector2i, Vector2i] = {}
	var closed: Dictionary[Vector2i, bool] = {}
	var open: MinHeap = MinHeap.new()
	open.push(start, _manhattan(start, goal))
	while not open.is_empty():
		var current: Vector2i = open.pop()
		if closed.has(current):
			continue  # stale entry, already expanded more cheaply
		if current == goal:
			last_cost = g_cost[goal]
			return _rebuild(came_from, goal)
		closed[current] = true
		last_expanded += 1
		for step: Vector2i in STEPS:
			var next: Vector2i = current + step
			if closed.has(next) or not walkable(grid, next):
				continue
			var new_g: float = g_cost[current] + 1.0 + threat_weight * danger(next, threats, threat_radius_cells)
			if not g_cost.has(next) or new_g < g_cost[next]:
				g_cost[next] = new_g
				came_from[next] = current
				open.push(next, new_g + _manhattan(next, goal))
	return []


static func _manhattan(a: Vector2i, b: Vector2i) -> float:
	return absi(a.x - b.x) + absi(a.y - b.y)


func _rebuild(came_from: Dictionary[Vector2i, Vector2i], goal: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = [goal]
	var cell: Vector2i = goal
	while came_from.has(cell):
		cell = came_from[cell]
		path.append(cell)
	path.reverse()
	return path

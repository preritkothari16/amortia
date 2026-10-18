class_name CoverFinder
extends RefCounted
## Where should a threatened Escort survivor hide? (Reactive Survival V2)
##
## A cell is COVER when every threat (enemy the survivor can see) has no line of sight to it, or
## it is concealing terrain (tall grass hides you beyond 2 tiles, GDD 4.3). It is only worth
## running to if:
##   - no threat is closer to it than min_threat_gap_cells (else the 2-tile rule spots you anyway)
##   - the survivor gets there before any threat could: walking time along the route versus the
##     threat's straight-line time (optimistic for the threat, so we stay on the safe side):
##         steps * tile / mover_speed  <  distance(cell, threat) * tile / threat_speed - margin
##
## Search: Dijkstra from the survivor's cell with SafePath's step cost (1 + danger), so routes that
## brush past enemies are expensive. Only cells within max_steps steps are explored.
## Choice: the reachable cover cell with the lowest
##         route cost + player_weight * distance(cell, player)
## i.e. cheap and safe to reach, and near the player who can protect it.
## Returns NONE when there is no such cell; last_path then is [].

const NONE: Vector2i = Vector2i(-9999, -9999)
const STEPS: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.UP, Vector2i.LEFT]

## Furthest the search goes, in steps.
var max_steps: int = 8
## A cover cell must be at least this far (cells, straight line) from every threat.
var min_threat_gap_cells: float = 3.0
## Survivor speed while taking cover / assumed enemy speed (px/s).
var mover_speed: float = 72.0
var threat_speed: float = 70.0
## The survivor must arrive this many seconds before the fastest threat could.
var margin_seconds: float = 0.3
## Cost of every cell of distance between the cover and the player.
var player_weight: float = 0.5
## Danger shape (same meaning as SafePath's).
var threat_radius_cells: float = 4.0
var threat_weight: float = 8.0
## False = tall grass does not count (a running survivor is not hidden by it).
var grass_counts: bool = true

## Results of the last find(): route to the chosen cell (start included) and cells expanded.
var last_path: Array[Vector2i] = []
var last_expanded: int = 0


## Best cover cell for a survivor at `from` hiding from `threats` (enemy cells), or NONE.
func find(grid: TerrainGrid, from: Vector2i, threats: Array[Vector2i], player: Vector2i) -> Vector2i:
	last_path = []
	last_expanded = 0
	if not SafePath.walkable(grid, from):
		return NONE
	var tile: float = float(grid.coords.tile_size)
	# Dijkstra: cost[c] = cheapest danger-weighted route, steps[c] = its length in steps.
	var cost: Dictionary[Vector2i, float] = {from: 0.0}
	var steps: Dictionary[Vector2i, int] = {from: 0}
	var came_from: Dictionary[Vector2i, Vector2i] = {}
	var closed: Dictionary[Vector2i, bool] = {}
	var open: MinHeap = MinHeap.new()
	open.push(from, 0.0)
	var best: Vector2i = NONE
	var best_score: float = INF
	while not open.is_empty():
		var c: Vector2i = open.pop()
		if closed.has(c):
			continue  # stale heap entry
		closed[c] = true
		last_expanded += 1
		# Is c a hiding place we can reach in time? Keep the best one.
		if _is_cover(grid, c, threats) and _reach_first(c, steps[c], threats, tile):
			var score: float = cost[c] + player_weight * Vector2(c - player).length()
			if score < best_score:
				best_score = score
				best = c
		if steps[c] >= max_steps:
			continue  # far enough: don't look further from here
		for d: Vector2i in STEPS:
			var n: Vector2i = c + d
			if closed.has(n) or not SafePath.walkable(grid, n):
				continue
			var new_cost: float = cost[c] + 1.0 + threat_weight * SafePath.danger(n, threats, threat_radius_cells)
			if not cost.has(n) or new_cost < cost[n]:
				cost[n] = new_cost
				steps[n] = steps[c] + 1
				came_from[n] = c
				open.push(n, new_cost)
	if best != NONE:
		last_path = _rebuild(came_from, best)
	return best


## Hidden from every threat at `cell`: concealing terrain, or no threat has a clear line to it.
## Never closer than min_threat_gap_cells to a threat.
func _is_cover(grid: TerrainGrid, cell: Vector2i, threats: Array[Vector2i]) -> bool:
	for t: Vector2i in threats:
		if Vector2(cell - t).length() < min_threat_gap_cells:
			return false
	if grass_counts and grid.conceals(cell):
		return true
	var at: Vector2 = grid.coords.cell_to_world(cell)
	for t: Vector2i in threats:
		if grid.has_line_of_sight(grid.coords.cell_to_world(t), at):
			return false
	return true


## True if the survivor (route of `step_count` steps) gets to `cell` margin_seconds before any
## threat walking straight there.
func _reach_first(cell: Vector2i, step_count: int, threats: Array[Vector2i], tile: float) -> bool:
	var my_time: float = step_count * tile / mover_speed
	for t: Vector2i in threats:
		var their_time: float = Vector2(cell - t).length() * tile / threat_speed
		if my_time >= their_time - margin_seconds:
			return false
	return true


func _rebuild(came_from: Dictionary[Vector2i, Vector2i], goal: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = [goal]
	var cell: Vector2i = goal
	while came_from.has(cell):
		cell = came_from[cell]
		path.append(cell)
	path.reverse()
	return path

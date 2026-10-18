class_name ObjectiveFairness
extends RefCounted
## Fairness check for generated Stealth and Escort areas (Reactive Survival V1). It never
## changes how enemies work; a layout that fails is simply regenerated from the next seed
## (GeneratedArea.build_scene). Questions, all on the plain grid:
##   1. reachable   is there a walk (player rules) from the entry to the exit?
##   2. cover       share of that shortest walk with tall grass or a sight blocker within
##                  cover_radius_cells - somewhere to break line of sight on the way
##   3. stealth     on the least-exposed walk (Dijkstra, step cost 1 + exposure_penalty x the
##                  number of spawn markers that would see the cell), how many different spawn
##                  markers watch it? Watchers are worst case: all-round vision, by day, best
##                  vision gene. Tall grass hides the cell.
## Result: {ok, reasons: PackedStringArray, route_length, cover_ratio, watching_spawns, exposed_cells}.

const STEPS: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.UP, Vector2i.LEFT]


static func check(grid: TerrainGrid, entry: Vector2i, exit: Vector2i, spawns: Array[Vector2i], stealth: bool,
		settings: ObjectiveFairnessSettings) -> Dictionary:
	var result: Dictionary = {"ok": true, "reasons": PackedStringArray(), "route_length": 0,
			"cover_ratio": 0.0, "watching_spawns": 0, "exposed_cells": 0}
	var route: Array[Vector2i] = SafePath.new().find(grid, entry, exit, [])
	if route.is_empty():
		result["ok"] = false
		result["reasons"].append("exit unreachable")
		return result
	result["route_length"] = route.size()
	result["cover_ratio"] = cover_ratio(grid, route, settings.cover_radius_cells)
	if result["cover_ratio"] < settings.min_cover_ratio:
		result["ok"] = false
		result["reasons"].append("too little cover (%.2f)" % result["cover_ratio"])
	if stealth:
		var exposure: Dictionary = least_exposed_route(grid, entry, exit, spawns, settings)
		result["watching_spawns"] = exposure["watchers"]
		result["exposed_cells"] = exposure["exposed_cells"]
		if exposure["watchers"] > settings.max_watching_spawns:
			result["ok"] = false
			result["reasons"].append("route overwatched by %d spawns" % exposure["watchers"])
	return result


## Share of `route` cells with a concealing or sight-blocking cell within `radius` (Chebyshev).
static func cover_ratio(grid: TerrainGrid, route: Array[Vector2i], radius: int) -> float:
	if route.is_empty():
		return 0.0
	var covered: int = 0
	for c: Vector2i in route:
		if _near_cover(grid, c, radius):
			covered += 1
	return float(covered) / route.size()


static func _near_cover(grid: TerrainGrid, cell: Vector2i, radius: int) -> bool:
	for dy: int in range(-radius, radius + 1):
		for dx: int in range(-radius, radius + 1):
			var n: Vector2i = cell + Vector2i(dx, dy)
			if grid.in_bounds(n) and (grid.conceals(n) or grid.blocks_vision(n)):
				return true
	return false


## Indices of the spawns that would see `cell` (worst case, see the class comment).
static func watchers_of(grid: TerrainGrid, cell: Vector2i, spawns: Array[Vector2i], range_px: float) -> Array[int]:
	var who: Array[int] = []
	if grid.conceals(cell):
		return who
	var at: Vector2 = grid.coords.cell_to_world(cell)
	for i: int in spawns.size():
		var from: Vector2 = grid.coords.cell_to_world(spawns[i])
		if from.distance_to(at) <= range_px and grid.has_line_of_sight(from, at):
			who.append(i)
	return who


## Dijkstra from entry to exit with step cost 1 + exposure_penalty x watchers(cell).
## Returns {watchers: distinct spawns seeing the route, exposed_cells, path}.
static func least_exposed_route(grid: TerrainGrid, entry: Vector2i, exit: Vector2i, spawns: Array[Vector2i],
		settings: ObjectiveFairnessSettings) -> Dictionary:
	var seen_by: Dictionary[Vector2i, Array] = {}
	var dist: Dictionary[Vector2i, float] = {entry: 0.0}
	var came: Dictionary[Vector2i, Vector2i] = {}
	var closed: Dictionary[Vector2i, bool] = {}
	var open: MinHeap = MinHeap.new()
	open.push(entry, 0.0)
	while not open.is_empty():
		var c: Vector2i = open.pop()
		if closed.has(c):
			continue
		closed[c] = true
		if c == exit:
			break
		for step: Vector2i in STEPS:
			var n: Vector2i = c + step
			if closed.has(n) or not SafePath.walkable(grid, n):
				continue
			if not seen_by.has(n):
				seen_by[n] = watchers_of(grid, n, spawns, settings.watch_range_px)
			var nd: float = dist[c] + 1.0 + settings.exposure_penalty * (seen_by[n] as Array).size()
			if nd < dist.get(n, INF):
				dist[n] = nd
				came[n] = c
				open.push(n, nd)
	if not closed.has(exit):
		return {"watchers": spawns.size(), "exposed_cells": -1, "path": [] as Array[Vector2i]}
	var path: Array[Vector2i] = [exit]
	while came.has(path[0]):
		path.push_front(came[path[0]])
	var distinct: Dictionary[int, bool] = {}
	var exposed: int = 0
	for c: Vector2i in path:
		var who: Array = seen_by.get(c, [])
		if not who.is_empty():
			exposed += 1
		for i: int in who:
			distinct[i] = true
	return {"watchers": distinct.size(), "exposed_cells": exposed, "path": path}

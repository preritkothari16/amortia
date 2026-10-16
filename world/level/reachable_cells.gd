class_name ReachableCells
extends RefCounted
## Cells the PLAYER can walk to from a start cell (4-way breadth-first search over player-passable
## terrain, gates count as open), minus hazards and overlays. Used to place things the player must be
## able to reach: blueprints and power-ups. Deterministic: the result is in search order.


## All reachable, safe cells (start included), nearest first.
static func from(grid: TerrainGrid, start: Vector2i) -> Array[Vector2i]:
	var seen: Dictionary[Vector2i, bool] = {start: true}
	var queue: Array[Vector2i] = [start]
	var out: Array[Vector2i] = []
	var head: int = 0
	while head < queue.size():
		var c: Vector2i = queue[head]
		head += 1
		if _is_safe(grid, c):
			out.append(c)
		for d: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]:
			var n: Vector2i = c + d
			if seen.has(n):
				continue
			var def: TerrainDefinition = grid.get_definition(n)
			if def != null and (def.player_passable or def.id == "gate"):
				seen[n] = true
				queue.append(n)
	return out


## The subset at least `min_cells` (straight-line cells) from `origin`.
static func farther_than(cells: Array[Vector2i], origin: Vector2i, min_cells: float) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for c: Vector2i in cells:
		if Vector2(c - origin).length() >= min_cells:
			out.append(c)
	return out


static func _is_safe(grid: TerrainGrid, cell: Vector2i) -> bool:
	var def: TerrainDefinition = grid.get_definition(cell)
	if def == null or not def.player_passable or def.hazard != TerrainDefinition.Hazard.NONE:
		return false
	return grid.get_overlay(cell) == ""

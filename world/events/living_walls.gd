class_name LivingWalls
extends TerrainEvent
## Living walls (GDD 4.4, zone 4): every grow_interval the next candidate cell is warned for
## warning_seconds, then grows into "living_wall" (solid, blocks vision, impassable).
##   - candidate_cells: where walls may grow (empty = every walkable cell next to a wall or
##     living wall that is in a 1-tile corridor), visited in a seeded random order
##   - a growth that would cut any protected cell off from the others (player-walkable BFS)
##     is skipped for good: objectives, entry and exit can't be softlocked
##   - an occupied cell waits until it is free

@export var grow_interval: float = 12.0
@export var warning_seconds: float = 2.0
@export var candidate_cells: Array[Vector2i] = []
## Cells that must stay connected to each other (player spawn, exit, objective...).
@export var protected_cells: Array[Vector2i] = []
## 0 = no limit.
@export var max_walls: int = 12

var grown: Array[Vector2i] = []
var _order: Array[Vector2i] = []
var _next_left: float = 0.0


func _on_reset() -> void:
	grown.clear()
	_order.clear()
	_next_left = grow_interval
	warning_color = Color(0.85, 0.3, 0.5)


func _on_start() -> void:
	_order = candidate_cells.duplicate() if not candidate_cells.is_empty() else _corridor_cells()
	# Seeded Fisher-Yates shuffle.
	for i: int in range(_order.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: Vector2i = _order[i]
		_order[i] = _order[j]
		_order[j] = tmp


func _on_tick(delta: float) -> void:
	for cell: Vector2i in _due_warnings(delta):
		if is_occupied.call(cell):
			warnings[cell] = 0.05
			continue
		warnings.erase(cell)
		if would_disconnect(cell):
			continue
		grid.set_terrain(cell, "living_wall")
		grown.append(cell)
	if max_walls > 0 and grown.size() + warnings.size() >= max_walls:
		return
	_next_left -= delta
	if _next_left > 0.0:
		return
	_next_left = grow_interval
	while not _order.is_empty():
		var cell: Vector2i = _order.pop_front()
		if grid.is_walkable(cell) and not would_disconnect(cell):
			warnings[cell] = warning_seconds
			return


## True if turning `cell` solid would leave a protected cell unreachable from the first one
## (breadth-first search over cells the player can walk on).
func would_disconnect(cell: Vector2i) -> bool:
	if protected_cells.has(cell):
		return true
	if protected_cells.size() < 2:
		return false
	var start: Vector2i = protected_cells[0]
	var seen: Dictionary[Vector2i, bool] = {start: true}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		for n: Vector2i in _neighbours4(c):
			if n == cell or seen.has(n):
				continue
			var d: TerrainDefinition = grid.get_definition(n)
			if d == null or not d.player_passable:
				continue
			seen[n] = true
			queue.append(n)
	for p: Vector2i in protected_cells:
		if not seen.has(p):
			return true
	return false


## Walkable cells squeezed between two solid cells (left/right or up/down): corridor cells.
func _corridor_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y: int in grid.height:
		for x: int in grid.width:
			var c: Vector2i = Vector2i(x, y)
			if not grid.is_walkable(c):
				continue
			var lr: bool = not grid.is_walkable(c + Vector2i.LEFT) and not grid.is_walkable(c + Vector2i.RIGHT)
			var ud: bool = not grid.is_walkable(c + Vector2i.UP) and not grid.is_walkable(c + Vector2i.DOWN)
			if lr or ud:
				cells.append(c)
	return cells


func status_text() -> String:
	return "The walls are growing..." if not warnings.is_empty() else ""

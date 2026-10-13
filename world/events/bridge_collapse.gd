class_name BridgeCollapse
extends TerrainEvent
## Bridges (GDD 4.4, zone 2). A bridge is a connected group of "bridge" cells. Every time a
## unit LEAVES a bridge cell the group's crossing count goes up; at crossings_to_collapse - or
## when explode() hits it - the whole group is warned for warning_seconds, then each cell
## turns into deep_water (impassable for walkers, cost 2 for swimmers). A cell with a unit on
## it waits until it is free, so nobody ends up inside water collision.

@export var crossings_to_collapse: int = 8
@export var warning_seconds: float = 1.5

## Group index -> crossings so far; cell -> group index.
var crossings: Array[int] = []
var group_of: Dictionary[Vector2i, int] = {}
## Cells that were occupied last tick (to count leaving).
var _occupied_before: Dictionary[Vector2i, bool] = {}
## Groups already collapsing.
var _collapsing: Dictionary[int, bool] = {}


func _on_reset() -> void:
	crossings.clear()
	group_of.clear()
	_occupied_before.clear()
	_collapsing.clear()
	warning_color = Color(1, 0.35, 0.2)


func _on_start() -> void:
	# Flood-fill bridge cells into groups.
	for cell: Vector2i in _cells_of("bridge"):
		if group_of.has(cell):
			continue
		var index: int = crossings.size()
		crossings.append(0)
		var stack: Array[Vector2i] = [cell]
		group_of[cell] = index
		while not stack.is_empty():
			var c: Vector2i = stack.pop_back()
			for n: Vector2i in _neighbours4(c):
				if not group_of.has(n) and grid.get_terrain(n) == "bridge":
					group_of[n] = index
					stack.append(n)


## An explosion at `cell`: collapses the bridge group it hits.
func explode(cell: Vector2i) -> void:
	if group_of.has(cell):
		_start_collapse(group_of[cell])


func _on_tick(delta: float) -> void:
	# Count crossings: a bridge cell that was occupied and isn't any more.
	for cell: Vector2i in group_of:
		var now: bool = is_occupied.call(cell)
		if _occupied_before.get(cell, false) and not now and grid.get_terrain(cell) == "bridge":
			var g: int = group_of[cell]
			crossings[g] += 1
			if crossings[g] >= crossings_to_collapse:
				_start_collapse(g)
		_occupied_before[cell] = now
	for cell: Vector2i in _due_warnings(delta):
		if is_occupied.call(cell):
			warnings[cell] = 0.05  # wait for the unit to step off
			continue
		warnings.erase(cell)
		grid.set_terrain(cell, "deep_water")


func _start_collapse(g: int) -> void:
	if _collapsing.has(g):
		return
	_collapsing[g] = true
	for cell: Vector2i in group_of:
		if group_of[cell] == g and grid.get_terrain(cell) == "bridge":
			warnings[cell] = warning_seconds


func status_text() -> String:
	return "Bridge collapsing!" if not warnings.is_empty() else ""

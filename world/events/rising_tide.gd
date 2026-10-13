class_name RisingTide
extends TerrainEvent
## Rising tide (GDD 4.4, zone 2): every interval_seconds the shallow water next to deep water is
## warned for warning_seconds and then turns deep - the map shrinks from the water's edge.
## Occupied cells wait until the unit leaves (never traps anyone inside water collision).
## Stops after max_stages rises (0 = no limit).

@export var interval_seconds: float = 20.0
@export var warning_seconds: float = 2.0
@export var max_stages: int = 4

var stages_done: int = 0
var _next_left: float = 0.0


func _on_reset() -> void:
	stages_done = 0
	_next_left = interval_seconds
	warning_color = Color(0.3, 0.6, 1.0)


func _on_tick(delta: float) -> void:
	for cell: Vector2i in _due_warnings(delta):
		if is_occupied.call(cell):
			warnings[cell] = 0.05
			continue
		warnings.erase(cell)
		if grid.get_terrain(cell) == "shallow_water":
			grid.set_terrain(cell, "deep_water")
	if max_stages > 0 and stages_done >= max_stages:
		return
	_next_left -= delta
	if _next_left > 0.0:
		return
	_next_left = interval_seconds
	stages_done += 1
	for cell: Vector2i in _cells_of("shallow_water"):
		for n: Vector2i in _neighbours4(cell):
			if grid.get_terrain(n) == "deep_water":
				warnings[cell] = warning_seconds
				break


func status_text() -> String:
	if not warnings.is_empty():
		return "The tide is rising!"
	if max_stages <= 0 or stages_done < max_stages:
		return "Tide rises in %d s" % ceili(_next_left) if _next_left <= 5.0 else ""
	return ""

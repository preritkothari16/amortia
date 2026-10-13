class_name TerrainEvent
extends Resource
## Base for dynamic terrain events (GDD 4.4): fire spread, bridge collapse, rising tide, fog
## banks, day/night, living walls. Each event is data (exported settings, editable as .tres)
## plus runtime state, and works only on the TerrainGrid (plain data), so it can run headless.
##
## Life cycle: start(grid, rng, ...) -> tick(delta) every physics frame -> reset().
## Every change that matters is TELEGRAPHED: a cell goes into `warnings` (cell -> seconds left)
## first and only changes when its warning runs out (GDD 4.1 rule 5).
## Cells with a unit standing in them (is_occupied) are never turned solid / deep under that
## unit: the change waits until the cell is free, so nobody is trapped inside collision.
## Grid changes emit TerrainGrid.terrain_changed, which updates navigation and the TileMap.

## Turn the event off without removing it.
@export var enabled: bool = true

var grid: TerrainGrid
var rng: RandomNumberGenerator
## Callable(cell: Vector2i) -> bool. True if the player or an enemy stands in the cell.
var is_occupied: Callable = func(_cell: Vector2i) -> bool: return false
## Level-wide conditions (night) for events that change them.
var conditions: WorldConditions
## Cells about to change: cell -> seconds until it happens (for the warning view).
var warnings: Dictionary[Vector2i, float] = {}
## Colour of this event's warning outline.
var warning_color: Color = Color(1, 0.3, 0.2)


## Binds the event to a level. `seed_value` makes it deterministic.
func start(terrain_grid: TerrainGrid, seed_value: int, occupied: Callable = Callable(),
		world_conditions: WorldConditions = null) -> void:
	grid = terrain_grid
	rng = RandomNumberGenerator.new()
	rng.seed = seed_value
	if occupied.is_valid():
		is_occupied = occupied
	conditions = world_conditions
	reset()
	_on_start()


## Clears all runtime state (warnings, timers). Grid changes already made stay.
func reset() -> void:
	warnings.clear()
	_on_reset()


func tick(delta: float) -> void:
	if enabled and grid != null:
		_on_tick(delta)


## One line for the HUD when something is coming ("Night in 5 s"), or "".
func status_text() -> String:
	return ""


# --- For subclasses -------------------------------------------------------------------

func _on_start() -> void:
	pass


func _on_reset() -> void:
	pass


func _on_tick(_delta: float) -> void:
	pass


## Counts warnings down; returns the cells whose warning just ran out (sorted, deterministic).
func _due_warnings(delta: float) -> Array[Vector2i]:
	var due: Array[Vector2i] = []
	for cell: Vector2i in warnings.keys():
		warnings[cell] -= delta
		if warnings[cell] <= 0.0:
			due.append(cell)
	due.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	return due


## 4-neighbours inside the map.
func _neighbours4(cell: Vector2i) -> Array[Vector2i]:
	var list: Array[Vector2i] = []
	for d: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
		if grid.in_bounds(cell + d):
			list.append(cell + d)
	return list


## Every cell of this terrain, row by row.
func _cells_of(terrain: String) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y: int in grid.height:
		for x: int in grid.width:
			if grid.get_terrain(Vector2i(x, y)) == terrain:
				cells.append(Vector2i(x, y))
	return cells

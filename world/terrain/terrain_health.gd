class_name TerrainHealth
extends RefCounted
## Hit points and state of destructible / interactive tiles (GDD 4.2): fences 40 HP, player
## barricades 50 HP, doors 60 HP. Works on the TerrainGrid only; the TileMap follows through
## TerrainGrid.terrain_changed (TerrainView).
##   damage(cell, amount)   bullets (player) and enemies breaking through (BREAK traversal)
##   place(cell, terrain)   player builds a barricade; the tile under it is remembered
##   open_door / close_door doors: closed = solid, blocks vision; open = walkable, cost 1
## A destroyed tile becomes its definition's destroyed_into (fence -> grass, door -> door_open),
## or for "" the tile it was built on.

signal tile_destroyed(cell: Vector2i, terrain: String)

var grid: TerrainGrid
## Callable(cell) -> bool: is a unit standing there? (a door can't close on someone)
var is_occupied: Callable = func(_cell: Vector2i) -> bool: return false

## Damaged cells only: cell -> HP left.
var _hp: Dictionary[Vector2i, float] = {}
## Built tiles: cell -> terrain that was there before.
var _underlying: Dictionary[Vector2i, String] = {}


func _init(terrain_grid: TerrainGrid) -> void:
	grid = terrain_grid
	grid.terrain_changed.connect(_on_terrain_changed)


## Cells that have taken damage but still stand (for the damage bars).
func damaged_cells() -> Array[Vector2i]:
	return _hp.keys()


## HP left (max HP if untouched, 0 if not destructible).
func health_of(cell: Vector2i) -> float:
	var d: TerrainDefinition = grid.get_definition(cell)
	if d == null or d.max_health <= 0.0:
		return 0.0
	return _hp.get(cell, d.max_health)


## Deals damage to a destructible tile. Returns true if the tile took it (false = indestructible).
func damage(cell: Vector2i, amount: float) -> bool:
	var d: TerrainDefinition = grid.get_definition(cell)
	if d == null or d.max_health <= 0.0 or amount <= 0.0:
		return false
	var left: float = health_of(cell) - amount
	if left > 0.0:
		_hp[cell] = left
		return true
	destroy(cell)
	return true


func destroy(cell: Vector2i) -> void:
	var d: TerrainDefinition = grid.get_definition(cell)
	if d == null:
		return
	var into: String = d.destroyed_into
	if into == "":
		into = _underlying.get(cell, "road")
	_hp.erase(cell)
	_underlying.erase(cell)
	grid.set_terrain(cell, into)
	tile_destroyed.emit(cell, d.id)


## Builds `terrain` (e.g. "barricade") on a free, player-walkable cell. Returns success.
func place(cell: Vector2i, terrain: String) -> bool:
	var d: TerrainDefinition = grid.get_definition(cell)
	if d == null or not d.player_passable or grid.get_overlay(cell) != "" or is_occupied.call(cell):
		return false
	_underlying[cell] = grid.get_terrain(cell)
	_hp.erase(cell)
	grid.set_terrain(cell, terrain)
	return true


func open_door(cell: Vector2i) -> bool:
	if grid.get_terrain(cell) != "door":
		return false
	_underlying[cell] = "door"
	grid.set_terrain(cell, "door_open")
	return true


## Closes an open door (not a broken one) if nobody stands in it.
func close_door(cell: Vector2i) -> bool:
	if grid.get_terrain(cell) != "door_open" or _underlying.get(cell, "") != "door" or is_occupied.call(cell):
		return false
	_underlying.erase(cell)
	grid.set_terrain(cell, "door")
	return true


func _on_terrain_changed(cells: Array[Vector2i], _affects_cost: bool) -> void:
	if cells.is_empty():  # whole map replaced
		_hp.clear()
		_underlying.clear()

class_name FireSpread
extends TerrainEvent
## Fire (GDD 4.4, "from player weapons"). ignite(cell) sets a burnable cell on fire (overlay
## "fire": enemy cost 20, damage over time via the hazard system). Every spread_interval a
## burning cell may pass the fire to burnable 4-neighbours (chance spread_chance each); a
## neighbour about to catch fire is warned for warning_seconds first. After burn_seconds the
## fire goes out and the tile becomes its burns_into terrain (grass / tall grass -> ash, cost 1).
## max_burning caps how many cells burn at once so a lawn can't burn forever.

@export var burn_seconds: float = 4.0
@export var spread_interval: float = 1.0
@export_range(0.0, 1.0) var spread_chance: float = 0.35
@export var warning_seconds: float = 1.0
@export var max_burning: int = 40

## Burning cell -> seconds of fire left.
var burning: Dictionary[Vector2i, float] = {}
var _spread_left: float = 0.0


func _on_reset() -> void:
	burning.clear()
	_spread_left = spread_interval
	warning_color = Color(1, 0.6, 0.1)


## Starts a fire (after the warning) if the cell is burnable. Returns true if it will burn.
func ignite(cell: Vector2i, immediately: bool = false) -> bool:
	if not _burnable(cell) or burning.has(cell):
		return false
	if immediately:
		_light(cell)
	elif not warnings.has(cell):
		warnings[cell] = warning_seconds
	return true


func _on_tick(delta: float) -> void:
	for cell: Vector2i in _due_warnings(delta):
		warnings.erase(cell)
		if _burnable(cell) and burning.size() < max_burning:
			_light(cell)
	# Burn down.
	for cell: Vector2i in burning.keys():
		burning[cell] -= delta
		if burning[cell] <= 0.0:
			burning.erase(cell)
			var definition: TerrainDefinition = grid.get_definition(cell)
			grid.set_overlay(cell, "")
			if definition != null and definition.burns_into != "":
				grid.set_terrain(cell, definition.burns_into)
	# Spread.
	_spread_left -= delta
	if _spread_left > 0.0:
		return
	_spread_left = spread_interval
	var sources: Array[Vector2i] = burning.keys()
	sources.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	for cell: Vector2i in sources:
		for next: Vector2i in _neighbours4(cell):
			if burning.size() + warnings.size() >= max_burning:
				return
			if _burnable(next) and not burning.has(next) and not warnings.has(next) and rng.randf() < spread_chance:
				warnings[next] = warning_seconds


func _light(cell: Vector2i) -> void:
	burning[cell] = burn_seconds
	grid.set_overlay(cell, "fire")


func _burnable(cell: Vector2i) -> bool:
	var definition: TerrainDefinition = grid.get_definition(cell)
	return definition != null and definition.burnable and grid.get_overlay(cell) != "fire"

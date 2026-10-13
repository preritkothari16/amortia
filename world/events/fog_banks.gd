class_name FogBanks
extends TerrainEvent
## Moving fog (GDD 4.4, zone 3). bank_count round banks (radius radius_tiles) drift across the
## map at speed_tiles_per_second from seeded positions and directions, bouncing off the edges.
## Fog is an OVERLAY: it never replaces the tile under it, it only halves vision (fog terrain's
## vision_multiplier) and costs the same as the ground, so navigation is not rebuilt for it.
## Fog never covers fire (fire wins the overlay slot).

@export var bank_count: int = 3
@export var radius_tiles: float = 4.0
@export var speed_tiles_per_second: float = 0.6
## How often the fog cells are recomputed (seconds).
@export var update_interval: float = 0.5

## Each bank: [centre (cells, float), velocity (cells per second)].
var banks: Array[Array] = []
## Cells this event currently covers with fog.
var fogged: Dictionary[Vector2i, bool] = {}
var _update_left: float = 0.0


func _on_reset() -> void:
	banks.clear()
	fogged.clear()
	_update_left = 0.0


func _on_start() -> void:
	for i: int in bank_count:
		var centre: Vector2 = Vector2(rng.randf_range(0.0, grid.width), rng.randf_range(0.0, grid.height))
		var angle: float = rng.randf_range(0.0, TAU)
		banks.append([centre, Vector2.from_angle(angle) * speed_tiles_per_second])
	_apply()


func _on_tick(delta: float) -> void:
	for bank: Array in banks:
		var c: Vector2 = bank[0] + bank[1] * delta
		var v: Vector2 = bank[1]
		if c.x < 0.0 or c.x > grid.width:
			v.x = -v.x
		if c.y < 0.0 or c.y > grid.height:
			v.y = -v.y
		bank[0] = c.clamp(Vector2.ZERO, Vector2(grid.width, grid.height))
		bank[1] = v
	_update_left -= delta
	if _update_left <= 0.0:
		_update_left = update_interval
		_apply()


## Recomputes the fog cells and only touches cells that changed.
func _apply() -> void:
	var now: Dictionary[Vector2i, bool] = {}
	var r: int = ceili(radius_tiles)
	for bank: Array in banks:
		var c: Vector2 = bank[0]
		for y: int in range(floori(c.y) - r, floori(c.y) + r + 1):
			for x: int in range(floori(c.x) - r, floori(c.x) + r + 1):
				var cell: Vector2i = Vector2i(x, y)
				if grid.in_bounds(cell) and (Vector2(cell) + Vector2(0.5, 0.5)).distance_to(c) <= radius_tiles:
					now[cell] = true
	for cell: Vector2i in fogged:
		if not now.has(cell) and grid.get_overlay(cell) == "fog":
			grid.set_overlay(cell, "")
	for cell: Vector2i in now:
		if grid.get_overlay(cell) == "":
			grid.set_overlay(cell, "fog")
		elif grid.get_overlay(cell) != "fog":
			now.erase(cell)  # fire (or another overlay) keeps the cell
	fogged = now

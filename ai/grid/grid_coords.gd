class_name GridCoords
extends RefCounted
## Converts between world pixels and grid cells.
## Kept apart from TerrainGrid so search code only ever deals with cells, never pixels.

## Width and height of one tile in pixels.
var tile_size: int = 16
## World position of the top-left corner of cell (0, 0).
var origin: Vector2 = Vector2.ZERO


func _init(tile_px: int = 16, world_origin: Vector2 = Vector2.ZERO) -> void:
	assert(tile_px > 0, "GridCoords: tile size must be positive")
	tile_size = tile_px
	origin = world_origin


## The cell that contains this world position. Uses floor, so negative positions map to
## negative cells instead of being rounded towards (0, 0).
func world_to_cell(world_pos: Vector2) -> Vector2i:
	var local: Vector2 = (world_pos - origin) / float(tile_size)
	return Vector2i(floori(local.x), floori(local.y))


## Centre of the cell in world pixels. Units steer towards cell centres.
func cell_to_world(cell: Vector2i) -> Vector2:
	return origin + (Vector2(cell) + Vector2(0.5, 0.5)) * tile_size


## The cell's square in world pixels (for debug drawing).
func cell_rect(cell: Vector2i) -> Rect2:
	return Rect2(origin + Vector2(cell * tile_size), Vector2(tile_size, tile_size))

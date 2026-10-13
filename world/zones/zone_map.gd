class_name ZoneMap
extends Node2D
## A hand-built level. Terrain lives in the "Terrain" TileMapLayer: every tile carries a
## "terrain" custom-data string (road, grass, tall_grass, fence, wall, house).
## The terrain-cost grid (ai/grid) will be built from get_terrain_rows(), which is plain data.

const TERRAIN_DATA_LAYER: String = "terrain"

@onready var terrain_layer: TileMapLayer = $Terrain


## Map size in tiles. Maps start at cell (0, 0).
func get_grid_size() -> Vector2i:
	return terrain_layer.get_used_rect().end


## Terrain name of one cell, or "" outside the map.
func get_terrain_at(cell: Vector2i) -> String:
	var data: TileData = terrain_layer.get_cell_tile_data(cell)
	if data == null:
		return ""
	return data.get_custom_data(TERRAIN_DATA_LAYER)


## Terrain names row by row: rows[y][x]. No Node references, so AI code can take it directly.
func get_terrain_rows() -> Array[PackedStringArray]:
	var size: Vector2i = get_grid_size()
	var rows: Array[PackedStringArray] = []
	for y: int in size.y:
		var row: PackedStringArray = PackedStringArray()
		for x: int in size.x:
			row.append(get_terrain_at(Vector2i(x, y)))
		rows.append(row)
	return rows


func world_to_cell(world_pos: Vector2) -> Vector2i:
	return terrain_layer.local_to_map(terrain_layer.to_local(world_pos))


## Centre of a cell in world space.
func cell_to_world(cell: Vector2i) -> Vector2:
	return terrain_layer.to_global(terrain_layer.map_to_local(cell))


## Map bounds in world pixels.
func get_world_rect() -> Rect2:
	var tile: Vector2 = Vector2(terrain_layer.tile_set.tile_size)
	return Rect2(global_position, Vector2(get_grid_size()) * tile)


func get_player_spawn() -> Vector2:
	return ($PlayerSpawn as Marker2D).global_position


func get_enemy_spawns() -> Array[Vector2]:
	var spawns: Array[Vector2] = []
	for marker: Node in $EnemySpawns.get_children():
		spawns.append((marker as Marker2D).global_position)
	return spawns


# --- Area markers (wave-to-wave progression) ------------------------------------------

## Where the player enters the area (left side). Same as the player spawn.
func get_entry() -> Vector2:
	return get_player_spawn()


## Centre of the exit (right side), or the player spawn if the map has no exit marker.
func get_exit() -> Vector2:
	return ($Exit as Marker2D).global_position if has_node("Exit") else get_player_spawn()


## Spawns behind the player's entry (left edge). Part of later waves arrives from here.
func get_behind_spawns() -> Array[Vector2]:
	var spawns: Array[Vector2] = []
	if has_node("BehindSpawns"):
		for marker: Node in $BehindSpawns.get_children():
			spawns.append((marker as Marker2D).global_position)
	return spawns


## Cells of the closed exit gate ("gate" terrain), opened when the wave is done.
func get_gate_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for cell: Vector2i in terrain_layer.get_used_cells():
		if get_terrain_at(cell) == "gate":
			cells.append(cell)
	return cells

extends Node2D
## Prototype level root: puts the player on the map's spawn, keeps the camera inside the map,
## and builds the terrain-cost grid the enemy AI will path over.

@export var terrain_costs: TerrainCosts

## Plain-data copy of the map for the AI. Rebuild or set_terrain() when terrain changes.
var terrain_grid: TerrainGrid

@onready var _map: ZoneMap = $MapleHollow
@onready var _player: Player = $Player
@onready var _cost_overlay: TerrainCostOverlay = $TerrainCostOverlay


func _ready() -> void:
	var tile_px: int = _map.terrain_layer.tile_set.tile_size.x
	terrain_grid = TerrainGrid.from_rows(_map.get_terrain_rows(), terrain_costs, tile_px)
	_cost_overlay.grid = terrain_grid

	_player.global_position = _map.get_player_spawn()
	var bounds: Rect2 = _map.get_world_rect()
	var camera: Camera2D = _player.get_node("Camera2D")
	camera.limit_left = int(bounds.position.x)
	camera.limit_top = int(bounds.position.y)
	camera.limit_right = int(bounds.end.x)
	camera.limit_bottom = int(bounds.end.y)
	camera.reset_smoothing()

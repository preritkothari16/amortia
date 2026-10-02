extends Node2D
## Prototype level root: puts the player on the map's spawn, keeps the camera inside the map,
## builds the terrain-cost grid, and keeps the shared flow field pointing at the player.

@export var terrain_costs: TerrainCosts

## Plain-data copy of the map for the AI. Rebuild or set_terrain() when terrain changes.
var terrain_grid: TerrainGrid
## Shared flow field towards the player, rebuilt whenever the player enters a new cell.
var flow_field: FlowField
## How long the last flow field rebuild took, in milliseconds.
var last_flow_build_msec: float = 0.0

@onready var _map: ZoneMap = $MapleHollow
@onready var _player: Player = $Player
@onready var _cost_overlay: TerrainCostOverlay = $TerrainCostOverlay
@onready var _flow_overlay: FlowFieldOverlay = $FlowFieldOverlay
@onready var _wave_manager: WaveManager = $WaveManager


func _ready() -> void:
	var coords: GridCoords = GridCoords.new(_map.terrain_layer.tile_set.tile_size.x, _map.get_world_rect().position)
	terrain_grid = TerrainGrid.from_rows(_map.get_terrain_rows(), terrain_costs, coords)
	_cost_overlay.grid = terrain_grid
	flow_field = FlowField.new(terrain_grid)
	_flow_overlay.field = flow_field

	_player.global_position = _map.get_player_spawn()
	var bounds: Rect2 = _map.get_world_rect()
	var camera: Camera2D = _player.get_node("Camera2D")
	camera.limit_left = int(bounds.position.x)
	camera.limit_top = int(bounds.position.y)
	camera.limit_right = int(bounds.end.x)
	camera.limit_bottom = int(bounds.end.y)
	camera.reset_smoothing()
	_update_flow_field()
	_wave_manager.setup(_map.get_enemy_spawns(), flow_field, _player)


func _physics_process(_delta: float) -> void:
	_update_flow_field()


## Rebuilds the field only when the player's cell changes (GDD 6.2).
func _update_flow_field() -> void:
	var cell: Vector2i = terrain_grid.coords.world_to_cell(_player.global_position)
	if flow_field.is_built() and cell == flow_field.target:
		return
	if not terrain_grid.is_walkable(cell):
		return  # keep the old field rather than pointing everything at a wall
	var start_usec: int = Time.get_ticks_usec()
	flow_field.build(cell)
	last_flow_build_msec = (Time.get_ticks_usec() - start_usec) / 1000.0
	_flow_overlay.refresh()

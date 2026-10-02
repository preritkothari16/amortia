class_name WaveManager
extends Node2D
## Prototype spawner: scatters a wave of enemies around the map's enemy spawn points and
## tracks who is alive. No GA yet - every enemy uses its scene's base stats.
## F3 spawns another wave (debug).

signal wave_cleared

@export var enemy_scene: PackedScene
@export var wave_size: int = 20
## Spawn the first wave as soon as the level starts.
@export var auto_start: bool = true
## Enemies land on a random walkable tile up to this many tiles from a spawn marker.
@export var spawn_scatter_tiles: int = 2
## Fixed seed for reproducible spawn positions (tests, experiments). 0 = random each run.
@export var spawn_seed: int = 0

## Living enemies. Shared with every enemy for separation, so only add/remove here.
var alive: Array[Enemy] = []

var _flow_field: FlowField
var _target: Node2D
var _spawn_points: Array[Vector2] = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func setup(spawn_points: Array[Vector2], flow_field: FlowField, target: Node2D) -> void:
	if spawn_seed != 0:
		_rng.seed = spawn_seed
	else:
		_rng.randomize()
	_spawn_points = spawn_points
	_flow_field = flow_field
	_target = target
	if auto_start:
		spawn_wave()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_spawn_wave"):
		spawn_wave()


## Spawns `count` enemies, cycling through the spawn markers.
func spawn_wave(count: int = wave_size) -> void:
	for i: int in count:
		spawn_enemy(_spawn_points[i % _spawn_points.size()])


func spawn_enemy(near: Vector2) -> Enemy:
	var enemy: Enemy = enemy_scene.instantiate() as Enemy
	enemy.global_position = _pick_spawn_position(near, enemy.stats)
	enemy.setup(_flow_field, _target, alive)
	enemy.died.connect(_on_enemy_died)
	alive.append(enemy)
	add_child(enemy)
	return enemy


## A random tile near `near` that the enemy can stand on (walkable and not a fence),
## jittered inside the tile so enemies don't spawn exactly on top of each other.
func _pick_spawn_position(near: Vector2, stats: EnemyStats) -> Vector2:
	var grid: TerrainGrid = _flow_field.grid
	var centre: Vector2i = grid.coords.world_to_cell(near)
	for attempt: int in 20:
		var cell: Vector2i = centre + Vector2i(
			_rng.randi_range(-spawn_scatter_tiles, spawn_scatter_tiles),
			_rng.randi_range(-spawn_scatter_tiles, spawn_scatter_tiles))
		if grid.is_walkable(cell) and not stats.climbable_terrains.has(grid.get_terrain(cell)):
			var jitter: Vector2 = Vector2(_rng.randf_range(-3, 3), _rng.randf_range(-3, 3))
			return grid.coords.cell_to_world(cell) + jitter
	return near


func _on_enemy_died(enemy: Enemy) -> void:
	alive.erase(enemy)
	if alive.is_empty():
		wave_cleared.emit()

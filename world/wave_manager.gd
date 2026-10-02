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
## New enemies learn where the player was when they spawned ("the Pulse") and come to
## investigate. Off = they stay idle until they see or hear the player.
@export var alert_on_spawn: bool = true
## Give every enemy a random genome within the wave's stat budget (no GA yet).
## Off = plain archetype values.
@export var random_genomes: bool = true
## Print a one-line gene summary per wave.
@export var log_waves: bool = true

## Waves spawned so far in this zone (the first wave is 1). Sets the stat budget.
var wave_number: int = 0

## Living enemies. Shared with every enemy for separation, so only add/remove here.
var alive: Array[Enemy] = []

var _context: EnemyContext
var _spawn_points: Array[Vector2] = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func setup(spawn_points: Array[Vector2], context: EnemyContext) -> void:
	if spawn_seed != 0:
		_rng.seed = spawn_seed
	else:
		_rng.randomize()
	_spawn_points = spawn_points
	_context = context
	if auto_start:
		spawn_wave()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_spawn_wave"):
		spawn_wave()


## Spawns `count` enemies, cycling through the spawn markers. Each gets its own genome.
func spawn_wave(count: int = wave_size) -> void:
	wave_number += 1
	var genomes: Array[Genome] = []
	for i: int in count:
		var genome: Genome = make_genome()
		genomes.append(genome)
		spawn_enemy(_spawn_points[i % _spawn_points.size()], genome)
	if log_waves and not genomes.is_empty() and genomes[0] != null:
		print(_wave_summary(genomes))


## A random genome for the current wave's budget, or null if genomes are off.
func make_genome() -> Genome:
	var rules: GenomeRules = _context.genome_rules
	if not random_genomes or rules == null:
		return null
	return Genome.random(_rng, rules, rules.budget_for_wave(maxi(wave_number, 1)))


func spawn_enemy(near: Vector2, genome: Genome = null) -> Enemy:
	var enemy: Enemy = enemy_scene.instantiate() as Enemy
	enemy.global_position = _pick_spawn_position(near, enemy.stats)
	enemy.setup(_context, alive, genome)
	if alert_on_spawn:
		enemy.alert(_context.target.global_position)
	enemy.died.connect(_on_enemy_died)
	alive.append(enemy)
	add_child(enemy)
	return enemy


## A random tile near `near` that the enemy can stand on (walkable and not a fence),
## jittered inside the tile so enemies don't spawn exactly on top of each other.
func _pick_spawn_position(near: Vector2, stats: EnemyStats) -> Vector2:
	var grid: TerrainGrid = _context.flow_field.grid
	var centre: Vector2i = grid.coords.world_to_cell(near)
	for attempt: int in 20:
		var cell: Vector2i = centre + Vector2i(
			_rng.randi_range(-spawn_scatter_tiles, spawn_scatter_tiles),
			_rng.randi_range(-spawn_scatter_tiles, spawn_scatter_tiles))
		if grid.is_walkable(cell) and not stats.climbable_terrains.has(grid.get_terrain(cell)):
			var jitter: Vector2 = Vector2(_rng.randf_range(-3, 3), _rng.randf_range(-3, 3))
			return grid.coords.cell_to_world(cell) + jitter
	return near


## e.g. "[Wave 1] 20 enemies, budget 15 | speed 2.1-7.9 (avg 5.0) | ... | paths FLOW 7 ASTAR 6 GREEDY 7"
func _wave_summary(genomes: Array[Genome]) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for gene: StringName in Genome.STAT_GENES + Genome.BEHAVIOUR_GENES:
		var lo: float = INF
		var hi: float = -INF
		var total: float = 0.0
		for g: Genome in genomes:
			var v: float = g.get(gene)
			lo = minf(lo, v)
			hi = maxf(hi, v)
			total += v
		parts.append("%s %.2f-%.2f (avg %.2f)" % [gene, lo, hi, total / genomes.size()])
	var modes: Dictionary = {}
	for g: Genome in genomes:
		var m: String = Genome.PathMode.keys()[g.path_mode]
		modes[m] = modes.get(m, 0) + 1
	return "[Wave %d] %d enemies, budget %d | %s | paths %s" % [
		wave_number, genomes.size(), _context.genome_rules.budget_for_wave(wave_number), " | ".join(parts), modes]


func _on_enemy_died(enemy: Enemy) -> void:
	alive.erase(enemy)
	if alive.is_empty():
		wave_cleared.emit()

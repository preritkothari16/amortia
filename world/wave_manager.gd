class_name WaveManager
extends Node2D
## Prototype spawner: scatters a wave of enemies around the map's enemy spawn points and
## tracks who is alive. Each enemy gets a random genome (no GA yet) and a FitnessRecord.
## A wave ends when all its enemies are dead, when the next wave spawns, or on F8 (debug);
## then every record is frozen, scored and reported. F3 spawns another wave (debug).

signal wave_cleared
## Fitness results of a finished wave, best first (see end_wave for the entry format).
signal wave_ended(results: Array[Dictionary])

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
## Results of the last finished wave, best fitness first.
var last_wave_results: Array[Dictionary] = []
## Seconds since the current wave spawned (only counts while it is open).
var wave_seconds: float = 0.0

## The wave being scored: one {genome, record} per enemy spawned by spawn_wave().
var _wave_entries: Array[Dictionary] = []
var _wave_open: bool = false

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


func _physics_process(delta: float) -> void:
	if _wave_open:
		wave_seconds += delta


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_spawn_wave"):
		spawn_wave()
	elif event.is_action_pressed("debug_end_wave"):
		end_wave()


## Spawns `count` enemies, cycling through the spawn markers. Each gets its own genome.
func spawn_wave(count: int = wave_size) -> void:
	end_wave()  # close and score the previous wave first, if it is still open
	wave_number += 1
	wave_seconds = 0.0
	_wave_entries.clear()
	_wave_open = true
	var genomes: Array[Genome] = []
	for i: int in count:
		var genome: Genome = make_genome()
		genomes.append(genome)
		var record: FitnessRecord = FitnessRecord.new()
		record.wave = wave_number
		_wave_entries.append({"genome": genome, "record": record})
		spawn_enemy(_spawn_points[i % _spawn_points.size()], genome, record)
	if log_waves and not genomes.is_empty() and genomes[0] != null:
		print(_wave_summary(genomes))


## A random genome for the current wave's budget, or null if genomes are off.
func make_genome() -> Genome:
	var rules: GenomeRules = _context.genome_rules
	if not random_genomes or rules == null:
		return null
	return Genome.random(_rng, rules, rules.budget_for_wave(maxi(wave_number, 1)))


func spawn_enemy(near: Vector2, genome: Genome = null, record: FitnessRecord = null) -> Enemy:
	var enemy: Enemy = enemy_scene.instantiate() as Enemy
	enemy.global_position = _pick_spawn_position(near, enemy.stats)
	enemy.setup(_context, alive, genome, record)
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


## Freezes every record of the current wave, scores it and reports. Safe to call twice.
## Each result: {"genome": Genome, "record": FitnessRecord, "components": {D, P, S, O},
## "fitness": float}, sorted best first (ties keep spawn order).
func end_wave() -> void:
	if not _wave_open:
		return
	_wave_open = false
	var results: Array[Dictionary] = []
	for i: int in _wave_entries.size():
		var record: FitnessRecord = _wave_entries[i]["record"]
		record.freeze()
		var components: Dictionary[StringName, float] = _context.fitness.components(record, wave_seconds)
		results.append({
			"genome": _wave_entries[i]["genome"], "record": record, "components": components,
			"fitness": _context.fitness.score_components(components), "index": i,
		})
	results.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["fitness"] > b["fitness"] or (a["fitness"] == b["fitness"] and a["index"] < b["index"]))
	last_wave_results = results
	if log_waves:
		print(fitness_report(results))
	wave_ended.emit(results)


## Current fitness of a record if the wave ended now (for live debug display).
func preview_fitness(record: FitnessRecord) -> float:
	return _context.fitness.score(record, wave_seconds) if _context.fitness != null else 0.0


## Multi-line end-of-wave report: summary line, then one line per enemy, best first.
func fitness_report(results: Array[Dictionary]) -> String:
	var s: FitnessSettings = _context.fitness.settings
	var killed: int = 0
	var total: float = 0.0
	for r: Dictionary in results:
		killed += 1 if (r["record"] as FitnessRecord).died else 0
		total += r["fitness"]
	var lines: PackedStringArray = PackedStringArray()
	lines.append("[Wave %d fitness] %d enemies, %.1f s, %d killed / %d survived | F best %.3f mean %.3f worst %.3f | F = %.2f D + %.2f P + %.2f S + %.2f O" % [
		wave_number, results.size(), wave_seconds, killed, results.size() - killed,
		results[0]["fitness"] if not results.is_empty() else 0.0, total / maxf(results.size(), 1),
		results[-1]["fitness"] if not results.is_empty() else 0.0,
		s.weight_damage, s.weight_pressure, s.weight_survival, s.weight_objective])
	for i: int in results.size():
		var r: Dictionary = results[i]
		var rec: FitnessRecord = r["record"]
		var c: Dictionary = r["components"]
		var genome: Genome = r["genome"]
		lines.append("  #%-2d F %.3f | D %.2f P %.2f S %.2f O %.2f | dmg %.0f, near %.1f s, alive %.1f s, %s | %s" % [
			i + 1, r["fitness"], c[Fitness.D], c[Fitness.P], c[Fitness.S], c[Fitness.O],
			rec.damage_dealt, rec.pressure_seconds, rec.alive_seconds, "killed" if rec.died else "survived",
			genome.describe() if genome != null else "(no genome)"])
	return "\n".join(lines)


func _on_enemy_died(enemy: Enemy) -> void:
	alive.erase(enemy)
	if alive.is_empty():
		wave_cleared.emit()
	# The wave is over once every enemy it spawned is dead.
	if _wave_open and _wave_entries.all(func(e: Dictionary) -> bool: return (e["record"] as FitnessRecord).frozen):
		end_wave()

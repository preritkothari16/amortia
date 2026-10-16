class_name PowerUpManager
extends Node
## Spawns and applies temporary power-ups during a wave (separate from permanent progression).
##  - Weighted random type, random REACHABLE safe cell near the player (ReachableCells), seeded:
##    the same wave seed gives the same sequence (Retry replays it).
##  - Only while a wave is open and its enemies are here; `first_delay`, then every `interval`
##    seconds, at most `max_per_wave` per wave and `max_on_map` lying around.
##  - Limits (PowerUpSet): effects are brief (capped duration), the same kind refreshes instead of
##    stacking, at most `max_concurrent` timed effects at once.
##  - Effects live in Player.modifiers' temporary layer / shield, never in saved or base stats.

signal spawned(type: PowerUpType, position: Vector2)
signal collected(type: PowerUpType)

var settings: PowerUpSet
var grid: TerrainGrid
var player: Player
var wave_manager: WaveManager
var seed_value: int = 1
## False = no spawning (prototype, experiments, tests that don't want them).
var enabled: bool = true

var spawned_this_wave: int = 0
var _timer: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _on_map: Array[PowerUpPickup] = []


func setup(power_up_set: PowerUpSet, terrain_grid: TerrainGrid, the_player: Player, waves: WaveManager, base_seed: int) -> void:
	settings = power_up_set
	grid = terrain_grid
	player = the_player
	wave_manager = waves
	seed_value = base_seed
	wave_manager.wave_started.connect(_on_wave_started)
	wave_manager.wave_restarting.connect(func(_w: int) -> void: clear())


func _on_wave_started(wave: int) -> void:
	clear()
	spawned_this_wave = 0
	_timer = settings.first_delay
	_rng.seed = seed_value + wave * 977


## Removes every power-up lying on the map (area change, Retry).
func clear() -> void:
	for p: PowerUpPickup in _on_map:
		if is_instance_valid(p):
			p.queue_free()
	_on_map.clear()


func _physics_process(delta: float) -> void:
	if not enabled or settings == null or wave_manager == null or not wave_manager.is_wave_running() \
			or wave_manager.is_arriving() or player == null or player.is_dead:
		return
	_on_map = _on_map.filter(func(p: PowerUpPickup) -> bool: return is_instance_valid(p) and not p.is_queued_for_deletion())
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = settings.interval
	if spawned_this_wave < settings.max_per_wave and _on_map.size() < settings.max_on_map:
		spawn_one()


## Spawns one power-up now (weighted type, reachable cell). Returns it, or null if no cell / no types.
func spawn_one() -> PowerUpPickup:
	var type: PowerUpType = settings.pick(_rng.randf() * settings.total_weight())
	if type == null:
		return null
	var cell: Vector2i = _pick_cell()
	if cell == Vector2i(-1, -1):
		return null
	var pickup: PowerUpPickup = PowerUpPickup.create(type, self, grid.coords.cell_to_world(cell), settings.lifetime)
	get_parent().add_child(pickup)
	_on_map.append(pickup)
	spawned_this_wave += 1
	spawned.emit(type, pickup.global_position)
	return pickup


## A random reachable, safe cell between min and max distance from the player; (-1, -1) if none.
func _pick_cell() -> Vector2i:
	var here: Vector2i = grid.coords.world_to_cell(player.global_position)
	var candidates: Array[Vector2i] = []
	for c: Vector2i in ReachableCells.from(grid, here):
		var d: float = Vector2(c - here).length()
		if d >= settings.min_player_distance_cells and d <= settings.max_player_distance_cells:
			candidates.append(c)
	if candidates.is_empty():
		return Vector2i(-1, -1)
	return candidates[_rng.randi_range(0, candidates.size() - 1)]


## True if the effect may be taken now (the concurrent-effects limit).
func can_collect(type: PowerUpType) -> bool:
	if type.kind == PowerUpType.Kind.HEAL:
		return true
	return _timed_effects_active(type.id) < settings.max_concurrent


## Applies the effect to `target`. False (nothing happens, the pickup stays) at the concurrency limit.
func collect(type: PowerUpType, target: Player) -> bool:
	if not can_collect(type):
		return false
	apply(type, target)
	collected.emit(type)
	return true


func apply(type: PowerUpType, target: Player) -> void:
	var seconds: float = minf(type.duration, settings.max_duration)
	match type.kind:
		PowerUpType.Kind.HEAL:
			target.heal(type.heal_amount)
		PowerUpType.Kind.SHIELD:
			target.add_shield(type.shield_amount, seconds)
		PowerUpType.Kind.BOOST:
			target.modifiers.add_temporary(type.id, type.modifiers, seconds)


## Timed effects running (boosts + shield), not counting `except_id` itself (a refresh is not a new effect).
func _timed_effects_active(except_id: StringName) -> int:
	var n: int = 0
	for id: StringName in player.modifiers.temporary_ids():
		if id != except_id:
			n += 1
	if player.shield > 0.0 and except_id != &"shield":
		n += 1
	return n

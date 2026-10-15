class_name TerrainEvents
extends Node
## Runs a level's dynamic terrain events (GDD 4.4) and terrain hazards.
##   - `events`: TerrainEvent resources (fire, bridge, tide, fog, day/night, living walls).
##     They are duplicated in setup() so the .tres files never hold runtime state.
##   - hazards: every hazard_tick seconds, units standing in a hazard tile (fire overlay, toxic
##     pool) take hazard_damage_per_second x hazard_tick. Enemies' toxin_resistance gene cuts
##     toxic damage (x (1 - gene)).
## Debug: F10 sets the tile under the mouse on fire (no fire weapon exists yet).

## Events for this level (the prototype has only FireSpread, which does nothing until ignited).
@export var events: Array[TerrainEvent] = []
## Base seed for the events; 0 = the WaveManager's spawn seed (or random).
@export var seed_value: int = 0
@export var hazard_tick: float = 0.5
@export var hazards_enabled: bool = true

var grid: TerrainGrid
var rules: TerrainCosts
var player: Player
var wave_manager: WaveManager
var conditions: WorldConditions

var _hazard_left: float = 0.0
var _running: bool = false


## Starts every event on this grid. Call again (or restart()) when the map changes.
func setup(terrain_grid: TerrainGrid, terrain_rules: TerrainCosts, the_player: Player,
		waves: WaveManager, world_conditions: WorldConditions, base_seed: int) -> void:
	grid = terrain_grid
	rules = terrain_rules
	player = the_player
	wave_manager = waves
	conditions = world_conditions
	if seed_value != 0:
		base_seed = seed_value
	var fresh: Array[TerrainEvent] = []
	for e: TerrainEvent in events:
		fresh.append(e.duplicate(true) as TerrainEvent)
	events = fresh
	restart(base_seed)


## (Re)starts every event from a clean state, e.g. after a map swap or a retried wave.
func restart(base_seed: int) -> void:
	for i: int in events.size():
		events[i].start(grid, base_seed + 7919 * (i + 1), is_occupied, conditions)
	_hazard_left = hazard_tick
	_running = true


func stop() -> void:
	_running = false
	for e: TerrainEvent in events:
		e.reset()
	if conditions != null:
		conditions.is_night = false


## True if the player or a living enemy stands in the cell.
func is_occupied(cell: Vector2i) -> bool:
	if grid == null:
		return false
	if player != null and not player.is_dead and grid.coords.world_to_cell(player.global_position) == cell:
		return true
	if wave_manager != null:
		for e: Enemy in wave_manager.alive:
			if grid.coords.world_to_cell(e.global_position) == cell:
				return true
	return false


## First event of this class, or null. e.g. get_event(FireSpread).
func get_event(type: Script) -> TerrainEvent:
	for e: TerrainEvent in events:
		if e.get_script() == type:
			return e
	return null


## Every warning of every event: [cell, seconds left, colour].
func all_warnings() -> Array[Array]:
	var list: Array[Array] = []
	for e: TerrainEvent in events:
		for cell: Vector2i in e.warnings:
			list.append([cell, e.warnings[cell], e.warning_color])
	return list


## The first non-empty event message ("Night falls in 5 s"), or "".
func status_text() -> String:
	for e: TerrainEvent in events:
		if e.enabled:
			var text: String = e.status_text()
			if text != "":
				return text
	return ""


func _physics_process(delta: float) -> void:
	if not _running or grid == null:
		return
	for e: TerrainEvent in events:
		e.tick(delta)
	if hazards_enabled:
		_hazard_left -= delta
		if _hazard_left <= 0.0:
			_hazard_left = hazard_tick
			_apply_hazards()


## [hazard, damage per second] of the worst hazard in the cell (overlay or base).
func hazard_at(cell: Vector2i) -> Array:
	var best: Array = [TerrainDefinition.Hazard.NONE, 0.0]
	for name: String in [grid.get_overlay(cell), grid.get_terrain(cell)]:
		var d: TerrainDefinition = rules.get_definition(name) if name != "" else null
		if d != null and d.hazard != TerrainDefinition.Hazard.NONE and d.hazard_damage_per_second > best[1]:
			best = [d.hazard, d.hazard_damage_per_second]
	return best


func _apply_hazards() -> void:
	if player != null and not player.is_dead:
		var h: Array = hazard_at(grid.coords.world_to_cell(player.global_position))
		if h[1] > 0.0:
			player.take_damage(h[1] * hazard_tick)
	if wave_manager == null:
		return
	for e: Enemy in wave_manager.alive.duplicate():
		var h: Array = hazard_at(grid.coords.world_to_cell(e.global_position))
		if h[1] <= 0.0:
			continue
		var amount: float = h[1] * hazard_tick
		if h[0] == TerrainDefinition.Hazard.TOXIC and e.genome != null:
			amount *= 1.0 - e.genome.toxin_resistance
		if amount > 0.0:
			e.take_damage(amount)


func _unhandled_input(event: InputEvent) -> void:
	if DebugKeys.enabled() and event.is_action_pressed("debug_ignite") and grid != null:
		var fire: FireSpread = get_event(FireSpread) as FireSpread
		var vp: Viewport = get_viewport()
		var cam: Camera2D = vp.get_camera_2d()
		if fire != null and cam != null:
			var mouse: Vector2 = cam.get_global_mouse_position()
			fire.ignite(grid.coords.world_to_cell(mouse))

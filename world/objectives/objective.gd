class_name Objective
extends Node2D
## Base for level objectives (GDD 8.2). One objective node lives under the level while a
## campaign level runs; LevelFlow drives it through these hooks:
##   area_loaded(map)       a (new) area is on screen: place points / nests / supplies / survivor
##   wave_started(n)        wave n of the level began (enemies arrive after the opening delay)
##   tick(delta)            every physics frame while the wave is open
##   wave_ended()           the wave was completed (scored and bred)
##   retry()                the lost wave is replayed: back to this wave's start state
## and it reports back with signals:
##   goal_reached           this wave's goal is met -> LevelFlow ends the wave (scored, bred)
##   failed(reason)         the objective is lost (escort died, point lost, alarm) -> the wave
##                          is lost like a player death: Game Over, Retry the same wave
## Objective fitness (O) goes to the enemy responsible: enemy.fitness_record.add_objective().
## Points are raw; Fitness normalises them by FitnessSettings.objective_cap (bounded 0..1).

enum State { INACTIVE, ACTIVE, COMPLETED, FAILED }

signal goal_reached
signal failed(reason: String)
signal state_changed(state: State)

var config: ObjectiveConfig
var state: State = State.INACTIVE:
	set(value):
		if state != value:
			state = value
			state_changed.emit(state)
## Set by LevelFlow.
var grid: TerrainGrid
var player: Player
var wave_manager: WaveManager
var terrain_health: TerrainHealth
var map: ZoneMap
## Wave of the level (1-based) currently played.
var wave_in_level: int = 0


func setup(objective_config: ObjectiveConfig, terrain_grid: TerrainGrid, the_player: Player,
		waves: WaveManager, health: TerrainHealth) -> void:
	config = objective_config
	grid = terrain_grid
	player = the_player
	wave_manager = waves
	terrain_health = health


## True if killing every enemy of the wave also completes it (Survive, Hold...). False when
## the goal is something else (Escort reaching the exit, Stealth...).
func clears_on_kill_all() -> bool:
	return true


## True if the exit gate is open from the start (Stealth: sneak to it; Escort: walk to it).
func exit_open_from_start() -> bool:
	return false


## The player walked out while the wave was still on (only with exit_open_from_start).
## Return true if that completes the wave's goal.
func player_exited() -> bool:
	return false


func area_loaded(zone_map: ZoneMap) -> void:
	map = zone_map
	_clear_props()


func wave_started(wave: int) -> void:
	wave_in_level = wave
	state = State.ACTIVE


func tick(_delta: float) -> void:
	pass


func wave_ended() -> void:
	if state == State.ACTIVE:
		state = State.COMPLETED


func retry() -> void:
	state = State.INACTIVE


## One HUD line, e.g. "Hold the point  23 s  (HP 140)".
func hud_text() -> String:
	return ""


## Called by subclasses.
func _complete() -> void:
	if state != State.ACTIVE:
		return
	state = State.COMPLETED
	goal_reached.emit()


func _fail(reason: String) -> void:
	if state != State.ACTIVE:
		return
	state = State.FAILED
	failed.emit(reason)


## Gives `points` objective disruption to an enemy (fitness O), if it is scored.
static func credit(enemy: Enemy, points: float) -> void:
	if enemy != null and enemy.fitness_record != null and points > 0.0:
		enemy.fitness_record.add_objective(points)


## Removes props this objective placed (children).
func _clear_props() -> void:
	for child: Node in get_children():
		child.queue_free()


# --- Helpers for placing props -------------------------------------------------------

## The walkable (for the player) cell nearest to `cell`, searching outwards; `cell` if none.
func walkable_near(cell: Vector2i) -> Vector2i:
	for r: int in 12:
		for dy: int in range(-r, r + 1):
			for dx: int in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var c: Vector2i = cell + Vector2i(dx, dy)
				var d: TerrainDefinition = grid.get_definition(c)
				if d != null and d.player_passable and grid.get_overlay(c) == "":
					return c
	return cell


## Shortest 4-way walk for a survivor (player rules: no fences, no water) - breadth-first
## search. [] if none. The exit gate counts as walkable (it opens).
func walk_path(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var came: Dictionary[Vector2i, Vector2i] = {from: from}
	var queue: Array[Vector2i] = [from]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		if c == to:
			var path: Array[Vector2i] = [c]
			while path[0] != from:
				path.push_front(came[path[0]])
			return path
		for d: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.UP, Vector2i.LEFT]:
			var n: Vector2i = c + d
			if came.has(n):
				continue
			var t: TerrainDefinition = grid.get_definition(n)
			if t == null or not (t.player_passable or t.id == "gate"):
				continue
			came[n] = c
			queue.append(n)
	return []

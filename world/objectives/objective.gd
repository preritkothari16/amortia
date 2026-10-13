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


## True if the exit gate is open from the start (Stealth: sneak to it).
func exit_open_from_start() -> bool:
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

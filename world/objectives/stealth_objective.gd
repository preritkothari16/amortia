class_name StealthObjective
extends Objective
## Stealth (GDD 8.2): reach the exit without raising an alarm. An alarm = an enemy sees the
## player (its Awareness enters CHASE; within 2 tiles you are always seen, GDD 4.3). More than
## alarms_allowed alarms = level fail (Retry). The exit is open from the start; walking out is
## the wave goal. Enemies are NOT told the player's spawn position (no spawn Pulse).
## Objective fitness O: the enemy that raises an alarm earns alarm_points (once per enemy).

var alarms: int = 0
var _spotters: Dictionary[int, bool] = {}


func clears_on_kill_all() -> bool:
	return false


func exit_open_from_start() -> bool:
	return true


func player_exited() -> bool:
	_complete()
	return true


func setup(objective_config: ObjectiveConfig, terrain_grid: TerrainGrid, the_player: Player,
		waves: WaveManager, health: TerrainHealth) -> void:
	super(objective_config, terrain_grid, the_player, waves, health)
	wave_manager.alert_on_spawn = false


func wave_started(wave: int) -> void:
	super(wave)
	alarms = 0
	_spotters.clear()


func tick(_delta: float) -> void:
	if state != State.ACTIVE:
		return
	for e: Enemy in wave_manager.alive:
		if e.awareness.state != Awareness.State.CHASE or _spotters.has(e.get_instance_id()):
			continue
		_spotters[e.get_instance_id()] = true
		alarms += 1
		credit(e, config.alarm_points)
		if alarms > config.alarms_allowed:
			_fail("you were spotted")
			return


func hud_text() -> String:
	return "Reach the exit unseen   alarms %d / %d" % [alarms, config.alarms_allowed] if state == State.ACTIVE else ""

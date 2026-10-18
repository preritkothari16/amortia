class_name StealthObjective
extends Objective
## Stealth (GDD 8.2): reach the exit without raising an alarm. An alarm = an enemy sees the
## player (its Awareness enters CHASE: suspicion full, or within 2 tiles, GDD 4.3). The exit is
## open from the start; walking out is the wave goal. Enemies are NOT told the player's spawn
## position (no spawn Pulse).
## Recovery (Reactive Survival V1, V2): once more than alarms_allowed enemies raised an alarm, any
## enemy seeing the player starts a SPOTTED countdown. If no enemy sees the player when it ends
## (hid, broke line of sight, or shot the spotter) it was a close call; if one still does, the
## level fails. Close calls are unlimited, but each one shortens the next countdown
## (grace_for(escapes): alarm_grace_seconds - alarm_grace_step per escape, never below
## alarm_grace_min), and every enemy that saw the player stays wary (Awareness.wary_seconds).
## Objective fitness O: the enemy that raises an alarm earns alarm_points (once per enemy).

var alarms: int = 0
## Seconds left of the SPOTTED countdown (< 0 = not running).
var grace_left: float = -1.0
## Close calls survived this wave.
var escapes_used: int = 0
var _spotters: Dictionary[int, bool] = {}
## Seconds the "close call" note stays on the HUD.
var _close_call_note: float = 0.0


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
	grace_left = -1.0
	escapes_used = 0
	_close_call_note = 0.0
	_spotters.clear()


func tick(delta: float) -> void:
	if state != State.ACTIVE:
		return
	_close_call_note = maxf(_close_call_note - delta, 0.0)
	var seen: bool = false
	for e: Enemy in wave_manager.alive:
		if e.awareness.state != Awareness.State.CHASE:
			continue
		seen = true
		if not _spotters.has(e.get_instance_id()):
			_spotters[e.get_instance_id()] = true
			alarms += 1
			credit(e, config.alarm_points)
	if grace_left >= 0.0:
		grace_left -= delta
		if grace_left > 0.0:
			return
		grace_left = -1.0
		if seen:
			_fail("you were spotted")
			return
		escapes_used += 1
		_close_call_note = 2.5
		return
	if seen and alarms > config.alarms_allowed:
		if config.alarm_grace_seconds > 0.0:
			grace_left = grace_for(escapes_used)
		else:
			_fail("you were spotted")


## Length of the SPOTTED countdown after `escapes` close calls this wave: 3 -> 2.5 -> 2 -> 1.5 s ...
func grace_for(escapes: int) -> float:
	return maxf(config.alarm_grace_seconds - config.alarm_grace_step * escapes,
			minf(config.alarm_grace_min, config.alarm_grace_seconds))


## Highest suspicion of any enemy that does not see the player yet (HUD warning).
func strongest_suspicion() -> float:
	var top: float = 0.0
	for e: Enemy in wave_manager.alive:
		if e.awareness.state != Awareness.State.CHASE:
			top = maxf(top, e.awareness.suspicion)
	return top


func hud_text() -> String:
	if state != State.ACTIVE:
		return ""
	if grace_left >= 0.0:
		return "SPOTTED! Break line of sight   %.1f s" % grace_left
	var text: String = "Reach the exit unseen   close calls %d (next %.1f s)" % [
		escapes_used, grace_for(escapes_used)]
	if _close_call_note > 0.0:
		text += "   - close call!"
	elif strongest_suspicion() >= 0.5:
		text += "   - something noticed you"
	return text

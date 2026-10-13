class_name LevelFlow
extends Node
## Wave-to-wave area progression for a campaign level (expansion phase 5, GDD 8.1):
##
##   ENTERING  player stands at the area's left entry; enemies arrive after the opening delay
##             (barricades may be placed with B); part of waves 2+ comes from behind
##   FIGHTING  the wave is on; it ends when its goal is met (all dead, or the objective's goal)
##             -> scored and bred by the WaveManager as always
##   CLEARED   the right-hand exit gate opens; the player may stay to pick up samples / scrap;
##             after straggler_delay_seconds stragglers come, faster and faster (not scored)
##   EXITED    player walked through the exit -> Wave Report (+ skill tree) -> Continue loads the
##             next area variant and the next wave; after the level's last wave -> COMPLETE
##
## Separation of concerns: the WaveManager owns waves, scoring and evolution; this node only
## sequences areas around it. Losing a wave (player down, objective failed) uses the same
## fail_wave() -> Game Over -> Retry path as the prototype; Retry reloads this area fresh
## (barricades and terrain changes don't carry over) and replays the same wave. A player
## downed AFTER the wave was cleared keeps the cleared wave: the report opens and play goes on
## from the next area.

enum Phase { ENTERING, FIGHTING, CLEARED, EXITED, COMPLETE }

signal level_completed
signal phase_changed(phase: Phase)

var config: LevelConfig
var main: Node  # world/main.gd (load_area, terrain_health, terrain_grid)
var wave_manager: WaveManager
var player: Player
var report: WaveReport
var objective: Objective

var phase: Phase = Phase.ENTERING:
	set(value):
		if phase != value:
			phase = value
			phase_changed.emit(phase)
## 0-based index into config.areas of the current area, and waves finished in this level.
var area_index: int = 0
var waves_done: int = 0
## Barricades left to place in this area's opening.
var barricades_left: int = 0
## Seconds until the first / next straggler (< 0 = not counting).
var straggler_left: float = -1.0
var straggler_interval: float = 0.0
var stragglers_spawned: int = 0

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func setup(level: LevelConfig, level_main: Node, waves: WaveManager, the_player: Player,
		wave_report: WaveReport, level_objective: Objective, seed_value: int) -> void:
	config = level
	main = level_main
	wave_manager = waves
	player = the_player
	report = wave_report
	objective = level_objective
	_rng.seed = seed_value
	wave_manager.wave_started.connect(_on_wave_started)
	wave_manager.enemies_arrived.connect(func(_w: int) -> void: phase = Phase.FIGHTING)
	wave_manager.generation_bred.connect(func(_s: Dictionary) -> void: _on_wave_done())
	wave_manager.wave_restarting.connect(_on_wave_restarting)
	report.auto_open = false
	report.drives_wave_manager = false
	report.continue_pressed.connect(_on_report_continue)
	player.died.connect(_on_player_died, CONNECT_DEFERRED)
	player.build_requested.connect(_on_build_requested)
	EventBus.enemy_killed.connect(_on_enemy_killed)
	if objective != null:
		objective.goal_reached.connect(_on_goal_reached)
		objective.failed.connect(_on_objective_failed)
		objective.area_loaded(main.current_map())


func _on_wave_started(_wave: int) -> void:
	phase = Phase.ENTERING
	barricades_left = config.barricades_per_wave
	straggler_left = -1.0
	stragglers_spawned = 0
	if objective != null:
		objective.wave_started(waves_done + 1)
		if objective.exit_open_from_start():
			main.open_exit()


func _physics_process(delta: float) -> void:
	if objective != null and (phase == Phase.ENTERING or phase == Phase.FIGHTING):
		objective.tick(delta)
	match phase:
		Phase.CLEARED:
			_tick_stragglers(delta)
			_check_exit()
		Phase.FIGHTING, Phase.ENTERING:
			if objective != null and objective.exit_open_from_start():
				_check_exit()


## The wave was scored and bred (all enemies dead, or the objective's goal -> end_wave()).
func _on_wave_done() -> void:
	if phase == Phase.EXITED or phase == Phase.COMPLETE:
		return
	if objective != null:
		objective.wave_ended()
	phase = Phase.CLEARED
	waves_done += 1
	main.open_exit()
	straggler_left = config.straggler_delay_seconds
	straggler_interval = config.straggler_interval_start


func _on_goal_reached() -> void:
	if wave_manager.is_wave_running():
		wave_manager.end_wave()  # survivors are scored as survivors, then bred


func _on_objective_failed(reason: String) -> void:
	print("[Objective] failed: %s" % reason)
	if wave_manager.is_wave_running():
		wave_manager.fail_wave()  # Game Over -> Retry the same wave, no evolution


func _tick_stragglers(delta: float) -> void:
	straggler_left -= delta
	if straggler_left > 0.0:
		return
	if wave_manager.spawn_straggler() != null:
		stragglers_spawned += 1
	straggler_interval = maxf(straggler_interval * config.straggler_interval_factor, config.straggler_interval_min)
	straggler_left = straggler_interval


func _check_exit() -> void:
	if player.is_dead:
		return
	if player.global_position.distance_to(main.current_map().get_exit()) <= 20.0 \
			or main.terrain_grid.coords.world_to_cell(player.global_position).x >= main.terrain_grid.width - 2:
		_on_exited()


func _on_exited() -> void:
	if phase == Phase.FIGHTING or phase == Phase.ENTERING:
		# Stealth: walking out IS the goal.
		if objective != null:
			objective._complete()
		if wave_manager.is_wave_running():
			wave_manager.end_wave()
		if objective == null:
			return
	wave_manager.clear_enemies()  # stragglers
	if waves_done >= config.waves:
		phase = Phase.COMPLETE
		level_completed.emit()
		return
	phase = Phase.EXITED
	report.open_last()


func _on_report_continue() -> void:
	if phase != Phase.EXITED:
		return
	area_index += 1
	main.load_area(config.areas[area_index % config.areas.size()])
	if objective != null:
		objective.area_loaded(main.current_map())
	wave_manager.use_behind_spawns = true
	wave_manager.continue_to_next_wave()


## Retry: the same area again, fresh (no barricades, no burnt grass), same wave.
func _on_wave_restarting(_wave: int) -> void:
	main.load_area(config.areas[area_index % config.areas.size()])
	if objective != null:
		objective.retry()
		objective.area_loaded(main.current_map())


## Downed after the wave was already done: it stays done (see class comment).
func _on_player_died() -> void:
	if phase == Phase.CLEARED:
		player.revive()
		_on_exited()


func _on_build_requested(cell: Vector2i) -> void:
	if phase != Phase.ENTERING or barricades_left <= 0:
		return
	if main.terrain_health.place(cell, "barricade"):
		barricades_left -= 1


## Kills drop samples and scrap (GDD 7.5 / 7.6) - also during the straggler phase.
func _on_enemy_killed(enemy: Node2D) -> void:
	var at: Vector2 = enemy.global_position
	if _rng.randf() < config.sample_chance:
		main.call_deferred("add_child", Pickup.create(&"sample", 1, at + Vector2(-3, 0)))
	var scrap: int = _rng.randi_range(config.scrap_min, config.scrap_max)
	if scrap > 0:
		main.call_deferred("add_child", Pickup.create(&"scrap", scrap, at + Vector2(3, 2)))


## HUD line for the current phase.
func status_text() -> String:
	var obj: String = objective.hud_text() if objective != null else ""
	var head: String = "Wave %d / %d   " % [mini(waves_done + (0 if phase == Phase.CLEARED or phase == Phase.EXITED else 1), config.waves), config.waves]
	match phase:
		Phase.ENTERING:
			var t: float = wave_manager.arrival_seconds_left()
			var build: String = "   B: barricade (%d left)" % barricades_left if barricades_left > 0 else ""
			return head + "They're coming in %.1f s%s   %s" % [t, build, obj]
		Phase.FIGHTING:
			return head + (obj if obj != "" else "Clear the wave   %d left" % wave_manager.alive.size())
		Phase.CLEARED:
			var s: String = "stragglers in %d s" % ceili(straggler_left) if stragglers_spawned == 0 \
					else "stragglers incoming!"
			return head + "Exit open - go right (%s)   samples %d  scrap %d" % [s, GameState.samples, GameState.scrap]
		Phase.COMPLETE:
			return "Level complete!"
	return ""

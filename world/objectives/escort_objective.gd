class_name EscortObjective
extends Objective
## Escort (GDD 8.2): bring a survivor from the entry to the exit. Survivor at the exit (same
## rule as the player: near the exit marker or in the last two columns) = wave goal; the player
## walking out alone completes nothing. The exit is open from the start.
## Commands (Reactive Survival V1, key: input action "escort_command"):
##   FOLLOW  walks to the player along a threat-aware route (SafePath, re-planned every
##           REPLAN_SECONDS) and stops escort_follow_distance short; waits while the player is
##           more than escort_leash away. Player standing at the exit: walks into the exit.
##   WAIT    stays where it is
## Whatever the command, an enemy within escort_flee_radius makes it back away, towards the player.
## Enemies hunt the survivor: one that perceives it (the player's sight rules) scores HuntSurvivor
## and walks to it (Enemy._hunt_survivor_seek). Only the escort_max_attackers nearest enemies within
## reach hit it, each with its own cooldown and ferocity-scaled damage.
## Recovery: the first time its HP reaches 0 in a wave it goes DOWN (no damage, enemies lose
## interest) for escort_downed_seconds; standing next to it for escort_revive_seconds revives it
## with part of its HP. Down time over, or 0 HP again that wave = level fail (Retry).
## Objective fitness O: each enemy is credited with the damage IT did to the survivor.

enum Mode { FOLLOW, WAIT }

const REACH: float = 14.0
const REPLAN_SECONDS: float = 0.5
## Distance (px) from the exit marker that counts as out (LevelFlow uses the same for the player).
const EXIT_RADIUS: float = 20.0

var survivor: Vector2 = Vector2.ZERO
var survivor_health: float = 0.0
var mode: Mode = Mode.FOLLOW
## True while backing away from an enemy this frame.
var scared: bool = false
## Recovery state: down (0 HP, waiting for a revive), seconds left, revive progress (seconds
## the player has stood next to it), and how often it went down this wave.
var downed: bool = false
var downed_left: float = 0.0
var revive_progress: float = 0.0
var downs: int = 0
var _safe_path: SafePath = SafePath.new()
var _path: Array[Vector2i] = []
var _path_index: int = 0
var _replan_left: float = 0.0
var _planned_goal: Vector2i = Vector2i(-9999, -9999)
## Enemy instance id -> seconds until it may hit the survivor again.
var _cooldowns: Dictionary[int, float] = {}
var _hit_flash: float = 0.0


func clears_on_kill_all() -> bool:
	return false


func exit_open_from_start() -> bool:
	return true


func setup(objective_config: ObjectiveConfig, terrain_grid: TerrainGrid, the_player: Player,
		waves: WaveManager, health: TerrainHealth) -> void:
	super(objective_config, terrain_grid, the_player, waves, health)
	waves.set_escort(self)


## The survivor can be seen (and hunted) while the objective runs, it has HP and is not down.
func is_survivor_alive() -> bool:
	return state == State.ACTIVE and survivor_health > 0.0 and not downed


func area_loaded(zone_map: ZoneMap) -> void:
	super(zone_map)
	_place()


func wave_started(wave: int) -> void:
	super(wave)
	survivor_health = config.escort_health
	mode = Mode.FOLLOW
	downed = false
	downs = 0
	revive_progress = 0.0
	_cooldowns.clear()
	_place()


func _place() -> void:
	if map == null:
		return
	var start: Vector2i = grid.coords.world_to_cell(map.get_entry()) + Vector2i(1, 0)
	survivor = grid.coords.cell_to_world(start)
	_path.clear()
	_replan_left = 0.0
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if state == State.ACTIVE and event.is_action_pressed("escort_command"):
		toggle_mode()
		get_viewport().set_input_as_handled()


## FOLLOW <-> WAIT.
func toggle_mode() -> void:
	mode = Mode.WAIT if mode == Mode.FOLLOW else Mode.FOLLOW
	_path.clear()
	_replan_left = 0.0


func tick(delta: float) -> void:
	if state != State.ACTIVE:
		return
	_hit_flash = maxf(_hit_flash - delta, 0.0)
	if downed:
		_tick_downed(delta)
		queue_redraw()
		return
	_move(delta)
	# Enemies next to the survivor hit it.
	for id: int in _cooldowns.keys():
		_cooldowns[id] -= delta
	for e: Enemy in nearest_attackers():
		var id: int = e.get_instance_id()
		if _cooldowns.get(id, 0.0) > 0.0:
			continue
		_cooldowns[id] = e.stats.attack_cooldown
		var dmg: float = minf(config.escort_hit_damage * e.attack_scale, survivor_health)
		survivor_health -= dmg
		_hit_flash = 0.3
		credit(e, dmg)
	queue_redraw()
	if survivor_health <= 0.0:
		_go_down()
	elif at_exit():
		_complete()


## Survivor out: near the exit marker or in the last two columns (as for the player).
func at_exit() -> bool:
	if map == null:
		return false
	return survivor.distance_to(map.get_exit()) <= EXIT_RADIUS \
			or grid.coords.world_to_cell(survivor).x >= grid.width - 2


# --- Movement ------------------------------------------------------------------------

## The player is in the exit zone (LevelFlow's rule): the survivor then heads for the exit.
func _player_at_exit() -> bool:
	return player.global_position.distance_to(map.get_exit()) <= EXIT_RADIUS * 1.5 			or grid.coords.world_to_cell(player.global_position).x >= grid.width - 2


func _move(delta: float) -> void:
	scared = false
	var step: float = config.escort_speed * delta
	var threat: Enemy = _nearest_enemy_within(config.escort_flee_radius)
	if threat != null:
		scared = true
		var away: Vector2 = threat.global_position.direction_to(survivor)
		var towards: Vector2 = survivor.direction_to(player.global_position)
		for dir: Vector2 in [(away + towards * 0.6).normalized(), away]:
			if _try_step(dir * step):
				return
		return
	if mode == Mode.WAIT:
		return
	var to_player: float = survivor.distance_to(player.global_position)
	if to_player > config.escort_leash:
		return
	# Following: up to the player, stopping short - unless the player stands at the exit (the map
	# edge, nowhere further to go): then into the exit itself.
	var target: Vector2 = player.global_position
	if _player_at_exit():
		target = map.get_exit()
	elif to_player <= config.escort_follow_distance:
		return
	var goal: Vector2i = grid.coords.world_to_cell(target)
	_replan_left -= delta
	if _replan_left <= 0.0 or _path.is_empty() or goal != _planned_goal:
		_plan(goal)
	if _path.is_empty():
		_try_step(survivor.direction_to(target) * step)  # no route: straight, if walkable
		return
	while _path_index < _path.size() and survivor.distance_to(grid.coords.cell_to_world(_path[_path_index])) < 1.0:
		_path_index += 1
	if _path_index >= _path.size():
		return
	survivor = survivor.move_toward(grid.coords.cell_to_world(_path[_path_index]), step)


## Plans the threat-aware route from the survivor's cell to `goal`.
func _plan(goal: Vector2i) -> void:
	_replan_left = REPLAN_SECONDS
	_planned_goal = goal
	_path = _safe_path.find(grid, grid.coords.world_to_cell(survivor), goal, known_threats())
	_path_index = 1


## Cells of the enemies the survivor can see: within escort_threat_sight, clear grid line.
func known_threats() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for e: Enemy in wave_manager.alive:
		if e.global_position.distance_to(survivor) <= config.escort_threat_sight \
				and grid.has_line_of_sight(survivor, e.global_position):
			cells.append(grid.coords.world_to_cell(e.global_position))
	return cells


## Moves by `offset` if the cell there is walkable for the survivor. Returns true if it moved.
func _try_step(offset: Vector2) -> bool:
	if offset == Vector2.ZERO:
		return false
	var target: Vector2 = survivor + offset
	if not SafePath.walkable(grid, grid.coords.world_to_cell(target)):
		return false
	survivor = target
	return true


func _nearest_enemy_within(radius: float) -> Enemy:
	var best: Enemy = null
	var best_d: float = radius
	for e: Enemy in wave_manager.alive:
		var d: float = e.global_position.distance_to(survivor)
		if d <= best_d:
			best = e
			best_d = d
	return best


# --- Recovery ------------------------------------------------------------------------

func _go_down() -> void:
	downs += 1
	survivor_health = 0.0
	if downs > 1 or config.escort_downed_seconds <= 0.0:
		_fail("the survivor died")
		return
	downed = true
	downed_left = config.escort_downed_seconds
	revive_progress = 0.0
	_cooldowns.clear()


func _tick_downed(delta: float) -> void:
	downed_left -= delta
	if survivor.distance_to(player.global_position) <= config.escort_revive_radius:
		revive_progress += delta
	else:
		revive_progress = maxf(revive_progress - delta, 0.0)
	if revive_progress >= config.escort_revive_seconds:
		downed = false
		survivor_health = config.escort_health * config.escort_revive_health_ratio
		_path.clear()
	elif downed_left <= 0.0:
		_fail("the survivor died")


## Enemies within reach of the survivor, nearest first, at most escort_max_attackers of them.
## None while it is down.
func nearest_attackers() -> Array[Enemy]:
	var near: Array[Enemy] = []
	if downed:
		return near
	for e: Enemy in wave_manager.alive:
		if e.global_position.distance_to(survivor) <= REACH:
			near.append(e)
	near.sort_custom(func(a: Enemy, b: Enemy) -> bool:
		return a.global_position.distance_squared_to(survivor) < b.global_position.distance_squared_to(survivor))
	if near.size() > config.escort_max_attackers:
		near.resize(config.escort_max_attackers)
	return near


## Enemies going for the survivor right now (warning before the first hit).
func hunters() -> int:
	var n: int = 0
	for e: Enemy in wave_manager.alive:
		if e.brain != null and e.brain.current == UtilityAction.Type.HUNT_SURVIVOR and e.survivor_visible:
			n += 1
	return n


# --- Display -------------------------------------------------------------------------

## Short state word shown above the survivor and in the HUD.
func status_word() -> String:
	if downed:
		return "DOWN"
	if scared:
		return "SCARED"
	if mode == Mode.WAIT:
		return "WAITING"
	if survivor.distance_to(player.global_position) > config.escort_leash:
		return "LOST YOU"
	return "FOLLOWING"


func hud_text() -> String:
	if state != State.ACTIVE:
		return ""
	if downed:
		return "SURVIVOR DOWN! Stand next to it to revive   %.1f s" % maxf(downed_left, 0.0)
	var text: String = "Escort the survivor to the exit   HP %d/%d   %s %s" % [
		ceili(survivor_health), roundi(config.escort_health), status_word(), KeyHint.tag(&"escort_command")]
	var n: int = hunters()
	if n > 0:
		text += "   HUNTED by %d!" % n
	return text


func _draw() -> void:
	if map == null or state == State.INACTIVE:
		return
	var body: Color = Color(1.0, 0.85, 0.3)
	if downed:
		body = Color(0.5, 0.5, 0.5)
	elif _hit_flash > 0.0:
		body = Color(1, 0.3, 0.3)
	elif scared:
		body = Color(1.0, 0.55, 0.2)
	draw_circle(survivor, 4.0, body)
	draw_arc(survivor, 5.5, 0.0, TAU, 16, Color(1, 1, 1, 0.6), 1.0)
	var top: Vector2 = survivor + Vector2(-8, -9)
	if downed:
		var r: float = clampf(revive_progress / config.escort_revive_seconds, 0.0, 1.0) if config.escort_revive_seconds > 0.0 else 0.0
		draw_rect(Rect2(top, Vector2(16, 2)), Color(0, 0, 0, 0.7))
		draw_rect(Rect2(top, Vector2(16 * r, 2)), Color(0.5, 0.8, 1.0))
		draw_arc(survivor, config.escort_revive_radius, 0.0, TAU, 24, Color(0.5, 0.8, 1.0, 0.5), 1.0)
	else:
		var ratio: float = survivor_health / config.escort_health if config.escort_health > 0.0 else 0.0
		draw_rect(Rect2(top, Vector2(16, 2)), Color(0, 0, 0, 0.7))
		draw_rect(Rect2(top, Vector2(16 * ratio, 2)), Color(0.4, 1, 0.4))
	var font: Font = ThemeDB.fallback_font
	var word: String = status_word()
	var at: Vector2 = survivor + Vector2(-font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, 7).x * 0.5, -12)
	draw_string_outline(font, at, word, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, 2, Color.BLACK)
	draw_string(font, at, word, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, body if not downed else Color(0.7, 0.85, 1.0))

class_name EscortObjective
extends Objective
## Escort (GDD 8.2): bring a survivor from the entry to the exit. Survivor at the exit (same
## rule as the player: near the exit marker or in the last two columns) = wave goal; the player
## walking out alone completes nothing. The exit is open from the start.
## Commands (Reactive Survival V1, V2; input actions "escort_command" = E, "escort_run" = R):
##   FOLLOW  walks to the player along a threat-aware route (SafePath, re-planned every
##           REPLAN_SECONDS) and stops escort_follow_distance short; waits while the player is
##           more than escort_leash away. Player standing at the exit: walks into the exit.
##   WAIT    stays where it was told to wait (comes back there after hiding)
##   RUN     sprints to the exit along the threat-aware route, wherever the player is. Uses
##           stamina (empty -> FOLLOW) and makes a noise every escort_run_noise_interval.
## E: FOLLOW <-> WAIT (RUN -> FOLLOW). R: RUN <-> FOLLOW.
## Threatened (an enemy it can see closing in within escort_threat_radius, or any enemy within
## escort_flee_radius), it never fights: it runs to the best reachable cover (CoverFinder: out of
## every threat's sight or in tall grass, reached before the threats) and hides there until no
## enemy has seen it for escort_hide_seconds (also after running to the player or backing away).
## No cover: to the player if that route stays clear of the threats, else it backs away. Tall grass hides it beyond 2 tiles unless it is running.
## Enemies hunt the survivor: one that perceives it (the player's sight rules) scores HuntSurvivor
## and walks to it (Enemy._hunt_survivor_seek). Only the escort_max_attackers nearest enemies within
## reach hit it, each with its own cooldown and ferocity-scaled damage.
## 0 HP = level fail at once (Retry). No revive (Reactive Survival V2).
## Objective fitness O: each enemy is credited with the damage IT did to the survivor.

enum Mode { FOLLOW, WAIT, RUN }
## What the survivor does about a threat: nothing, heads for cover, runs to the player, backs away.
enum Retreat { NONE, COVER, TO_PLAYER, BACK_AWAY }

const REACH: float = 14.0
const REPLAN_SECONDS: float = 0.5
## Distance (px) from the exit marker that counts as out (LevelFlow uses the same for the player).
const EXIT_RADIUS: float = 20.0
## An enemy counts as closing in when it moves towards the survivor at least this fast (px/s).
const CLOSING_SPEED: float = 10.0

var survivor: Vector2 = Vector2.ZERO
var survivor_health: float = 0.0
var mode: Mode = Mode.FOLLOW
## Seconds of running left (escort_stamina_seconds when rested).
var stamina: float = 0.0
## True while threatened this frame.
var scared: bool = false
## True while sprinting on the Run command this frame (loud, not hidden by grass).
var running: bool = false
var retreat: Retreat = Retreat.NONE
## The cover being used (CoverFinder.NONE = none).
var cover_cell: Vector2i = CoverFinder.NONE
## Seconds since an enemy last saw or threatened the survivor.
var since_seen: float = INF
var _wait_spot: Vector2 = Vector2.ZERO
var _safe_path: SafePath = SafePath.new()
var _cover_finder: CoverFinder = CoverFinder.new()
var _path: Array[Vector2i] = []
var _path_index: int = 0
var _replan_left: float = 0.0
var _planned_goal: Vector2i = Vector2i(-9999, -9999)
var _noise_left: float = 0.0
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
	_cover_finder.max_steps = config.escort_cover_max_steps
	_cover_finder.min_threat_gap_cells = config.escort_cover_gap_cells
	_cover_finder.mover_speed = config.escort_run_speed
	_cover_finder.threat_speed = config.escort_threat_speed
	_cover_finder.margin_seconds = config.escort_cover_margin
	_cover_finder.player_weight = config.escort_cover_player_weight


## The survivor can be seen (and hunted) while the objective runs and it has HP.
func is_survivor_alive() -> bool:
	return state == State.ACTIVE and survivor_health > 0.0


## Hidden from enemies beyond their sense radius: standing or walking in tall grass, not running.
func is_survivor_concealed() -> bool:
	return not running and grid != null and grid.conceals(grid.coords.world_to_cell(survivor))


func area_loaded(zone_map: ZoneMap) -> void:
	super(zone_map)
	_place()


func wave_started(wave: int) -> void:
	super(wave)
	survivor_health = config.escort_health
	mode = Mode.FOLLOW
	stamina = config.escort_stamina_seconds
	_cooldowns.clear()
	_place()


func _place() -> void:
	if map == null:
		return
	var start: Vector2i = grid.coords.world_to_cell(map.get_entry()) + Vector2i(1, 0)
	survivor = grid.coords.cell_to_world(start)
	_wait_spot = survivor
	_end_retreat()
	running = false
	scared = false
	since_seen = INF
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if state != State.ACTIVE:
		return
	if event.is_action_pressed("escort_command"):
		toggle_mode()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("escort_run"):
		toggle_run()
		get_viewport().set_input_as_handled()


## E: FOLLOW <-> WAIT; a running survivor goes back to FOLLOW.
func toggle_mode() -> void:
	if mode == Mode.FOLLOW:
		mode = Mode.WAIT
		_wait_spot = survivor
	else:
		mode = Mode.FOLLOW
	_path.clear()
	_replan_left = 0.0


## R: RUN <-> FOLLOW. A run only starts with at least escort_run_min_stamina left. Returns true
## if the survivor is running now.
func toggle_run() -> bool:
	if mode == Mode.RUN:
		mode = Mode.FOLLOW
	elif stamina >= config.escort_run_min_stamina:
		mode = Mode.RUN
	_path.clear()
	_replan_left = 0.0
	return mode == Mode.RUN


func tick(delta: float) -> void:
	if state != State.ACTIVE:
		return
	_hit_flash = maxf(_hit_flash - delta, 0.0)
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
		survivor_health = 0.0
		_fail("the survivor died")
	elif at_exit():
		_complete()


## Survivor out: near the exit marker or in the last two columns (as for the player).
func at_exit() -> bool:
	if map == null:
		return false
	return survivor.distance_to(map.get_exit()) <= EXIT_RADIUS \
			or grid.coords.world_to_cell(survivor).x >= grid.width - 2


## True while the survivor stands in its cover.
func is_hiding() -> bool:
	return retreat == Retreat.COVER and grid.coords.world_to_cell(survivor) == cover_cell


# --- Movement ------------------------------------------------------------------------

## The player is in the exit zone (LevelFlow's rule): the survivor then heads for the exit.
func _player_at_exit() -> bool:
	return player.global_position.distance_to(map.get_exit()) <= EXIT_RADIUS * 1.5 \
			or grid.coords.world_to_cell(player.global_position).x >= grid.width - 2


func _move(delta: float) -> void:
	running = false
	scared = threatened()
	if scared or _seen_by_enemy():
		since_seen = 0.0
	else:
		since_seen += delta
	if scared:
		_retreat(delta)
	elif retreat != Retreat.NONE and since_seen < config.escort_hide_seconds:
		# Shaken: stays put (finishing the way into its cover) until nobody has seen it for a while,
		# so it doesn't walk straight back into the enemy it just got away from.
		if retreat == Retreat.COVER:
			_follow_path(config.escort_run_speed * delta)
	else:
		if retreat != Retreat.NONE:
			_end_retreat()
		match mode:
			Mode.RUN:
				_run(delta)
			Mode.WAIT:
				if survivor.distance_to(_wait_spot) > 2.0:
					_go_to(_wait_spot, config.escort_speed * delta, delta)
			Mode.FOLLOW:
				_follow(delta)
	if not running:
		stamina = minf(stamina + config.escort_stamina_refill * delta, config.escort_stamina_seconds)


## FOLLOW: up to the player, stopping short - unless the player stands at the exit (the map edge,
## nowhere further to go): then into the exit itself. Waits while the player is too far away.
func _follow(delta: float) -> void:
	var to_player: float = survivor.distance_to(player.global_position)
	if to_player > config.escort_leash:
		return
	var target: Vector2 = player.global_position
	if _player_at_exit():
		target = map.get_exit()
	elif to_player <= config.escort_follow_distance:
		return
	_go_to(target, config.escort_speed * delta, delta)


## RUN: sprint to the exit, using stamina and making noise. Out of stamina -> FOLLOW.
func _run(delta: float) -> void:
	if stamina <= 0.0:
		mode = Mode.FOLLOW
		_follow(delta)
		return
	running = true
	stamina = maxf(stamina - delta, 0.0)
	_noise_left -= delta
	if _noise_left <= 0.0:
		_noise_left = config.escort_run_noise_interval
		if config.escort_run_noise_radius > 0.0:
			EventBus.noise_emitted.emit(survivor, config.escort_run_noise_radius)
	_go_to(map.get_exit(), config.escort_run_speed * delta, delta)


## Threatened: re-chooses where to go every REPLAN_SECONDS - the best cover; without one the
## player, if the safe route there keeps 2 cells from every threat; else straight away from the
## nearest enemy (biased towards the player). Moves at escort_run_speed, without stamina or noise.
func _retreat(delta: float) -> void:
	var step: float = config.escort_run_speed * delta
	_replan_left -= delta
	if retreat == Retreat.NONE or _replan_left <= 0.0:
		_replan_left = REPLAN_SECONDS
		var threats: Array[Vector2i] = _threat_cells()
		var here: Vector2i = grid.coords.world_to_cell(survivor)
		var player_cell: Vector2i = grid.coords.world_to_cell(player.global_position)
		cover_cell = _cover_finder.find(grid, here, threats, player_cell)
		if cover_cell != CoverFinder.NONE:
			retreat = Retreat.COVER
			_set_path(_cover_finder.last_path, cover_cell)
		else:
			var to_player: Array[Vector2i] = _safe_path.find(grid, here, player_cell, threats)
			if not to_player.is_empty() and _keeps_clear(to_player, threats):
				retreat = Retreat.TO_PLAYER
				_set_path(to_player, player_cell)
			else:
				retreat = Retreat.BACK_AWAY
				_path.clear()
	if retreat == Retreat.BACK_AWAY:
		var threat: Enemy = _nearest_enemy_within(config.escort_threat_radius)
		if threat == null:
			return
		var away: Vector2 = threat.global_position.direction_to(survivor)
		var towards: Vector2 = survivor.direction_to(player.global_position)
		for dir: Vector2 in [(away + towards * 0.6).normalized(), away]:
			if _try_step(dir * step):
				return
		return
	if retreat == Retreat.TO_PLAYER and survivor.distance_to(player.global_position) <= config.escort_follow_distance:
		return
	_follow_path(step)


## Every cell of `path` is at least 2 cells from every threat.
static func _keeps_clear(path: Array[Vector2i], threats: Array[Vector2i]) -> bool:
	for c: Vector2i in path:
		for t: Vector2i in threats:
			if Vector2(c - t).length() < 2.0:
				return false
	return true


func _end_retreat() -> void:
	retreat = Retreat.NONE
	cover_cell = CoverFinder.NONE
	_path.clear()
	_replan_left = 0.0


## Walks the threat-aware route to `target`, re-planned every REPLAN_SECONDS or when the goal
## cell changes.
func _go_to(target: Vector2, step: float, delta: float) -> void:
	var goal: Vector2i = grid.coords.world_to_cell(target)
	_replan_left -= delta
	if _replan_left <= 0.0 or _path.is_empty() or goal != _planned_goal:
		_replan_left = REPLAN_SECONDS
		_set_path(_safe_path.find(grid, grid.coords.world_to_cell(survivor), goal, _threat_cells()), goal)
	if _path.is_empty():
		_try_step(survivor.direction_to(target) * step)  # no route: straight, if walkable
		return
	_follow_path(step)


func _set_path(path: Array[Vector2i], goal: Vector2i) -> void:
	_path = path
	_path_index = 1
	_planned_goal = goal


## One step of `step` px along the current route.
func _follow_path(step: float) -> void:
	while _path_index < _path.size() and survivor.distance_to(grid.coords.cell_to_world(_path[_path_index])) < 1.0:
		_path_index += 1
	if _path_index >= _path.size():
		return
	survivor = survivor.move_toward(grid.coords.cell_to_world(_path[_path_index]), step)


## Cells of the enemies the survivor can see (within escort_threat_sight, clear grid line), plus
## any enemy within escort_flee_radius (heard right next to it).
func _threat_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for e: Enemy in wave_manager.alive:
		var d: float = e.global_position.distance_to(survivor)
		if d <= config.escort_flee_radius or (d <= config.escort_threat_sight
				and grid.has_line_of_sight(survivor, e.global_position)):
			cells.append(grid.coords.world_to_cell(e.global_position))
	return cells


## The cells of the threats the routes avoid (also used by tests).
func known_threats() -> Array[Vector2i]:
	return _threat_cells()


## An enemy within escort_flee_radius, or one in clear line within escort_threat_radius that is
## moving towards the survivor.
func threatened() -> bool:
	for e: Enemy in wave_manager.alive:
		var d: float = e.global_position.distance_to(survivor)
		if d <= config.escort_flee_radius:
			return true
		if d <= config.escort_threat_radius and e.velocity.dot(e.global_position.direction_to(survivor)) >= CLOSING_SPEED \
				and grid.has_line_of_sight(survivor, e.global_position):
			return true
	return false


func _seen_by_enemy() -> bool:
	for e: Enemy in wave_manager.alive:
		if e.survivor_visible:
			return true
	return false


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


## Enemies within reach of the survivor, nearest first, at most escort_max_attackers of them.
func nearest_attackers() -> Array[Enemy]:
	var near: Array[Enemy] = []
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
	if is_hiding():
		return "HIDING"
	if retreat == Retreat.COVER:
		return "TAKING COVER"
	if retreat != Retreat.NONE:
		return "SCARED"
	if mode == Mode.RUN:
		return "RUNNING"
	if mode == Mode.WAIT:
		return "WAITING"
	if survivor.distance_to(player.global_position) > config.escort_leash:
		return "LOST YOU"
	return "FOLLOWING"


## Stamina as a 6-segment text bar, e.g. "####--".
func stamina_bar() -> String:
	var full: int = roundi(6.0 * stamina / config.escort_stamina_seconds) if config.escort_stamina_seconds > 0.0 else 0
	return "#".repeat(full) + "-".repeat(6 - full)


func hud_text() -> String:
	if state != State.ACTIVE:
		return ""
	var text: String = "Escort  HP %d/%d  %s  stamina %s  %s %s %s %s" % [
		ceili(survivor_health), roundi(config.escort_health), status_word(), stamina_bar(),
		KeyHint.tag(&"escort_command"), "wait" if mode == Mode.FOLLOW else "follow",
		KeyHint.tag(&"escort_run"), "follow" if mode == Mode.RUN else "run"]
	var n: int = hunters()
	if n > 0:
		text += "   HUNTED by %d!" % n
	return text


func _draw() -> void:
	if map == null or state == State.INACTIVE:
		return
	var body: Color = Color(1.0, 0.85, 0.3)
	if _hit_flash > 0.0:
		body = Color(1, 0.3, 0.3)
	elif retreat != Retreat.NONE:
		body = Color(1.0, 0.55, 0.2)
	if is_survivor_concealed():
		body = Color(body, 0.55)  # hidden in the grass
	draw_circle(survivor, 4.0, body)
	draw_arc(survivor, 5.5, 0.0, TAU, 16, Color(1, 1, 1, 0.6), 1.0)
	var top: Vector2 = survivor + Vector2(-8, -9)
	var ratio: float = survivor_health / config.escort_health if config.escort_health > 0.0 else 0.0
	draw_rect(Rect2(top, Vector2(16, 2)), Color(0, 0, 0, 0.7))
	draw_rect(Rect2(top, Vector2(16 * ratio, 2)), Color(0.4, 1, 0.4))
	if stamina < config.escort_stamina_seconds and config.escort_stamina_seconds > 0.0:
		draw_rect(Rect2(top + Vector2(0, 3), Vector2(16, 1)), Color(0, 0, 0, 0.7))
		draw_rect(Rect2(top + Vector2(0, 3), Vector2(16 * stamina / config.escort_stamina_seconds, 1)), Color(0.5, 0.8, 1.0))
	if retreat == Retreat.COVER and not is_hiding():
		draw_arc(grid.coords.cell_to_world(cover_cell), 5.0, 0.0, TAU, 12, Color(1.0, 0.55, 0.2, 0.6), 1.0)
	var font: Font = ThemeDB.fallback_font
	var word: String = status_word()
	var at: Vector2 = survivor + Vector2(-font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, 7).x * 0.5, -12)
	draw_string_outline(font, at, word, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, 2, Color.BLACK)
	draw_string(font, at, word, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, body)

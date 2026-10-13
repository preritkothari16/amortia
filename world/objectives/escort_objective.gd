class_name EscortObjective
extends Objective
## Escort (GDD 8.2): a survivor walks from the entry to the exit along the shortest walk the
## PLAYER could take (no fences, no water). It waits whenever the player is more than
## escort_leash away. Enemies within reach of it hit it (their attack damage... no: the
## config's escort_hit_damage, on each enemy's own attack cooldown). Survivor dead = level
## fail (Retry); survivor at the exit = wave goal. The exit is open from the start, but the
## player walking out alone completes nothing.
## Objective fitness O: each enemy is credited with the damage IT did to the survivor.
## Not done: enemies don't steer towards the survivor (that is a utility-AI action, a later
## step); they hit it when it is next to them, which happens because it walks with the player.

const REACH: float = 14.0

var survivor: Vector2 = Vector2.ZERO
var survivor_health: float = 0.0
var _path: Array[Vector2i] = []
var _path_index: int = 0
## Enemy instance id -> seconds until it may hit the survivor again.
var _cooldowns: Dictionary[int, float] = {}


func clears_on_kill_all() -> bool:
	return false


func exit_open_from_start() -> bool:
	return true


func area_loaded(zone_map: ZoneMap) -> void:
	super(zone_map)
	_place()


func wave_started(wave: int) -> void:
	super(wave)
	survivor_health = config.escort_health
	_cooldowns.clear()
	_place()


func _place() -> void:
	if map == null:
		return
	var start: Vector2i = grid.coords.world_to_cell(map.get_entry()) + Vector2i(1, 0)
	survivor = grid.coords.cell_to_world(start)
	_path = walk_path(start, grid.coords.world_to_cell(map.get_exit()))
	_path_index = 1
	queue_redraw()


func tick(delta: float) -> void:
	if state != State.ACTIVE:
		return
	# Walk, unless the player fell behind.
	if survivor.distance_to(player.global_position) <= config.escort_leash and _path_index < _path.size():
		var goal: Vector2 = grid.coords.cell_to_world(_path[_path_index])
		survivor = survivor.move_toward(goal, config.escort_speed * delta)
		if survivor.distance_to(goal) < 1.0:
			_path_index += 1
	# Enemies next to the survivor hit it.
	for id: int in _cooldowns.keys():
		_cooldowns[id] -= delta
	for e: Enemy in wave_manager.alive:
		if e.global_position.distance_to(survivor) > REACH:
			continue
		var id: int = e.get_instance_id()
		if _cooldowns.get(id, 0.0) > 0.0:
			continue
		_cooldowns[id] = e.stats.attack_cooldown
		var dmg: float = minf(config.escort_hit_damage, survivor_health)
		survivor_health -= dmg
		credit(e, dmg)
	queue_redraw()
	if survivor_health <= 0.0:
		_fail("the survivor died")
	elif _path_index >= _path.size() and not _path.is_empty():
		_complete()


func hud_text() -> String:
	if state != State.ACTIVE:
		return ""
	var waiting: String = "  (waiting for you)" if survivor.distance_to(player.global_position) > config.escort_leash else ""
	return "Escort the survivor to the exit   HP %d%s" % [ceili(survivor_health), waiting]


func _draw() -> void:
	if map == null:
		return
	draw_circle(survivor, 4.0, Color(1.0, 0.85, 0.3))
	var ratio: float = survivor_health / config.escort_health if config.escort_health > 0.0 else 0.0
	draw_rect(Rect2(survivor + Vector2(-6, -9), Vector2(12 * ratio, 2)), Color(0.4, 1, 0.4))

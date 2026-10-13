class_name PurgeObjective
extends Objective
## Purge nests (GDD 8.2): nest_count (3-5) nests sit at the area's first enemy spawn points
## and keep spawning stragglers (not scored) until destroyed. All nests destroyed = wave goal.
## Objective fitness O: each second an enemy spends within nest_guard_radius of a living nest
## while the player is within that radius too (it is guarding the nest) earns it 1 point.

var nests: Array[Nest] = []


func clears_on_kill_all() -> bool:
	return false


func area_loaded(zone_map: ZoneMap) -> void:
	super(zone_map)
	nests.clear()


func wave_started(wave: int) -> void:
	super(wave)
	_clear_props()
	nests.clear()
	var spawns: Array[Vector2] = map.get_enemy_spawns()
	for i: int in mini(config.nest_count, spawns.size()):
		var n: Nest = Nest.new()
		n.max_health = config.nest_health
		n.health = config.nest_health
		n.spawn_interval = config.nest_spawn_interval
		n.wave_manager = wave_manager
		n.position = grid.coords.cell_to_world(walkable_near(grid.coords.world_to_cell(spawns[i])))
		n.destroyed.connect(_on_nest_destroyed)
		add_child(n)
		nests.append(n)


func tick(delta: float) -> void:
	if state != State.ACTIVE:
		return
	var r2: float = config.nest_guard_radius * config.nest_guard_radius
	for n: Nest in nests:
		if player.global_position.distance_squared_to(n.global_position) > r2:
			continue
		for e: Enemy in wave_manager.alive:
			if e.global_position.distance_squared_to(n.global_position) <= r2:
				credit(e, delta)


func _on_nest_destroyed(nest: Nest) -> void:
	nests.erase(nest)
	if nests.is_empty():
		_complete()


func hud_text() -> String:
	return "Purge the nests   %d left" % nests.size() if state == State.ACTIVE else ""

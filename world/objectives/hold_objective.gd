class_name HoldObjective
extends Objective
## Hold the point (GDD 8.2): a radio point in the middle of the area must survive hold_seconds
## once the enemies arrive. Every enemy inside hold_radius damages it (point_damage_per_enemy
## per second); point HP 0 = lost (level fail -> Retry the wave). Kill-all doesn't end the
## wave: the timer does (enemies still alive then are scored as survivors).
## Objective fitness O: each enemy is credited with the damage IT did to the point.

var point: Vector2 = Vector2.ZERO
var point_health: float = 0.0
var hold_left: float = 0.0
var _running: bool = false


func clears_on_kill_all() -> bool:
	return false


func area_loaded(zone_map: ZoneMap) -> void:
	super(zone_map)
	var centre: Vector2i = Vector2i(grid.width / 2, grid.height / 2)
	point = grid.coords.cell_to_world(walkable_near(centre))
	queue_redraw()


func wave_started(wave: int) -> void:
	super(wave)
	point_health = config.point_health
	hold_left = config.hold_seconds
	_running = false


func tick(delta: float) -> void:
	if state != State.ACTIVE:
		return
	if not _running:
		_running = not wave_manager.is_arriving()
		return
	var r2: float = config.hold_radius * config.hold_radius
	for e: Enemy in wave_manager.alive:
		if e.global_position.distance_squared_to(point) <= r2:
			var dmg: float = minf(config.point_damage_per_enemy * delta, point_health)
			point_health -= dmg
			credit(e, dmg)
	queue_redraw()
	if point_health <= 0.0:
		_fail("the point was lost")
		return
	hold_left -= delta
	if hold_left <= 0.0:
		_complete()


func hud_text() -> String:
	if state != State.ACTIVE:
		return ""
	return "Hold the point  %d s   point HP %d" % [ceili(hold_left), ceili(point_health)]


func _draw() -> void:
	if map == null:
		return
	var ratio: float = point_health / config.point_health if config.point_health > 0.0 else 0.0
	draw_arc(point, config.hold_radius, 0.0, TAU, 48, Color(0.3, 0.8, 1.0, 0.6), 1.0)
	draw_rect(Rect2(point - Vector2(4, 4), Vector2(8, 8)), Color(0.3, 0.8, 1.0))
	draw_rect(Rect2(point + Vector2(-10, -10), Vector2(20 * ratio, 2)), Color(0.4, 1, 0.4))

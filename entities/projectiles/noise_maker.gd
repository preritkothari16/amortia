class_name NoiseMaker
extends Node2D
## A thrown noise-maker (Reactive Survival V1): flies from the player to its landing point,
## then makes one noise there (EventBus.noise_emitted) and fades out. Not an attack: it does no
## damage. Built in code by Player.throw_noise_maker (greybox, no scene).

signal landed(at: Vector2)

const RING_SECONDS: float = 0.6

var from: Vector2 = Vector2.ZERO
var to: Vector2 = Vector2.ZERO
var flight_time: float = 0.45
var noise_radius: float = 160.0
var has_landed: bool = false
var _t: float = 0.0
var _ring_left: float = 0.0


## Where a throw from `origin` towards `target` comes down: at most `max_range` away, and short
## of the first tile that blocks sight (walls, houses) on the way.
static func landing_point(grid: TerrainGrid, origin: Vector2, target: Vector2, max_range: float) -> Vector2:
	var offset: Vector2 = (target - origin).limit_length(max_range)
	var length: float = offset.length()
	if length < 1.0:
		return origin
	var dir: Vector2 = offset / length
	var best: Vector2 = origin
	var d: float = 4.0
	while d <= length:
		var p: Vector2 = origin + dir * d
		if not grid.has_line_of_sight(origin, p):
			break
		best = p
		d += 4.0
	if best != origin + offset and grid.has_line_of_sight(origin, origin + offset):
		best = origin + offset
	return best


func setup(start: Vector2, landing: Vector2, seconds: float, radius: float) -> void:
	from = start
	to = landing
	flight_time = maxf(seconds, 0.01)
	noise_radius = radius
	global_position = start
	z_index = 12


func _physics_process(delta: float) -> void:
	if has_landed:
		_ring_left -= delta
		queue_redraw()
		if _ring_left <= 0.0:
			queue_free()
		return
	_t = minf(_t + delta / flight_time, 1.0)
	global_position = from.lerp(to, _t)
	queue_redraw()
	if _t >= 1.0:
		has_landed = true
		_ring_left = RING_SECONDS
		EventBus.noise_emitted.emit(to, noise_radius)
		landed.emit(to)


func _draw() -> void:
	if has_landed:
		var k: float = clampf(_ring_left / RING_SECONDS, 0.0, 1.0)
		draw_arc(Vector2.ZERO, noise_radius * (1.0 - k * 0.7), 0.0, TAU, 48, Color(0.6, 0.9, 1.0, 0.5 * k), 1.0)
		draw_circle(Vector2.ZERO, 2.0, Color(0.6, 0.9, 1.0, k))
		return
	var lift: float = -10.0 * sin(PI * _t)  # a small arc so it reads as thrown
	draw_circle(Vector2(0, lift), 2.0, Color(0.6, 0.9, 1.0))

class_name AwarenessOverlay
extends Node2D
## Temporary debug view of the noise system and what each enemy knows. Toggle with F6.
##   white ring (fades)  noise radius of each shot
##   dot above an enemy  its state: red CHASE, yellow INVESTIGATE, orange SEARCH, grey IDLE
##   thin line           enemy -> its current target (where it is heading this frame)
##   cyan polyline       remaining A* path while investigating
##   yellow X            the enemy's last known player position (while not chasing)

const NOISE_SHOW_TIME: float = 1.0
const STATE_COLORS: Dictionary = {
	Awareness.State.IDLE: Color(0.6, 0.6, 0.6),
	Awareness.State.INVESTIGATE: Color(1, 0.9, 0.2),
	Awareness.State.SEARCH: Color(1, 0.55, 0.1),
	Awareness.State.CHASE: Color(1, 0.2, 0.2),
}

var wave_manager: WaveManager
var grid: TerrainGrid

## Recent noises: [position, radius, time left].
var _noises: Array[Array] = []


func _ready() -> void:
	visible = false
	z_index = 13
	EventBus.noise_emitted.connect(_on_noise_emitted)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_awareness"):
		visible = not visible


func _on_noise_emitted(noise_position: Vector2, radius: float) -> void:
	_noises.append([noise_position, radius, NOISE_SHOW_TIME])


func _process(delta: float) -> void:
	for noise: Array in _noises:
		noise[2] -= delta
	_noises = _noises.filter(func(n: Array) -> bool: return n[2] > 0.0)
	if visible:
		queue_redraw()


func _draw() -> void:
	for noise: Array in _noises:
		draw_arc(noise[0], noise[1], 0.0, TAU, 64, Color(1, 1, 1, 0.6 * noise[2] / NOISE_SHOW_TIME), 1.0)
	if wave_manager == null:
		return
	for enemy: Enemy in wave_manager.alive:
		var state: Awareness.State = enemy.awareness.state
		var color: Color = STATE_COLORS[state]
		var pos: Vector2 = enemy.global_position
		draw_circle(pos + Vector2(0, -9), 1.5, color)
		var path: Array[Vector2i] = enemy.get_debug_path()
		if not path.is_empty():
			var points: PackedVector2Array = PackedVector2Array([pos])
			for cell: Vector2i in path:
				points.append(grid.coords.cell_to_world(cell))
			draw_polyline(points, Color(0.3, 0.9, 1, 0.6), 1.0)
		if enemy.current_target != Vector2.INF:
			draw_line(pos, enemy.current_target, Color(color, 0.35), 1.0)
		var known: Vector2 = enemy.awareness.last_known
		if state != Awareness.State.CHASE and known != Vector2.INF:
			draw_line(known + Vector2(-3, -3), known + Vector2(3, 3), Color(1, 0.9, 0.2))
			draw_line(known + Vector2(3, -3), known + Vector2(-3, 3), Color(1, 0.9, 0.2))

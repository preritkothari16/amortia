class_name BossAura
extends Node2D
## Pulsing ring and soft disc under an Apex boss (visual only; child of the enemy's Body, so it
## is scaled with the boss).

const RADIUS: float = 9.0


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var pulse: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * 4.0)
	draw_circle(Vector2.ZERO, RADIUS, Color(0.8, 0.1, 0.5, 0.18 + 0.1 * pulse))
	draw_arc(Vector2.ZERO, RADIUS + pulse, 0.0, TAU, 28, Color(1.0, 0.35, 0.8, 0.8), 1.0)

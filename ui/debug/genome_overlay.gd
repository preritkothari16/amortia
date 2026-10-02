class_name GenomeOverlay
extends Node2D
## Debug view of each enemy's genome. Toggle with F7.
##   "6/4/5"  speed / health / vision genes (rounded)
##   bar      aggression (red), flanking (magenta), patience (yellow), 0..1 each
##   "F .21"  fitness so far (as if the wave ended now)

var wave_manager: WaveManager


func _ready() -> void:
	visible = false
	z_index = 14


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_genome"):
		visible = not visible


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func _draw() -> void:
	if wave_manager == null:
		return
	var font: Font = ThemeDB.fallback_font
	for enemy: Enemy in wave_manager.alive:
		var g: Genome = enemy.genome
		if g == null:
			continue
		var pos: Vector2 = enemy.global_position
		draw_string(font, pos + Vector2(-8, 14), "%d/%d/%d" % [roundi(g.speed), roundi(g.health), roundi(g.vision)],
				HORIZONTAL_ALIGNMENT_LEFT, -1, 6, Color.WHITE)
		if enemy.fitness_record != null:
			draw_string(font, pos + Vector2(-8, 28), "F %.2f" % wave_manager.preview_fitness(enemy.fitness_record),
					HORIZONTAL_ALIGNMENT_LEFT, -1, 6, Color(0.6, 1, 0.6))
		var genes: Array[float] = [g.aggression, g.flanking, g.patience]
		var colors: Array[Color] = [Color(1, 0.3, 0.3), Color.MAGENTA, Color(1, 0.9, 0.2)]
		for i: int in 3:
			draw_rect(Rect2(pos + Vector2(-6, 16 + i * 2), Vector2(12 * genes[i], 1)), colors[i])

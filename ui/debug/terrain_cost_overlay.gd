class_name TerrainCostOverlay
extends Node2D
## Debug view of a TerrainGrid: tints every cell by its movement cost. Toggle with F1.
## Green = cost 1, yellow = cost 2, orange = 3+, red cross = impassable.

var grid: TerrainGrid:
	set(value):
		grid = value
		queue_redraw()


func _ready() -> void:
	visible = false
	z_index = 10


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_overlay"):
		visible = not visible


func _draw() -> void:
	if grid == null:
		return
	var size: Vector2 = Vector2(grid.tile_size, grid.tile_size)
	for y: int in grid.height:
		for x: int in grid.width:
			var cell: Vector2i = Vector2i(x, y)
			var top_left: Vector2 = Vector2(cell * grid.tile_size)
			var cost: float = grid.get_cost(cell)
			if cost == INF:
				draw_line(top_left, top_left + size, Color(1, 0.2, 0.2, 0.6))
				draw_line(top_left + Vector2(size.x, 0), top_left + Vector2(0, size.y), Color(1, 0.2, 0.2, 0.6))
			else:
				draw_rect(Rect2(top_left + Vector2.ONE, size - Vector2(2, 2)), _cost_color(cost))


func _cost_color(cost: float) -> Color:
	if cost <= 1.0:
		return Color(0.2, 1, 0.3, 0.25)
	if cost <= 2.0:
		return Color(1, 0.95, 0.2, 0.4)
	return Color(1, 0.5, 0.1, 0.55)

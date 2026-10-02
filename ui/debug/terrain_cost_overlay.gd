class_name TerrainCostOverlay
extends Node2D
## Debug view of a TerrainGrid: tints every cell by its movement cost. Toggle with F1.
## Green = cost 1, yellow = cost 2, orange = 3+, red cross = impassable.

var grid: TerrainGrid:
	set(value):
		grid = value
		queue_redraw()
## Which mover's costs to show. null = the grid's base profile.
var profile: TerrainCostProfile:
	set(value):
		profile = value
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
	var cross: Color = Color(1, 0.2, 0.2, 0.6)
	for y: int in grid.height:
		for x: int in grid.width:
			var cell: Vector2i = Vector2i(x, y)
			var rect: Rect2 = grid.coords.cell_rect(cell)
			var cost: float = grid.get_cost(cell, profile)
			if cost == INF:
				draw_line(rect.position, rect.end, cross)
				draw_line(Vector2(rect.end.x, rect.position.y), Vector2(rect.position.x, rect.end.y), cross)
			else:
				draw_rect(rect.grow(-1.0), _cost_color(cost))


func _cost_color(cost: float) -> Color:
	if cost <= 1.0:
		return Color(0.2, 1, 0.3, 0.25)
	if cost <= 2.0:
		return Color(1, 0.95, 0.2, 0.4)
	return Color(1, 0.5, 0.1, 0.55)

class_name FlowFieldOverlay
extends Node2D
## Debug view of a FlowField: one arrow per reachable tile pointing to its next cell.
## Colour = integration cost (yellow near the target, blue far away).
## Magenta dot = walkable tile that cannot reach the target. Toggle with F2.

## Cost at which arrows reach the "far" colour.
const FAR_COST: float = 40.0
const NEAR_COLOR: Color = Color(1, 0.9, 0.2, 0.9)
const FAR_COLOR: Color = Color(0.3, 0.5, 1, 0.9)

var field: FlowField


func _ready() -> void:
	visible = false
	z_index = 11


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_flow_field"):
		visible = not visible
		queue_redraw()


## Call after field.build() so the arrows update.
func refresh() -> void:
	if visible:
		queue_redraw()


func _draw() -> void:
	if field == null or not field.is_built():
		return
	var grid: TerrainGrid = field.grid
	var half: float = grid.coords.tile_size * 0.35
	for y: int in grid.height:
		for x: int in grid.width:
			var cell: Vector2i = Vector2i(x, y)
			var centre: Vector2 = grid.coords.cell_to_world(cell)
			if cell == field.target:
				draw_circle(centre, 3.0, Color.WHITE)
				continue
			if not field.is_reachable(cell):
				if grid.is_walkable(cell, field.profile):
					draw_circle(centre, 1.5, Color.MAGENTA)
				continue
			var t: float = clampf(field.get_cost(cell) / FAR_COST, 0.0, 1.0)
			_draw_arrow(centre, field.get_direction(cell), half, NEAR_COLOR.lerp(FAR_COLOR, t))


func _draw_arrow(centre: Vector2, dir: Vector2, half: float, color: Color) -> void:
	var tip: Vector2 = centre + dir * half
	draw_line(centre - dir * half, tip, color)
	draw_line(tip, tip - dir.rotated(0.5) * 3.0, color)
	draw_line(tip, tip - dir.rotated(-0.5) * 3.0, color)

class_name TerrainCostOverlay
extends Node2D
## Debug view of a TerrainGrid: tints every cell by its movement cost. F1: base costs, then
## each flow-field bucket's costs, then off.
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


## Optional: F1 then steps through every terrain-profile bucket in use (base first), so
## adapted costs (a climber's cheap fences...) can be inspected. Label shows the bucket.
var flow_fields: FlowFieldSet
var _profile_index: int = 0


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("debug_overlay"):
		return
	var profiles: Array[TerrainCostProfile] = flow_fields.get_profiles() if flow_fields != null else []
	if not visible:
		visible = true
		_profile_index = 0
	else:
		_profile_index += 1
		if _profile_index >= maxi(profiles.size(), 1):
			visible = false
			_profile_index = 0
	profile = profiles[_profile_index] if _profile_index < profiles.size() and _profile_index > 0 else null


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()  # terrain can change at runtime; label follows the camera


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
	var name: String = profile.label if profile != null else "base costs"
	var cam: Camera2D = get_viewport().get_camera_2d()
	var at: Vector2 = cam.get_screen_center_position() + Vector2(-230, 120) if cam != null else Vector2(4, 260)
	draw_string(ThemeDB.fallback_font, at, "F1 costs: " + name.left(90), HORIZONTAL_ALIGNMENT_LEFT, -1, 6, Color.WHITE)


func _cost_color(cost: float) -> Color:
	if cost <= 1.0:
		return Color(0.2, 1, 0.3, 0.25)
	if cost <= 2.0:
		return Color(1, 0.95, 0.2, 0.4)
	return Color(1, 0.5, 0.1, 0.55)

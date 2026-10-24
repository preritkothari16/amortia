class_name TerrainView
extends Node2D
## Keeps the visible / physical map in step with the TerrainGrid at runtime, and draws what the
## TileMap can't: overlays (fog, fire), event warnings (blinking outlines, GDD 4.1 rule 5) and
## damage on destructible tiles. Greybox only.
##   grid.terrain_changed -> the TileMapLayer cell gets the new terrain's tile (and collision)

## Seconds between redraws of overlays / warnings.
const REDRAW_INTERVAL: float = 0.1

var grid: TerrainGrid:
	set(value):
		grid = value
		if grid != null:
			grid.terrain_changed.connect(_on_terrain_changed)
var layer: TileMapLayer
var rules: TerrainCosts
## Optional: source of warnings and fire.
var events: TerrainEvents
var health: TerrainHealth
## Look of fog overlay cells (Atmosphere sets the zone's fog colour). Visual only.
var fog_color: Color = Color(0.85, 0.87, 0.9, 0.45)

## Terrain name -> atlas column (index in rules.definitions).
var _column: Dictionary[String, int] = {}
var _redraw_left: float = 0.0
var _time: float = 0.0


func _ready() -> void:
	z_index = 2


func _process(delta: float) -> void:
	_time += delta
	_redraw_left -= delta
	if _redraw_left <= 0.0:
		_redraw_left = REDRAW_INTERVAL
		queue_redraw()


func _on_terrain_changed(cells: Array[Vector2i], _affects_cost: bool) -> void:
	if layer == null or rules == null or cells.is_empty():
		return  # a whole-map reload repaints the layer itself
	if _column.is_empty():
		for i: int in rules.definitions.size():
			_column[rules.definitions[i].id] = i
	for cell: Vector2i in cells:
		var terrain: String = grid.get_terrain(cell)
		if _column.has(terrain):
			layer.set_cell(cell, 0, Vector2i(_column[terrain], 0))
	queue_redraw()


func _draw() -> void:
	if grid == null:
		return
	var blink: bool = fmod(_time, 0.4) < 0.2
	for y: int in grid.height:
		for x: int in grid.width:
			var cell: Vector2i = Vector2i(x, y)
			var overlay: String = grid.get_overlay(cell)
			if overlay == "":
				continue
			var rect: Rect2 = grid.coords.cell_rect(cell)
			if overlay == "fog":
				draw_rect(rect, fog_color)
				# Sparse brighter wisps, fixed per cell, so a bank reads as mist and not a flat block.
				for i: int in 6:
					var h: int = (x * 73 + y * 151 + i * 37) % 256
					draw_rect(Rect2(rect.position + Vector2(h % 16, (h / 16) % 16), Vector2(2, 1)), Color(fog_color, fog_color.a * 0.8))
			elif overlay == "fire":
				draw_rect(rect, Color(1.0, 0.45, 0.1, 0.75) if blink else Color(1.0, 0.8, 0.2, 0.75))
	if events != null:
		for w: Array in events.all_warnings():
			var rect: Rect2 = grid.coords.cell_rect(w[0]).grow(-1.0)
			var color: Color = w[2]
			draw_rect(rect, Color(color, 0.85 if blink else 0.35), false, 1.0)
	if health != null:
		for cell: Vector2i in health.damaged_cells():
			var rect: Rect2 = grid.coords.cell_rect(cell)
			var d: TerrainDefinition = grid.get_definition(cell)
			if d != null and d.max_health > 0.0:
				var ratio: float = health.health_of(cell) / d.max_health
				draw_rect(Rect2(rect.position + Vector2(2, 1), Vector2(12 * ratio, 1)), Color(1, 0.85, 0.3))

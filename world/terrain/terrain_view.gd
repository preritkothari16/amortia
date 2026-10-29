class_name TerrainView
extends Node2D
## Keeps the visible / physical map in step with the TerrainGrid at runtime, and draws what the
## TileMap can't: overlays (fog, fire), event warnings (blinking outlines, GDD 4.1 rule 5) and
## damage on destructible tiles. Greybox only.
##   grid.terrain_changed -> the TileMapLayer cell gets the new terrain's tile (and collision)
## Damage states of fences / doors / barricades (TerrainHealth decides HP and when they break):
## intact (hit flash + HP strip only), cracked (<= 2/3 HP), heavily damaged (<= 1/3 HP: deep cracks,
## holes, splinters), destroyed (CombatFx throws dust and leaves rubble on the now-open cell).

## Seconds between redraws of overlays / warnings.
const REDRAW_INTERVAL: float = 0.1
## Seconds a destructible tile flashes after a hit.
const HIT_FLASH_TIME: float = 0.12

enum DamageStage { INTACT, CRACKED, HEAVY }

var grid: TerrainGrid:
	set(value):
		grid = value
		if grid != null:
			grid.terrain_changed.connect(_on_terrain_changed)
var layer: TileMapLayer
var rules: TerrainCosts
## Optional: source of warnings and fire.
var events: TerrainEvents
var health: TerrainHealth:
	set(value):
		health = value
		if health != null and not health.tile_destroyed.is_connected(_on_tile_destroyed):
			health.tile_destroyed.connect(_on_tile_destroyed)
## Look of fog overlay cells (Atmosphere sets the zone's fog colour). Visual only.
var fog_color: Color = Color(0.85, 0.87, 0.9, 0.45)

## Terrain name -> atlas column (index in rules.definitions).
var _column: Dictionary[String, int] = {}
var _redraw_left: float = 0.0
var _time: float = 0.0
## Destructible cells hit recently: cell -> flash seconds left.
var _flash: Dictionary[Vector2i, float] = {}


func _ready() -> void:
	z_index = 2
	EventBus.terrain_hit.connect(_on_terrain_hit)


## Which look a destructible tile with `ratio` of its HP left has.
static func damage_stage(ratio: float) -> DamageStage:
	if ratio <= 1.0 / 3.0:
		return DamageStage.HEAVY
	if ratio <= 2.0 / 3.0:
		return DamageStage.CRACKED
	return DamageStage.INTACT


func _on_terrain_hit(at: Vector2, _damage: float) -> void:
	if grid == null or health == null:
		return
	var cell: Vector2i = grid.coords.world_to_cell(at)
	if health.health_of(cell) > 0.0:
		_flash[cell] = HIT_FLASH_TIME


func _on_tile_destroyed(cell: Vector2i, terrain: String) -> void:
	_flash.erase(cell)
	var fx: CombatFx = get_tree().get_first_node_in_group(&"combat_fx") as CombatFx if is_inside_tree() else null
	if fx != null and grid != null:
		fx.tile_broken(grid.coords.cell_rect(cell), terrain)


func _process(delta: float) -> void:
	_time += delta
	_redraw_left -= delta
	if not _flash.is_empty():
		for cell: Vector2i in _flash.keys():
			_flash[cell] -= delta
			if _flash[cell] <= 0.0:
				_flash.erase(cell)
		_redraw_left = 0.0
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
				_draw_fog_cell(cell, rect)
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
				_draw_damage(cell, rect, health.health_of(cell) / d.max_health)
		for cell: Vector2i in _flash:
			draw_rect(grid.coords.cell_rect(cell), Color(1.0, 0.95, 0.85, 0.45 * _flash[cell] / HIT_FLASH_TIME))


## Cracks, holes and splinters for the tile's damage stage, plus a thin HP strip on top that goes
## from bone to blood red. Fixed per cell (seeded by the cell), so it doesn't crawl between redraws.
func _draw_damage(cell: Vector2i, rect: Rect2, ratio: float) -> void:
	var o: Vector2 = rect.position.floor()
	var stage: DamageStage = damage_stage(ratio)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash(cell)
	var crack: Color = Color(0.03, 0.03, 0.04, 0.95)
	var chip: Color = Color(0.92, 0.84, 0.66)  # fresh splintered wood / bare concrete, bright on purpose
	if stage != DamageStage.INTACT:
		draw_rect(rect, Color(0.25, 0.05, 0.03, 0.18 if stage == DamageStage.CRACKED else 0.32))
		var cracks: int = 2 if stage == DamageStage.CRACKED else 4
		for i: int in cracks:
			# A split from a point on the edge towards the middle, wandering a little, with bright
			# splinters along its lit side.
			var p: Vector2 = o + [Vector2(rng.randi_range(2, 13), 0), Vector2(15, rng.randi_range(2, 13)),
					Vector2(rng.randi_range(2, 13), 15), Vector2(0, rng.randi_range(2, 13))][i % 4]
			var dir: Vector2 = ((o + Vector2(8, 8)) - p).normalized()
			for step: int in rng.randi_range(6, 8) + (3 if stage == DamageStage.HEAVY else 0):
				draw_rect(Rect2(p.floor(), Vector2(2, 1) if step % 2 == 0 else Vector2.ONE), crack)
				if step % 2 == 1:
					draw_rect(Rect2(p.floor() + Vector2(-1, 0), Vector2.ONE), chip)
				p += (dir + Vector2(rng.randf_range(-0.7, 0.7), rng.randf_range(-0.7, 0.7))).normalized()
	if stage == DamageStage.HEAVY:
		# A chunk broken out of one corner (dark, so it still reads as part of the barrier) with a
		# jagged bright rim, two holes punched through, splinters sticking out.
		var right: bool = rng.randf() < 0.5
		var corner: Vector2 = o + Vector2(10 if right else 0, 0)
		draw_rect(Rect2(corner, Vector2(6, 6)), Color(0.03, 0.03, 0.04, 0.95))
		draw_rect(Rect2(corner + Vector2(0 if right else 1, 6), Vector2(5, 1)), chip)
		draw_rect(Rect2(corner + Vector2(-1 if right else 6, 1), Vector2(1, 4)), chip)
		for i: int in 2:
			var h: Vector2 = o + Vector2(rng.randi_range(3, 10), rng.randi_range(8, 12))
			draw_rect(Rect2(h, Vector2(3, 2)), Color(0.03, 0.03, 0.04))
			draw_rect(Rect2(h + Vector2(0, -1), Vector2(2, 1)), chip)
		for i: int in 3:
			draw_rect(Rect2(o + Vector2(rng.randi_range(1, 14), rng.randi_range(1, 14)), Vector2(1, 2)), chip)
	var strip: Color = Color(0.84, 0.8, 0.74).lerp(Color(0.64, 0.14, 0.16), 1.0 - ratio)
	draw_rect(Rect2(o + Vector2(2, -2), Vector2(12, 1)), Color(0, 0, 0, 0.6))
	draw_rect(Rect2(o + Vector2(2, -2), Vector2(maxf(12.0 * ratio, 1.0), 1)), strip)


## A fog cell is drawn in 4 px blocks whose alpha fades towards every side that borders a cell
## without fog, so a bank has soft edges instead of the hard square the cell grid would give.
func _draw_fog_cell(cell: Vector2i, rect: Rect2) -> void:
	var open: Array[bool] = [
		not _has_fog(cell + Vector2i.LEFT), not _has_fog(cell + Vector2i.RIGHT),
		not _has_fog(cell + Vector2i.UP), not _has_fog(cell + Vector2i.DOWN)]
	if not (open[0] or open[1] or open[2] or open[3]):
		draw_rect(rect, fog_color)
		return
	for by: int in 4:
		for bx: int in 4:
			var fade: float = 1.0
			if open[0]:
				fade = minf(fade, (bx + 0.5) / 4.0)
			if open[1]:
				fade = minf(fade, (3.5 - bx) / 4.0)
			if open[2]:
				fade = minf(fade, (by + 0.5) / 4.0)
			if open[3]:
				fade = minf(fade, (3.5 - by) / 4.0)
			draw_rect(Rect2(rect.position + Vector2(bx * 4, by * 4), Vector2(4, 4)),
					Color(fog_color, fog_color.a * clampf(fade, 0.0, 1.0)))


func _has_fog(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < grid.width and cell.y < grid.height 			and grid.get_overlay(cell) == "fog"

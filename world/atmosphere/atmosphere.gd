class_name Atmosphere
extends Node2D
## Look of the world (visual only): per-zone graded, lit ground (ground.gdshader) on the map's
## terrain layer, scattered ground decals, a fog / vignette overlay under the HUD, and the
## player's light pool. Combat feedback lives in the CombatFx child. main.gd calls setup() once
## and apply_map() for every map it loads. Never touches collision, AI or gameplay RNG.

const GROUND_SHADER: Shader = preload("res://world/atmosphere/ground.gdshader")
const OVERLAY_SHADER: Shader = preload("res://world/atmosphere/screen_overlay.gdshader")

@export var settings: VisualFxSettings

## Shared by the terrain layer, decals and corpses so they are lit and graded the same way.
var ground_material: ShaderMaterial
## Same grade plus the per-zone surfaces (roofs, walls, floors); only the terrain layer uses it.
var terrain_material: ShaderMaterial
var decals: GroundDecals
## Buildings, detail over the solid cells and their shadows (BuildingDetail), lamp pools (AmbientLights).
var buildings: BuildingDetail
var lights: AmbientLights
var combat: CombatFx

var _player: Node2D
var _camera: Camera2D
var _overlay: ShaderMaterial
var _zone: int = 1
var _flash_left: float = 0.0
var _hurt_left: float = 0.0


func setup(player: Node2D, zone: int) -> void:
	_player = player
	_zone = zone
	_camera = player.get_node_or_null("Camera2D") as Camera2D
	var i: int = settings.palette_index(zone)
	ground_material = ShaderMaterial.new()
	ground_material.shader = GROUND_SHADER
	ground_material.set_shader_parameter("tint", settings.zone_tint[i])
	ground_material.set_shader_parameter("shade", settings.zone_shade[i])
	ground_material.set_shader_parameter("darkness", settings.zone_darkness[i])
	ground_material.set_shader_parameter("saturation", settings.zone_saturation[i])
	ground_material.set_shader_parameter("light_radius", settings.light_radius)
	ground_material.set_shader_parameter("light_color", settings.light_color)
	terrain_material = ground_material.duplicate() as ShaderMaterial
	terrain_material.set_shader_parameter("restyle", 1.0)
	terrain_material.set_shader_parameter("zone", i)
	_build_overlay(settings.zone_fog[i], settings.zone_fog_amount[i])
	combat = CombatFx.new()
	combat.name = "CombatFx"
	add_child(combat)
	combat.setup(self, player, settings)


## Puts the graded ground on a freshly loaded map, scatters its decals and raises the buildings
## of the level's district (`level_id` = LevelConfig.id; "" = the zone's first district).
func apply_map(map: ZoneMap, grid: TerrainGrid, level_id: String = "") -> void:
	if ground_material == null:
		return
	var view: TerrainView = get_parent().get_node_or_null("TerrainView") as TerrainView
	if view != null:
		var fog: Color = _overlay.get_shader_parameter("fog_color")
		view.fog_color = Color(fog.r * 0.8, fog.g * 0.8, fog.b * 0.8, 0.32)
	_set_terrain_columns(map.terrain_layer)
	map.terrain_layer.material = terrain_material
	decals = GroundDecals.new()
	decals.name = "GroundDecals"
	decals.material = ground_material
	map.add_child(decals)
	decals.scatter(grid, settings.decal_density, hash(String(map.scene_file_path)), settings.max_splats, settings.palette_index(_zone))
	buildings = BuildingDetail.new()
	buildings.name = "BuildingDetail"
	buildings.material = ground_material
	map.add_child(buildings)
	var architecture: ArchitectureSettings = load(ArchitectureSettings.PATH) as ArchitectureSettings
	var district: DistrictStyle = architecture.district_for(level_id, _zone) if architecture != null else null
	buildings.setup(grid, settings.palette_index(_zone), hash(String(map.scene_file_path)) + 17, district)
	lights = AmbientLights.new()
	lights.name = "AmbientLights"
	map.add_child(lights)
	lights.setup(grid, settings, settings.palette_index(_zone), hash(String(map.scene_file_path)) + 29)
	lights.add_fires(buildings.fire_spots())


## Tells the terrain shader which atlas columns are roads, walls, houses... (the tileset's order
## is the TerrainCosts rulebook's order) and how many columns the atlas has.
func _set_terrain_columns(layer: TileMapLayer) -> void:
	var rules: TerrainCosts = load("res://data/terrain_costs.tres") as TerrainCosts
	var source: TileSetAtlasSource = layer.tile_set.get_source(0) as TileSetAtlasSource
	if rules == null or source == null or source.texture == null:
		return
	terrain_material.set_shader_parameter("columns", float(source.texture.get_width() / layer.tile_set.tile_size.x))
	for i: int in rules.definitions.size():
		match rules.definitions[i].id:
			"road": terrain_material.set_shader_parameter("col_road", float(i))
			"grass": terrain_material.set_shader_parameter("col_grass", float(i))
			"tall_grass": terrain_material.set_shader_parameter("col_tall", float(i))
			"wall": terrain_material.set_shader_parameter("col_wall", float(i))
			"house": terrain_material.set_shader_parameter("col_house", float(i))
			"fence": terrain_material.set_shader_parameter("col_fence", float(i))
			"door": terrain_material.set_shader_parameter("col_door", float(i))
			"door_open": terrain_material.set_shader_parameter("col_door_open", float(i))
			"barricade": terrain_material.set_shader_parameter("col_barricade", float(i))
			"tree": terrain_material.set_shader_parameter("col_tree", float(i))
			"living_wall": terrain_material.set_shader_parameter("col_living", float(i))
			"gate": terrain_material.set_shader_parameter("col_gate", float(i))


## Muzzle light on the ground for a moment.
func flash(at: Vector2) -> void:
	_flash_left = settings.muzzle_light_time
	ground_material.set_shader_parameter("flash_pos", at)
	terrain_material.set_shader_parameter("flash_pos", at)


func hurt_pulse() -> void:
	_hurt_left = settings.hurt_pulse_time


func _process(delta: float) -> void:
	if ground_material == null or _player == null:
		return
	_flash_left = maxf(_flash_left - delta, 0.0)
	for m: ShaderMaterial in [ground_material, terrain_material]:
		m.set_shader_parameter("light_pos", _player.global_position)
		m.set_shader_parameter("flash", _flash_left / settings.muzzle_light_time)
	_hurt_left = maxf(_hurt_left - delta, 0.0)
	_overlay.set_shader_parameter("hurt", _hurt_left / settings.hurt_pulse_time)
	if _camera != null:
		_overlay.set_shader_parameter("view_origin", _camera.get_screen_center_position())


## Fog and vignette on their own CanvasLayer, drawn after the world and before the HUD
## (same layer as the HUD, earlier in the tree). Ignores the mouse.
func _build_overlay(fog: Color, amount: float) -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = "AtmosphereOverlay"
	layer.layer = 1
	var rect: ColorRect = ColorRect.new()
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay = ShaderMaterial.new()
	_overlay.shader = OVERLAY_SHADER
	_overlay.set_shader_parameter("fog_color", fog)
	_overlay.set_shader_parameter("fog_amount", amount)
	_overlay.set_shader_parameter("vignette", settings.vignette)
	_overlay.set_shader_parameter("vignette_color", settings.vignette_color)
	var i: int = settings.palette_index(_zone)
	if i < settings.zone_mote_color.size() and i < settings.zone_mote_amount.size():
		_overlay.set_shader_parameter("mote_color", settings.zone_mote_color[i])
		_overlay.set_shader_parameter("mote_amount", settings.zone_mote_amount[i])
	_overlay.set_shader_parameter("view_size", get_viewport_rect().size)
	rect.material = _overlay
	layer.add_child(rect)
	add_child(layer)

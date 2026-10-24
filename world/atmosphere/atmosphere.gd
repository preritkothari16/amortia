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
var decals: GroundDecals
var combat: CombatFx

var _player: Node2D
var _camera: Camera2D
var _overlay: ShaderMaterial
var _flash_left: float = 0.0
var _hurt_left: float = 0.0


func setup(player: Node2D, zone: int) -> void:
	_player = player
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
	_build_overlay(settings.zone_fog[i], settings.zone_fog_amount[i])
	combat = CombatFx.new()
	combat.name = "CombatFx"
	add_child(combat)
	combat.setup(self, player, settings)


## Puts the graded ground on a freshly loaded map and scatters its decals.
func apply_map(map: ZoneMap, grid: TerrainGrid) -> void:
	if ground_material == null:
		return
	var view: TerrainView = get_parent().get_node_or_null("TerrainView") as TerrainView
	if view != null:
		var fog: Color = _overlay.get_shader_parameter("fog_color")
		view.fog_color = Color(fog.r * 0.8, fog.g * 0.8, fog.b * 0.8, 0.32)
	map.terrain_layer.material = ground_material
	decals = GroundDecals.new()
	decals.name = "GroundDecals"
	decals.material = ground_material
	map.add_child(decals)
	decals.scatter(grid, settings.decal_density, hash(String(map.scene_file_path)), settings.max_splats)


## Muzzle light on the ground for a moment.
func flash(at: Vector2) -> void:
	_flash_left = settings.muzzle_light_time
	ground_material.set_shader_parameter("flash_pos", at)


func hurt_pulse() -> void:
	_hurt_left = settings.hurt_pulse_time


func _process(delta: float) -> void:
	if ground_material == null or _player == null:
		return
	ground_material.set_shader_parameter("light_pos", _player.global_position)
	_flash_left = maxf(_flash_left - delta, 0.0)
	ground_material.set_shader_parameter("flash", _flash_left / settings.muzzle_light_time)
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
	_overlay.set_shader_parameter("view_size", get_viewport_rect().size)
	rect.material = _overlay
	layer.add_child(rect)
	add_child(layer)

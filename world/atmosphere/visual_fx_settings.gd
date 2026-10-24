class_name VisualFxSettings
extends Resource
## Look-only tuning: zone palettes, light, fog, decals, combat feedback. Edit data/visual_fx.tres.
## Nothing here changes gameplay (collision, AI, damage, timing).

@export_group("Zone palettes (index 0 = zone 1)")
## Multiplies the ground colour.
@export var zone_tint: Array[Color] = []
## What the ground fades to in the dark.
@export var zone_shade: Array[Color] = []
@export var zone_fog: Array[Color] = []
@export var zone_darkness: Array[float] = []
@export var zone_fog_amount: Array[float] = []
@export var zone_saturation: Array[float] = []

@export_group("Light")
## Radius of the player's light pool, world px.
@export var light_radius: float = 128.0
@export var light_color: Color = Color(1.0, 0.8, 0.58)
@export var vignette: float = 0.6

@export_group("Decals")
## Chance per walkable cell of a decal (cracks, debris, stains, leaves).
@export var decal_density: float = 0.22
## Seconds a corpse stays before fading; blood splats stay for the area.
@export var corpse_seconds: float = 8.0
@export var max_splats: int = 80

@export_group("Feedback")
## Camera shake (world px) per pistol shot / per shotgun shot / when hurt; decays in shake_time.
@export var shake_shot: float = 0.6
@export var shake_shotgun: float = 2.0
@export var shake_hurt: float = 2.5
@export var shake_time: float = 0.14
@export var muzzle_light_time: float = 0.07
@export var hurt_pulse_time: float = 0.35


func palette_index(zone: int) -> int:
	return clampi(zone - 1, 0, maxi(zone_tint.size() - 1, 0))

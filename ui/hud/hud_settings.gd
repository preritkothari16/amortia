class_name HudSettings
extends Resource
## In-game HUD tuning (steps 67-68). Edit data/hud.tres. Display only.

@export_group("Player status")
## HP ratio at or below which the HP bar and heart pulse.
@export_range(0.0, 1.0) var low_health_ratio: float = 0.3
## Seconds the HP bar rim and value flash after a hit.
@export var hurt_flash_seconds: float = 0.18

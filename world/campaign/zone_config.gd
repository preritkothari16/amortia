class_name ZoneConfig
extends Resource
## One campaign zone (GDD 3): its levels in order - three objective levels, then the Apex boss
## level - and its display name. The enemy population carries over between its levels.

@export_range(1, 4) var zone: int = 1
@export var title: String = ""
## Levels in play order; the last one is the zone's Apex boss level.
@export var levels: Array[LevelConfig] = []

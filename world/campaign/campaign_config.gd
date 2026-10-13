class_name CampaignConfig
extends Resource
## The campaign (GDD 8.1): 4 zones x (3 levels + 1 Apex) = 16 levels, Safehouse after each
## zone, goal: destroy the Seed (zone 4's Apex). Edit data/campaign/campaign.tres.

@export var zones: Array[ZoneConfig] = []
## A new zone's first population: this share of the previous zone's best genomes, the rest
## random (GDD 3: 20 % / 80 %).
@export_range(0.0, 1.0) var elite_carry_share: float = 0.2
## New Game+ (GDD 8.4: higher mutation rate): GA mutation rate x this.
@export var ng_plus_mutation_multiplier: float = 2.0


func level_count() -> int:
	var n: int = 0
	for z: ZoneConfig in zones:
		n += z.levels.size()
	return n


## Level `level_index` (0-based) of zone `zone` (1-based), or null.
func get_level(zone: int, level_index: int) -> LevelConfig:
	if zone < 1 or zone > zones.size():
		return null
	var levels: Array[LevelConfig] = zones[zone - 1].levels
	return levels[level_index] if level_index >= 0 and level_index < levels.size() else null

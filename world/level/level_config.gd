class_name LevelConfig
extends Resource
## One campaign level (GDD 8.1): which areas its waves are fought in, how many waves, its
## objective and terrain events, and the wave-to-wave pacing (expansion phase 5).
## Edit the .tres files in data/levels/. A level with no config runs the prototype loop.

@export var id: String = ""
@export var title: String = ""
## Zone 1 Maple Hollow, 2 Lowtide, 3 Greywood, 4 Sunnyseed Labs.
@export_range(1, 4) var zone: int = 1
## Area variants; wave n is fought in areas[(n - 1) % size]. Must have Exit / BehindSpawns markers.
@export var areas: Array[PackedScene] = []
## Generate the areas with the CSP generator instead (GDD 4.6). Area n uses seed
## generator_seed + n * 7919, so a level always plays the same layouts. Falls back to `areas`
## if generation fails.
@export var generator: LevelGenSettings
@export var generator_seed: int = 1
## Waves in this level (an Apex boss level has 1).
@export var waves: int = 3
## What the player has to do (null = survive the waves). See world/objectives.
@export var objective: ObjectiveConfig
## Dynamic terrain for this level (fire, tide, fog, day/night...).
@export var events: Array[TerrainEvent] = []
## Optional goals (challenges for bonus scrap; GDD 8.3).
@export var side_objectives: Array[SideObjective] = []

## The scene for area `index` (0-based): generated, or areas[index % size]. null if none.
func area_scene(index: int) -> PackedScene:
	if generator != null:
		var scene: PackedScene = GeneratedArea.build_scene(generator, generator_seed + index * 7919)
		if scene != null:
			return scene
	return areas[index % areas.size()] if not areas.is_empty() else null


func has_areas() -> bool:
	return generator != null or not areas.is_empty()


@export_group("Pacing")
## Seconds from entering an area until enemies arrive (barricade building time).
@export var spawn_delay_seconds: float = 3.0
## Share of waves 2+ that arrives from behind (the left edge).
@export_range(0.0, 1.0) var behind_fraction: float = 0.3
## After the wave is done, seconds until stragglers start coming.
@export var straggler_delay_seconds: float = 15.0
## Seconds between stragglers at first, shrinking by straggler_interval_factor each time
## down to straggler_interval_min (rising pressure the longer the player stays).
@export var straggler_interval_start: float = 6.0
@export var straggler_interval_min: float = 1.5
@export var straggler_interval_factor: float = 0.85
## Barricades the player may place per area, during the opening delay.
@export var barricades_per_wave: int = 3

@export_group("Pickups")
## Chance a killed enemy drops a sample (GDD 7.5); every kill drops scrap_min..scrap_max scrap.
@export_range(0.0, 1.0) var sample_chance: float = 0.5
@export var scrap_min: int = 1
@export var scrap_max: int = 3

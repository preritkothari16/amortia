class_name NoiseMakerSettings
extends Resource
## Tuning for the throwable noise-maker (Reactive Survival V1). Edit data/noise_maker.tres.
## It lands where it is thrown (a wall stops it) and makes ONE ordinary noise there: enemies that
## hear it learn only that spot (EventBus.noise_emitted -> Awareness.hear), never the player's
## position, and each decides by its own genes whether to go and look (InvestigateAction).

## Endless / prototype loop (no campaign level): the count the player gets at every wave.
@export var count_per_area: int = 2

@export_group("Campaign inventory (Reactive Survival V2)")
## Noise-makers at the start of a campaign level. They carry over between its areas; Retry gives
## back the count the wave started with. Not saved between levels.
@export var level_start_count: int = 2
## Most the player can carry. A refill pickup stays on the ground while the player is full.
@export var max_carried: int = 3
## Refill pickups (+1 each) placed per area: Stealth and Escort levels / every other level.
@export var refills_per_area_stealth_escort: int = 2
@export var refills_per_area: int = 1
## They lie on reachable cells this far (cells, straight line) from the area's entry...
@export var refill_min_cells: float = 10.0
@export var refill_max_cells: float = 40.0
## ...at least this far apart, preferring cells next to cover (tall grass or a sight blocker).
@export var refill_spacing_cells: float = 8.0
## Farthest throw (px). 128 = 8 tiles.
@export var max_range: float = 128.0
## Noise radius on landing (px). Pistol shot 192, dodge roll 64.
@export var noise_radius: float = 160.0
## Seconds in the air.
@export var flight_time: float = 0.45

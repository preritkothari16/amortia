class_name NoiseMakerSettings
extends Resource
## Tuning for the throwable noise-maker (Reactive Survival V1). Edit data/noise_maker.tres.
## It lands where it is thrown (a wall stops it) and makes ONE ordinary noise there: enemies that
## hear it learn only that spot (EventBus.noise_emitted -> Awareness.hear), never the player's
## position, and each decides by its own genes whether to go and look (InvestigateAction).

## How many the player gets at the start of each wave / area (and again on Retry).
@export var count_per_area: int = 2
## Farthest throw (px). 128 = 8 tiles.
@export var max_range: float = 128.0
## Noise radius on landing (px). Pistol shot 192, dodge roll 64.
@export var noise_radius: float = 160.0
## Seconds in the air.
@export var flight_time: float = 0.45

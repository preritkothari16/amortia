class_name PerceptionSettings
extends Resource
## Senses tuning shared by the player's noise and every enemy's sight and hearing (GDD 4.3,
## 4.4). Edit data/perception.tres, not this file. Numbers marked "proposal" were not in the
## design doc; they are first guesses, kept here so they can be tuned without code changes.

@export_group("Night (GDD 4.4)")
## Vision range lost at night for an enemy with night_sense 0 (GDD: -40 % for all).
@export_range(0.0, 1.0) var night_vision_penalty: float = 0.4
## Hearing radius bonus every enemy gets at night (GDD: "enemies get +sense of sound").
## Proposal: +25 %.
@export var night_hearing_bonus: float = 0.25
## Extra hearing bonus at night per point of night_sense (gene 1 = +50 % more). Proposal.
@export var night_sense_hearing_bonus: float = 0.5

@export_group("Stealth (GDD 4.3)")
## After a shot the player stays visible in cover this long (seconds). Proposal: 1.5 s.
@export var shot_exposure_seconds: float = 1.5

@export_group("Player noise")
## Footstep noise radius (px) for TerrainDefinition.NoiseLevel SILENT / QUIET / NORMAL / LOUD.
## Proposal: 0 / 1.5 / 3 / 6 tiles. LOUD covers mud and splashing through shallow water.
@export var footstep_radius_by_level: PackedFloat32Array = PackedFloat32Array([0.0, 24.0, 48.0, 96.0])
## Seconds between footstep noises while walking. Proposal.
@export var footstep_interval: float = 0.5
## Noise of a dodge roll ("running"), px. Proposal: 4 tiles.
@export var dodge_noise_radius: float = 64.0

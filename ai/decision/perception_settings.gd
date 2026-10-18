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

@export_group("Vision cone and suspicion (Reactive Survival V1)")
## Width of an enemy's field of view, degrees. 360 = sees all around (the rule before V1).
## Within sense_radius the player is noticed whatever the facing (GDD 4.3).
@export_range(30.0, 360.0) var view_cone_degrees: float = 120.0
## Seconds of uninterrupted sight that fill suspicion from 0 to 1: right outside sense_radius /
## at the edge of the sight range (linear in between). Full = the enemy sees you (CHASE).
@export var suspicion_fill_near: float = 0.5
@export var suspicion_fill_far: float = 1.8
## Fill speed multiplier for an enemy that is already investigating or searching.
@export var suspicion_alert_multiplier: float = 1.5
## Suspicion lost per second while the player is not in view.
@export var suspicion_decay_per_second: float = 0.5
## Crossing this level sends the enemy to check the spot of the glimpse (a lead, like a noise).
@export_range(0.0, 1.0) var suspicion_investigate_threshold: float = 0.5

@export_group("Enemy facing (Reactive Survival V1)")
## An idle enemy sweeps its gaze this many degrees (total) around its rest direction...
@export var idle_scan_degrees: float = 60.0
## ...once every idle_scan_period seconds. Searching enemies sweep wider and faster.
@export var idle_scan_period: float = 5.0
@export var search_scan_degrees: float = 140.0
@export var search_scan_period: float = 2.0
## How fast an enemy turns its gaze (degrees per second).
@export var turn_speed_degrees: float = 300.0

@export_group("Player noise")
## Footstep noise radius (px) for TerrainDefinition.NoiseLevel SILENT / QUIET / NORMAL / LOUD.
## Proposal: 0 / 1.5 / 3 / 6 tiles. LOUD covers mud and splashing through shallow water.
@export var footstep_radius_by_level: PackedFloat32Array = PackedFloat32Array([0.0, 24.0, 48.0, 96.0])
## Seconds between footstep noises while walking. Proposal.
@export var footstep_interval: float = 0.5
## Noise of a dodge roll ("running"), px. Proposal: 4 tiles.
@export var dodge_noise_radius: float = 64.0

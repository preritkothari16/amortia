class_name UtilitySettings
extends Resource
## Tuning for the utility AI that is the same for every enemy (the genes are separate, in
## BehaviourWeights). Edit data/utility_ai.tres, not this file.

## Seconds between decisions (0.2 = 5 Hz).
@export var decision_interval: float = 0.2
## Added to the current action's score so a rival must be clearly better (stops flickering).
@export var momentum_bonus: float = 0.1
## Score of doing nothing. Any action scoring below this is not worth doing.
@export var idle_score: float = 0.1

@export_group("Chase")
## Distance (px) at which "closeness" reaches 0.
@export var chase_range: float = 160.0
## Part of the chase score a visible player always gives, even far away (0..1).
@export var chase_base: float = 0.5

@export_group("Flank")
## Allies chasing needed for the full ally factor.
@export var flank_allies_needed: int = 2
## Allies within this distance (px) count for the ally factor.
@export var ally_radius: float = 128.0
## Below this distance (px) to the player flanking is pointless: just attack.
@export var flank_min_distance: float = 32.0
## Over this many px beyond flank_min_distance the distance factor ramps from 0 to 1.
@export var flank_distance_ramp: float = 48.0
## Part of the flank score given even when the player is looking at us (0..1).
@export var flank_facing_base: float = 0.4
## How far (px) from the player the flank point is.
@export var flank_point_distance: float = 40.0
## Angle (degrees) of the flank point from the direction the player faces (180 = right behind).
@export var flank_angle_degrees: float = 120.0
## Flank point must be standable (tile cost at most this) ...
@export var flank_max_tile_cost: float = 2.0
## ... and a short walk from the player (flow cost at most this).
@export var flank_max_path_cost: float = 5.0

@export_group("Investigate")
## Seconds after which a lead counts as completely stale.
@export var memory_time: float = 8.0
## Part of the investigate score even a stale lead keeps (0..1).
@export var investigate_base: float = 0.4
## How much a strong lead (e.g. a gunshot close by) makes up for low patience, 0..1.
## drive = patience + (1 - patience) * lead_strength * provocation_weight. 0 = patience only.
@export_range(0.0, 1.0) var provocation_weight: float = 1.0
## Provocation of losing sight of a chased player (the lead is where they were last seen).
@export_range(0.0, 1.0) var lost_sight_strength: float = 0.5
## Hunger ramp: a wave that drags on pulls even lazy enemies towards the lead they hold.
## Pressure is 0 until pressure_start_seconds of wave time, then rises linearly to 1 over
## pressure_ramp_seconds. A very large start turns the ramp off.
@export var pressure_start_seconds: float = 30.0
@export var pressure_ramp_seconds: float = 30.0

@export_group("Escort survivor")
## Weight of the survivor as a target next to the player (1 = as attractive at equal distance).
@export_range(0.0, 2.0) var survivor_priority: float = 1.0

@export_group("Pack (cohesion)")
## Allies this close (px) count as the pack and hear what a packmate saw.
@export var pack_radius: float = 128.0
## A pack is complete with this many members (the enemy itself included).
@export var pack_needed: int = 3
## Strength (0..1) of a lead shared by a packmate, before the cohesion of both is applied:
## strength = min(sender cohesion, receiver cohesion) * this.
@export_range(0.0, 1.0) var pack_share_strength: float = 0.8
## Seconds before the same enemy may call its pack again.
@export var pack_share_cooldown: float = 2.0
## Regroup score = cohesion * this, while the pack is incomplete (it competes with Chase).
@export_range(0.0, 1.0) var regroup_base: float = 0.7
## Closer to the player than this (px) an enemy just fights instead of regrouping.
@export var regroup_min_distance: float = 64.0
## Packmates up to this far (px) are worth regrouping with.
@export var regroup_search_radius: float = 192.0
## Most seconds one enemy may spend regrouping per chase. Spent time is only forgiven after
## regroup_reset_seconds without seeing the player, so flickering sight can't restart it.
@export var regroup_timeout: float = 4.0
@export var regroup_reset_seconds: float = 6.0


## 0..1 pressure after `wave_seconds` of an open wave (see the two settings above).
func wave_pressure(wave_seconds: float) -> float:
	if pressure_ramp_seconds <= 0.0:
		return 1.0 if wave_seconds >= pressure_start_seconds else 0.0
	return clampf((wave_seconds - pressure_start_seconds) / pressure_ramp_seconds, 0.0, 1.0)

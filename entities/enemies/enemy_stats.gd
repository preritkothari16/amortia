class_name EnemyStats
extends Resource
## Tuning values for one enemy archetype. One .tres per archetype in data/ (runner.tres).
## The GA will later produce per-enemy values from a genome; these are the base numbers.

@export var archetype: StringName = &"runner"
@export var max_health: float = 30.0
## Top speed in pixels per second (16 px = 1 tile).
@export var move_speed: float = 70.0
## How fast velocity changes towards the desired velocity, in px/s². Lower = smoother, wider turns.
@export var acceleration: float = 500.0

@export_group("Decisions")
## Behaviour genes (aggression, flanking, patience) that weight the utility AI.
@export var behaviour: BehaviourWeights
## Shared utility AI tuning (decision rate, momentum, consideration ranges).
@export var utility_settings: UtilitySettings
## Fastest the heading may rotate while moving, in degrees per second (0 = no limit).
@export var max_turn_rate_degrees: float = 360.0
## The turn limit only applies above this speed (px/s). 0 = always.
@export var turn_limit_min_speed: float = 0.0

@export_group("Senses and pursuit")
## How far (px) the enemy can see the player, given a clear line of sight (10 tiles).
@export var sight_range: float = 160.0
## Within this distance (px) the enemy notices the player even without line of sight (2 tiles).
@export var sense_radius: float = 32.0
## Pursuit: aim at player position + player velocity * this many seconds. 0 = no prediction.
@export var prediction_time: float = 0.3

@export_group("Investigation")
## Counts as "arrived" at the last known position within this distance (px).
@export var investigate_arrive_distance: float = 12.0
## ...or within this distance (px) with a clear view of it (it is visibly empty).
@export var investigate_view_distance: float = 48.0
## Seconds spent looking around a last known position before giving up (IDLE).
@export var search_time: float = 2.0
## A* waypoint counts as reached within this distance (px) of the tile centre.
@export var waypoint_radius: float = 8.0
## Re-plan the A* path if pushed further than this (px) from the next waypoint.
@export var off_path_distance: float = 40.0

@export_group("Steering weights")
## How strongly the enemy follows the flow field / heads for the player.
@export var seek_weight: float = 1.0
## How strongly allies push each other apart.
@export var separation_weight: float = 1.6
## How strongly feelers push away from walls.
@export var wall_avoidance_weight: float = 1.2

@export_group("Steering shape")
## Allies closer than this (px) push each other apart.
@export var separation_radius: float = 14.0
## Queuing only applies within this flow cost of the player (about tiles), where crowds form.
## 0 = queuing off.
@export var crowd_cost: float = 5.0
## Allies ahead within this sideways distance (px) block us; we match their pace (queuing).
@export var queue_lane_width: float = 8.0
## Length of the wall feelers in px.
@export var feeler_length: float = 14.0
## Angle of the two side feelers from straight ahead, in degrees.
@export var feeler_angle_degrees: float = 35.0
## Within this flow cost of the player (about tiles), stop following arrows and close in directly.
@export var close_in_cost: float = 1.5
## When closing in, slow down within this distance (px) of the player instead of overshooting.
@export var arrive_radius: float = 24.0
## Desired speeds below this (px/s) count as "stand still" - stops shivering in crowds.
@export var dead_zone_speed: float = 6.0

@export_group("Terrain")
## Terrain the enemy crosses by climbing: walkable in the flow field but solid for physics.
## While climbing, speed = move_speed / tile cost (fence cost 6 -> 6x slower).
@export var climbable_terrains: PackedStringArray = PackedStringArray(["fence"])

@export_group("Greybox")
@export var color: Color = Color(0.9, 0.15, 0.2)

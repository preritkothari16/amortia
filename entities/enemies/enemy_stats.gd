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
## Fastest the heading may rotate while moving, in degrees per second (0 = no limit).
@export var max_turn_rate_degrees: float = 360.0
## The turn limit only applies above this speed (px/s). 0 = always.
@export var turn_limit_min_speed: float = 0.0

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

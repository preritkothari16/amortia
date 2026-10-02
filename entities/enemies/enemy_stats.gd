class_name EnemyStats
extends Resource
## Tuning values for one enemy archetype. One .tres per archetype in data/ (runner.tres).
## The GA will later produce per-enemy values from a genome; these are the base numbers.

@export var archetype: StringName = &"runner"
@export var max_health: float = 30.0
## Top speed in pixels per second (16 px = 1 tile).
@export var move_speed: float = 70.0
## How fast velocity turns towards the desired velocity, in px/s². Lower = smoother, wider turns.
@export var acceleration: float = 500.0

@export_group("Steering")
## Allies closer than this (px) push each other apart.
@export var separation_radius: float = 14.0
## Strength of the separation push relative to move_speed.
@export var separation_weight: float = 0.8
## When in the player's tile, slow down within this distance (px) instead of overshooting.
@export var arrive_radius: float = 12.0

@export_group("Terrain")
## Terrain the enemy crosses by climbing: walkable in the flow field but solid for physics.
## While climbing, speed = move_speed / tile cost (fence cost 6 -> 6x slower).
@export var climbable_terrains: PackedStringArray = PackedStringArray(["fence"])

@export_group("Greybox")
@export var color: Color = Color(0.9, 0.15, 0.2)

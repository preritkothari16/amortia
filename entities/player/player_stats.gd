class_name PlayerStats
extends Resource
## Tuning values for the player. Edit data/player_stats.tres, not this file.

## Hit points. Nothing damages the player yet; the Fortify skills already raise it.
@export var max_health: float = 100.0
## Top speed in pixels per second (16 px = 1 tile).
@export var move_speed: float = 90.0
## How fast the player reaches top speed, in pixels per second squared.
@export var acceleration: float = 900.0
## How fast the player stops when no key is held, in pixels per second squared.
@export var friction: float = 1200.0

@export_group("Dodge roll")
## Speed during the roll, in pixels per second.
@export var dodge_speed: float = 240.0
## How long the roll moves the player, in seconds.
@export var dodge_duration: float = 0.3
## How long the player cannot be damaged after starting a roll, in seconds.
@export var dodge_invulnerable_time: float = 0.3
## Seconds from the start of one roll until the next is allowed.
@export var dodge_cooldown: float = 1.2

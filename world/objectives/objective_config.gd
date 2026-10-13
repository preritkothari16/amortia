class_name ObjectiveConfig
extends Resource
## What a level asks of the player (GDD 8.2). One resource per level; the Objective classes in
## world/objectives read it. Numbers marked "proposal" were not in the design doc.

enum Type { SURVIVE, HOLD, ESCORT, PURGE, EXTRACT, STEALTH, APEX }

@export var type: Type = Type.SURVIVE

@export_group("Hold the point")
## Seconds the player must keep the point (per wave). Proposal: 45 s.
@export var hold_seconds: float = 45.0
## Radius of the point in px; enemies inside damage it, the player inside "holds" it.
@export var hold_radius: float = 40.0
## Point HP; 0 = point lost (level fail). Proposal: 200.
@export var point_health: float = 200.0
## Damage per second each enemy inside the radius does to the point. Proposal: 4.
@export var point_damage_per_enemy: float = 4.0

@export_group("Escort")
@export var escort_health: float = 120.0
## Survivor walking speed (px/s); it waits when the player is more than escort_leash px away.
@export var escort_speed: float = 40.0
@export var escort_leash: float = 96.0
## Melee damage an enemy next to the survivor deals per hit (uses the enemy's attack cooldown).
@export var escort_hit_damage: float = 8.0

@export_group("Purge nests")
@export_range(3, 5) var nest_count: int = 3
@export var nest_health: float = 120.0
## A nest spawns a straggler this often while it lives (seconds).
@export var nest_spawn_interval: float = 8.0

@export_group("Extract")
## Supplies to collect before the evac opens.
@export var extract_items: int = 4
## Noise radius of picking a supply up (looting draws enemies, GDD 8.2).
@export var loot_noise_radius: float = 160.0

@export_group("Stealth")
## Alarms allowed: an alarm = an enemy sees the player (enters CHASE). 0 = any alarm fails.
@export var alarms_allowed: int = 0

@export_group("Apex boss")
## Boss = the zone's best genome on its archetype, with these multipliers (placeholder until the
## boss designs exist - no special attacks are invented here).
@export var boss_health_multiplier: float = 12.0
@export var boss_damage_multiplier: float = 2.0
@export var boss_scale: float = 2.0
## The final boss (the Seed, GDD 3) uses the best genome of the whole run, not just the zone's.
@export var boss_uses_run_best: bool = false

@export_group("Objective fitness (O)")
## Raw objective points an enemy can earn per wave are normalised by FitnessSettings.objective_cap.
## What earns points (all attributable to one enemy):
##   HOLD    HP of damage the enemy did to the point
##   ESCORT  HP of damage the enemy did to the survivor
##   PURGE   seconds the enemy spent within nest_guard_radius of a living nest while the player
##           was within it too (guarding), x 1
##   EXTRACT seconds within evac_guard_radius of the evac point while it is open
##   STEALTH alarm_points for the enemy that raised an alarm
##   SURVIVE / APEX: none (O = 0)
@export var nest_guard_radius: float = 96.0
@export var evac_guard_radius: float = 96.0
@export var alarm_points: float = 50.0

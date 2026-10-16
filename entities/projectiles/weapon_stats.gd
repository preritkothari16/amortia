class_name WeaponStats
extends Resource
## Tuning values for one ranged weapon. One .tres per weapon in data/ (pistol) or data/weapons/.

## Short name used in saves and the loadout ("pistol", "shotgun").
@export var id: StringName = &"pistol"
@export var display_name: String = "Pistol"
@export var description: String = ""
## Scrap the Workbench charges to build the weapon from its blueprint (0 = always owned).
@export var unlock_cost_scrap: int = 0

## Scene spawned per shot. Its root must be a Bullet.
@export var projectile_scene: PackedScene
## Seconds between shots.
@export var fire_cooldown: float = 0.25
## true = hold to keep firing, false = one shot per click.
@export var automatic: bool = false
## Projectile speed in pixels per second (16 px = 1 tile).
@export var projectile_speed: float = 320.0
## Seconds before an unhit projectile disappears.
@export var projectile_lifetime: float = 1.0
## Damage dealt to anything with a take_damage(amount: float) method.
@export var damage: float = 10.0
## Each shot is a noise heard by enemies within this many pixels (16 px = 1 tile).
@export var noise_radius: float = 192.0
## Projectiles per shot (a shotgun fires several), each dealing `damage`.
@export_range(1, 16) var pellets: int = 1
## Total spread cone of one shot, in degrees (0 = every pellet flies straight).
@export var spread_degrees: float = 0.0
## Seconds after switching to this weapon before it can fire (the cost of carrying two).
@export var draw_time: float = 0.0

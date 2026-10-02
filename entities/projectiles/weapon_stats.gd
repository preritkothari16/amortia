class_name WeaponStats
extends Resource
## Tuning values for one ranged weapon. One .tres per weapon in data/.

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

class_name StatModifier
extends Resource
## One change to one number of the player's stats or weapon: multiply it or add to it.
## The same type serves every source (permanent research, temporary power-ups), but each source
## is its own layer in PlayerModifiers, so a temporary effect can never end up in a saved value.

enum Target { PLAYER, WEAPON }
enum Mode { MULTIPLY, ADD }

@export var target: Target = Target.PLAYER
## Property of PlayerStats (max_health, move_speed, ...) or WeaponStats (damage, fire_cooldown, ...).
@export var property: StringName
@export var mode: Mode = Mode.MULTIPLY
@export var amount: float = 1.0


static func make(for_target: Target, for_property: StringName, for_mode: Mode, for_amount: float) -> StatModifier:
	var m: StatModifier = StatModifier.new()
	m.target = for_target
	m.property = for_property
	m.mode = for_mode
	m.amount = for_amount
	return m


func apply_to(value: float) -> float:
	return value * amount if mode == Mode.MULTIPLY else value + amount

class_name PowerUpType
extends Resource
## One kind of temporary power-up. Always a benefit, always brief. Data only (data/power_up_set.tres).
##   HEAL    restores HP at once (never above max health)
##   SHIELD  absorbs up to `shield_amount` damage for `duration` seconds
##   BOOST   `modifiers` (haste, fire rate, damage) for `duration` seconds, in the temporary layer
## Nothing here is ever saved or written into the player's base stats.

enum Kind { HEAL, SHIELD, BOOST }

@export var id: StringName
@export var display_name: String = ""
@export var kind: Kind = Kind.BOOST
## Relative chance of being picked when a power-up spawns.
@export var weight: float = 1.0
## Seconds the effect lasts (SHIELD, BOOST). Capped by PowerUpSet.max_duration.
@export var duration: float = 10.0
@export var heal_amount: float = 0.0
@export var shield_amount: float = 0.0
@export var modifiers: Array[StatModifier] = []
@export var color: Color = Color.WHITE
## One or two letters drawn on the pickup.
@export var symbol: String = "?"


## True if every number is a benefit for the player (heal up, shield up, stats better).
func is_beneficial() -> bool:
	if heal_amount < 0.0 or shield_amount < 0.0 or duration < 0.0:
		return false
	for m: StatModifier in modifiers:
		var better_when_lower: bool = m.property == &"fire_cooldown" or m.property == &"dodge_cooldown"
		if m.mode == StatModifier.Mode.MULTIPLY:
			if m.amount == 1.0 or (m.amount > 1.0) == better_when_lower:
				return false
		elif m.amount == 0.0 or (m.amount > 0.0) == better_when_lower:
			return false
	return true

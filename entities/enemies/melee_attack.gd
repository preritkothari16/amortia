class_name MeleeAttack
extends RefCounted
## Close-range attack rules for one enemy (GDD 6.4: only token holders attack). Pure, so the
## rules can be unit-tested: the Enemy node supplies the facts (token, distance, clear line)
## and strike() applies a hit. Damage counted for fitness is the HP the target really lost,
## never proximity, never overkill, never hits blocked by a dodge.

## Seconds until the next swing is allowed.
var cooldown_left: float = 0.0


func tick(delta: float) -> void:
	cooldown_left = maxf(cooldown_left - delta, 0.0)


## True if a swing may start now: holds an attack token, target within `attack_range` px
## (centre to centre), nothing solid in between, cooldown over.
func can_attack(has_token: bool, distance: float, attack_range: float, clear_line: bool) -> bool:
	return has_token and distance <= attack_range and clear_line and cooldown_left <= 0.0


## Swings at `target` (anything with take_damage(amount) -> float). The cooldown starts even
## if the hit is dodged. Returns the HP actually removed, and adds it to `record` (fitness D).
func strike(target: Object, damage: float, cooldown: float, record: FitnessRecord) -> float:
	cooldown_left = cooldown
	if target == null or not target.has_method("take_damage"):
		return 0.0
	var dealt: float = target.take_damage(damage)
	if dealt > 0.0 and record != null:
		record.add_damage(dealt)
	return dealt

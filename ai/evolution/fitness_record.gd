class_name FitnessRecord
extends RefCounted
## Raw, measured facts about one enemy during one wave - no weights, no normalisation.
## Fitness turns these into the D / P / S / O terms. Once frozen (death or wave end) nothing
## changes any more, so the numbers the GA sees are exactly what was measured.

## Health points of damage this enemy dealt to the player (or an escort / objective target).
var damage_dealt: float = 0.0
## Seconds spent within the pressure radius of the player.
var pressure_seconds: float = 0.0
## Seconds from spawn until death or the end of the wave.
var alive_seconds: float = 0.0
## Objective disruption points (e.g. damage to a held point). Stays 0 until objectives exist.
var objective_score: float = 0.0
## True if the enemy was killed (false = survived until the wave ended).
var died: bool = false
## True once death or the wave end has locked the record.
var frozen: bool = false
## Which wave this record belongs to.
var wave: int = 0


## Called every physics frame while the enemy is alive.
## `distance_to_player` is measured by the evaluator (god's-eye view), not the enemy's senses.
func tick(delta: float, distance_to_player: float, pressure_radius: float) -> void:
	if frozen:
		return
	alive_seconds += delta
	if distance_to_player <= pressure_radius:
		pressure_seconds += delta


func add_damage(amount: float) -> void:
	if not frozen and amount > 0.0:
		damage_dealt += amount


func add_objective(points: float) -> void:
	if not frozen and points > 0.0:
		objective_score += points


## The enemy was killed: stop counting.
func mark_dead() -> void:
	if not frozen:
		died = true
		frozen = true


## The wave ended with this enemy still alive: stop counting.
func freeze() -> void:
	frozen = true


func to_dict() -> Dictionary:
	return {
		"damage_dealt": damage_dealt, "pressure_seconds": pressure_seconds,
		"alive_seconds": alive_seconds, "objective_score": objective_score,
		"died": died, "wave": wave,
	}

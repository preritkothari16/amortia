class_name ChaseAction
extends UtilityAction
## Chase: go straight for a player we can see. Higher the closer they are; scaled by Aggression.
##   score = aggression * (chase_base + (1 - chase_base) * closeness)
##   closeness = 1 - distance / chase_range   (clamped to 0..1)
## A wave that drags on adds hunger: aggression = max(aggression, wave_pressure), so a timid
## enemy that watches the player from afar finally comes (UtilitySettings.wave_pressure).


func _init() -> void:
	type = Type.CHASE


func score(inputs: DecisionInputs, genes: BehaviourWeights, settings: UtilitySettings) -> float:
	if not inputs.player_visible:
		return 0.0  # can't chase what we can't see
	var closeness: float = 1.0 - clampf(inputs.distance_to_player / settings.chase_range, 0.0, 1.0)
	var drive: float = maxf(genes.aggression, inputs.wave_pressure)
	return drive * (settings.chase_base + (1.0 - settings.chase_base) * closeness)

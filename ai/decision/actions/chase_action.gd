class_name ChaseAction
extends UtilityAction
## Chase: go straight for a player we can see. Higher the closer they are; scaled by Aggression.
##   score = aggression * (chase_base + (1 - chase_base) * closeness)
##   closeness = 1 - distance / chase_range   (clamped to 0..1)


func _init() -> void:
	type = Type.CHASE


func score(inputs: DecisionInputs, genes: BehaviourWeights, settings: UtilitySettings) -> float:
	if not inputs.player_visible:
		return 0.0  # can't chase what we can't see
	var closeness: float = 1.0 - clampf(inputs.distance_to_player / settings.chase_range, 0.0, 1.0)
	return genes.aggression * (settings.chase_base + (1.0 - settings.chase_base) * closeness)

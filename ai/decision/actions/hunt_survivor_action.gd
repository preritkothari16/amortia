class_name HuntSurvivorAction
extends UtilityAction
## Hunt the Escort survivor: go for the survivor when it is in view. Scored like Chase, so the
## nearer of the two targets wins when both are visible:
##   score = max(aggression, wave_pressure) * (chase_base + (1 - chase_base) * closeness) * survivor_priority
##   closeness = 1 - survivor_distance / chase_range   (clamped to 0..1)
## Needs the survivor to be perceived (grid line of sight within sight range, the same rule as for
## the player), so it never gives enemies knowledge they could not have.


func _init() -> void:
	type = Type.HUNT_SURVIVOR


func score(inputs: DecisionInputs, genes: BehaviourWeights, settings: UtilitySettings) -> float:
	if not inputs.survivor_visible:
		return 0.0
	var closeness: float = 1.0 - clampf(inputs.survivor_distance / settings.chase_range, 0.0, 1.0)
	var drive: float = maxf(genes.aggression, inputs.wave_pressure)
	return drive * (settings.chase_base + (1.0 - settings.chase_base) * closeness) * settings.survivor_priority

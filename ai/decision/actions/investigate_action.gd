class_name InvestigateAction
extends UtilityAction
## Investigate: the player is out of sight but we have a lead (a noise, or where they were last
## seen). Fresher leads are worth more; scaled by Patience.
##   score = patience * (investigate_base + (1 - investigate_base) * freshness)
##   freshness = 1 - lead_age / memory_time   (clamped to 0..1)


func _init() -> void:
	type = Type.INVESTIGATE


func score(inputs: DecisionInputs, genes: BehaviourWeights, settings: UtilitySettings) -> float:
	if inputs.player_visible or not inputs.has_lead:
		return 0.0  # seeing the player beats any lead; no lead, nothing to investigate
	var freshness: float = 1.0 - clampf(inputs.lead_age / settings.memory_time, 0.0, 1.0)
	return genes.patience * (settings.investigate_base + (1.0 - settings.investigate_base) * freshness)

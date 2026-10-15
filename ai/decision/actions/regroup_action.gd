class_name RegroupAction
extends UtilityAction
## Regroup: the player is in view but the pack is not together yet. A cohesive enemy waits for
## its friends instead of charging alone: it walks to the packmates and, once enough of them
## are close, every one of them switches to Chase at the same time.
##   score = cohesion * regroup_base * (1 - wave_pressure)   only while the pack is incomplete
## It never adds to Chase: with low cohesion this scores under idle, so loners behave as before.
## It cannot wait forever: regroup_expired (RegroupBudget) turns it off, and a wave that drags on
## (wave_pressure) fades it out, so the waiting always ends.


func _init() -> void:
	type = Type.REGROUP


func score(inputs: DecisionInputs, genes: BehaviourWeights, settings: UtilitySettings) -> float:
	if not inputs.player_visible or not inputs.regroup_available or inputs.regroup_expired:
		return 0.0
	if inputs.distance_to_player < settings.regroup_min_distance:
		return 0.0  # already in the fight
	if inputs.pack_size + 1 >= settings.pack_needed:
		return 0.0  # the pack is complete: go
	return genes.cohesion * settings.regroup_base * (1.0 - clampf(inputs.wave_pressure, 0.0, 1.0))

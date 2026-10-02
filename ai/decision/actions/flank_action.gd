class_name FlankAction
extends UtilityAction
## Flank: while allies keep the player busy, circle round to the side the player isn't facing.
## Scaled by Flanking. Every factor is 0..1 and they multiply, so any one of them being 0
## (no allies, no flank point, already too close) rules flanking out:
##   score = flanking * allies * facing * far_enough
##   allies     = allies_chasing / flank_allies_needed            (clamped)
##   facing     = flank_facing_base + (1 - flank_facing_base) * facing_away
##   facing_away = (1 - player_facing_dot) / 2                   (0 = looking at us, 1 = back turned)
##   far_enough = (distance - flank_min_distance) / flank_distance_ramp   (clamped)


func _init() -> void:
	type = Type.FLANK


func score(inputs: DecisionInputs, genes: BehaviourWeights, settings: UtilitySettings) -> float:
	if not inputs.player_visible or not inputs.flank_point_available or inputs.allies_chasing <= 0:
		return 0.0
	var allies: float = clampf(float(inputs.allies_chasing) / settings.flank_allies_needed, 0.0, 1.0)
	var facing_away: float = (1.0 - inputs.player_facing_dot) * 0.5
	var facing: float = settings.flank_facing_base + (1.0 - settings.flank_facing_base) * facing_away
	var far_enough: float = clampf(
			(inputs.distance_to_player - settings.flank_min_distance) / settings.flank_distance_ramp, 0.0, 1.0)
	return genes.flanking * allies * facing * far_enough

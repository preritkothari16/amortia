class_name SideObjective
extends Resource
## Optional per-level goals (GDD 8.3). Challenges are evaluated at level end from the level's
## stats; rescue / bestiary / collectible are interfaces only until their content is designed
## (they never complete yet - nothing is invented here).

enum Kind { CHALLENGE, RESCUE, BESTIARY, COLLECTIBLE }
enum Challenge { NO_DAMAGE, UNDER_TIME, NO_BARRICADES }

@export var id: String = ""
@export var title: String = ""
@export var kind: Kind = Kind.CHALLENGE
@export var challenge: Challenge = Challenge.NO_DAMAGE
## UNDER_TIME: finish the level within this many seconds.
@export var time_limit_seconds: float = 300.0
## Bonus scrap for completing it (GDD 8.3 "for bonus scrap").
@export var reward_scrap: int = 10


## `stats`: {damage_taken: float, seconds: float, barricades_placed: int}.
func is_met(stats: Dictionary) -> bool:
	if kind != Kind.CHALLENGE:
		return false  # placeholder kinds: no content yet
	match challenge:
		Challenge.NO_DAMAGE:
			return stats.get("damage_taken", 1.0) <= 0.0
		Challenge.UNDER_TIME:
			return stats.get("seconds", INF) <= time_limit_seconds
		Challenge.NO_BARRICADES:
			return stats.get("barricades_placed", 1) == 0
	return false

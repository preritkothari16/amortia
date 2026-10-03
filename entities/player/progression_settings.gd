class_name ProgressionSettings
extends Resource
## Tuning for player XP and levels (GDD 7.2). Edit data/progression.tres, not this file.

## Highest level the player can reach. XP stops counting once it is reached.
@export var level_cap: int = 30
## Skill points granted by each level gained.
@export var skill_points_per_level: int = 1

@export_group("Level curve")
## XP needed to go from level 1 to level 2.
@export var xp_first_level: int = 40
## Extra XP needed for each level after that (linear curve: 40, 60, 80, ...).
@export var xp_per_level: int = 20

@export_group("Enemy XP")
## XP for killing an enemy whose stat genes add up to `reference_stat_total`.
@export var enemy_base_xp: float = 10.0
## Stat total of a first-wave enemy (= GenomeRules.budget_start).
@export var reference_stat_total: float = 15.0
## Bonus per stat point above the reference: 0.05 = +5 % XP per point.
## Later waves have a bigger stat budget, so evolved enemies are worth slightly more.
@export var xp_bonus_per_stat_point: float = 0.05


## XP needed to go from `level` to `level + 1`. 0 at or above the cap.
func xp_to_next(level: int) -> int:
	if level >= level_cap:
		return 0
	return xp_first_level + xp_per_level * maxi(level - 1, 0)


## XP for killing an enemy with this stat total. Never less than the base XP.
func enemy_xp(stat_total: float) -> int:
	var extra: float = maxf(stat_total - reference_stat_total, 0.0)
	return roundi(enemy_base_xp * (1.0 + xp_bonus_per_stat_point * extra))

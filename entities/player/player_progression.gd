class_name PlayerProgression
extends RefCounted
## The player's XP, level and unspent skill points. Plain data so it can be tested headless
## and later saved by the SaveSystem. Lives on the Player, so it carries over between waves.

## Emitted once per level gained (several times if one big XP gain skips levels).
signal leveled_up(new_level: int)
## Emitted after every XP change.
signal xp_changed()

var settings: ProgressionSettings
var level: int = 1
## XP collected towards the next level (resets to the remainder on level up).
var xp: int = 0
## All XP ever earned, including XP that was spent on levels.
var total_xp: int = 0
## Points to spend in the skill tree (not built yet).
var skill_points: int = 0


func _init(p_settings: ProgressionSettings) -> void:
	settings = p_settings


## Adds XP and levels up as many times as it covers. Returns the number of levels gained.
func add_xp(amount: int) -> int:
	if amount <= 0 or is_max_level():
		return 0
	total_xp += amount
	xp += amount
	var gained: int = 0
	while not is_max_level() and xp >= xp_to_next():
		xp -= xp_to_next()
		level += 1
		skill_points += settings.skill_points_per_level
		gained += 1
		leveled_up.emit(level)
	if is_max_level():
		xp = 0  # nothing left to fill at the cap
	xp_changed.emit()
	return gained


func is_max_level() -> bool:
	return level >= settings.level_cap


## XP needed for the current level up (0 at the cap).
func xp_to_next() -> int:
	return settings.xp_to_next(level)


## How full the XP bar is, 0..1 (1 at the cap).
func progress() -> float:
	if is_max_level():
		return 1.0
	return float(xp) / float(xp_to_next())


## Spends one skill point if there is one. For the future skill tree.
func spend_skill_point() -> bool:
	if skill_points <= 0:
		return false
	skill_points -= 1
	xp_changed.emit()
	return true

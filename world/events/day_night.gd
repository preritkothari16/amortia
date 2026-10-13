class_name DayNight
extends TerrainEvent
## Day / night cycle (GDD 4.4, zones 1 and 3). Writes WorldConditions.is_night; Perception
## then cuts enemy vision by 40 % (less with night_sense) and widens their hearing. It changes
## no tile and no knowledge of where the player is. The switch is announced warning_seconds
## ahead (status_text) so it never surprises the player.

@export var day_seconds: float = 90.0
@export var night_seconds: float = 60.0
@export var warning_seconds: float = 5.0
## Start at night instead of day.
@export var start_at_night: bool = false

## Seconds until the next switch.
var time_left: float = 0.0


func _on_reset() -> void:
	time_left = night_seconds if start_at_night else day_seconds


func _on_start() -> void:
	if conditions != null:
		conditions.is_night = start_at_night


func is_night() -> bool:
	return conditions != null and conditions.is_night


func _on_tick(delta: float) -> void:
	if conditions == null:
		return
	time_left -= delta
	if time_left <= 0.0:
		conditions.is_night = not conditions.is_night
		time_left = night_seconds if conditions.is_night else day_seconds


func status_text() -> String:
	if conditions == null or time_left > warning_seconds:
		return ""
	return ("Dawn in %d s" if conditions.is_night else "Night falls in %d s") % ceili(time_left)

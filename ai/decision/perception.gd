class_name Perception
extends RefCounted
## The sense rules (GDD 4.3 vision and sound, 4.4 night) as small pure functions, so the enemy
## Node only gathers facts (distance, line of sight, the tiles involved) and asks these.
## No state: Awareness still remembers what was seen or heard.
##
## Sight:   within sense_radius (2 tiles)          -> always noticed, even in cover
##          target concealed (tall grass, quiet)    -> not seen further out
##          else seen if distance <= effective range and the line of sight is clear
##          effective range = sight range x fog multiplier x night factor
##          night factor    = 1 - night_vision_penalty x (1 - night_sense)
## Hearing: a noise is heard within its radius; at night the radius grows by
##          night_hearing_bonus + night_sense_hearing_bonus x night_sense.
##          Hearing only ever gives the noise's position (a last known spot), never live tracking.


## Sight range after fog and night. `fog_multiplier` = the smaller vision multiplier of the
## observer's and the target's cell (fog 0.5).
static func effective_sight_range(sight_range: float, fog_multiplier: float, is_night: bool,
		night_sense: float, settings: PerceptionSettings) -> float:
	var range_px: float = sight_range * clampf(fog_multiplier, 0.0, 1.0)
	if is_night:
		range_px *= 1.0 - settings.night_vision_penalty * (1.0 - clampf(night_sense, 0.0, 1.0))
	return range_px


## Can the observer see the target right now?
static func can_see(distance: float, sense_radius: float, sight_range: float, line_clear: bool,
		target_concealed: bool) -> bool:
	if distance <= sense_radius:
		return true  # close enough to notice anyone (GDD: stealth hides you beyond 2 tiles)
	if target_concealed:
		return false
	return distance <= sight_range and line_clear


## Hearing radius for a noise of `radius` px, for this listener.
static func hearing_radius(radius: float, is_night: bool, night_sense: float,
		settings: PerceptionSettings) -> float:
	if not is_night:
		return radius
	return radius * (1.0 + settings.night_hearing_bonus + settings.night_sense_hearing_bonus * clampf(night_sense, 0.0, 1.0))


## Stealth rule for the player: hidden while standing in concealing terrain, not rolling
## ("running") and not having shot in the last shot_exposure_seconds.
static func is_concealed(in_concealing_tile: bool, seconds_since_shot: float, is_dodging: bool,
		settings: PerceptionSettings) -> bool:
	return in_concealing_tile and not is_dodging and seconds_since_shot >= settings.shot_exposure_seconds


## Footstep noise radius for a tile's NoiseLevel (TerrainDefinition.NoiseLevel as int).
static func footstep_radius(noise_level: int, settings: PerceptionSettings) -> float:
	if noise_level < 0 or noise_level >= settings.footstep_radius_by_level.size():
		return 0.0
	return settings.footstep_radius_by_level[noise_level]

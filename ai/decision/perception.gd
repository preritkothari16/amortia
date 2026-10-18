class_name Perception
extends RefCounted
## The sense rules (GDD 4.3 vision and sound, 4.4 night) as small pure functions, so the enemy
## Node only gathers facts (distance, line of sight, the tiles involved) and asks these.
## No state: Awareness still remembers what was seen or heard.
##
## Sight:   within sense_radius (2 tiles)          -> always noticed, even in cover or behind
##          target concealed (tall grass, quiet)    -> not seen further out
##          outside the view cone (V1)              -> not seen further out
##          else seen if distance <= effective range and the line of sight is clear
##          "seen" further out only fills suspicion; full suspicion = CHASE (Awareness.notice)
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


## Is the target inside the view cone? `to_target` = target - observer, `facing` = the observer's
## gaze direction. 360 degrees, or no facing / no offset yet, counts as inside: an unknown
## facing must not become a blind spot the player gets for free.
static func in_view_cone(to_target: Vector2, facing: Vector2, cone_degrees: float) -> bool:
	if cone_degrees >= 360.0 or facing == Vector2.ZERO or to_target == Vector2.ZERO:
		return true
	return absf(facing.angle_to(to_target)) <= deg_to_rad(cone_degrees) * 0.5


## Suspicion gained per second while the player is in view at `distance`:
##   t         = (distance - sense_radius) / (sight_range - sense_radius)   clamped to 0..1
##   fill_time = lerp(suspicion_fill_near, suspicion_fill_far, t)
##   rate      = 1 / fill_time, x suspicion_alert_multiplier if the enemy is already alert
## Closer = faster: right outside 2 tiles an enemy is sure in 0.5 s, at the edge of its sight in 1.8 s.
static func suspicion_rate(distance: float, sense_radius: float, sight_range: float, already_alert: bool,
		settings: PerceptionSettings) -> float:
	var span: float = maxf(sight_range - sense_radius, 1.0)
	var t: float = clampf((distance - sense_radius) / span, 0.0, 1.0)
	var fill_time: float = maxf(lerpf(settings.suspicion_fill_near, settings.suspicion_fill_far, t), 0.01)
	var rate: float = 1.0 / fill_time
	if already_alert:
		rate *= settings.suspicion_alert_multiplier
	return rate


## Gaze of an enemy that is looking around: `rest` swung back and forth by a sine,
## `sweep_degrees` in total, one full swing every `period` seconds.
static func scan_facing(rest: Vector2, time: float, sweep_degrees: float, period: float) -> Vector2:
	if rest == Vector2.ZERO or period <= 0.0:
		return rest
	return rest.rotated(deg_to_rad(sweep_degrees) * 0.5 * sin(TAU * time / period))


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

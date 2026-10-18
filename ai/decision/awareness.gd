class_name Awareness
extends RefCounted
## What one enemy knows about the player (GDD 4.3): the "Sensors" part of its PEAS agent.
## No live tracking: the enemy only learns the player's position by SEEING it (every frame
## while visible) or by HEARING a noise (once, at the noise position). Everything else is memory.
##
##   IDLE        knows nothing useful, stands still
##   CHASE       player visible right now: last_known is the player's real position
##   INVESTIGATE heading for last_known (where the player was last seen or heard)
##   SEARCH      reached last_known and found nothing: looks around for search_time, then IDLE
##
## Suspicion (Reactive Survival V1): further out than sense_radius, seeing the player does not
## mean CHASE at once. Each frame in view adds to `suspicion` (Perception.suspicion_rate), each
## frame out of view drains it. Crossing the investigate threshold makes the enemy go and check
## the glimpse spot (an ordinary lead, like a noise); reaching 1 = it sees you (CHASE).
## Breaking line of sight before that, or during a chase, drops it back to a lead it has to follow.
##
## Wariness (Reactive Survival V2): an enemy that actually SAW the player (CHASE) and lost them
## stays wary for wary_seconds. While wary it counts as alert (suspicion fills faster, it sweeps
## its gaze like a searching enemy) but it learns nothing new: no position, no lead.

enum State { IDLE, INVESTIGATE, SEARCH, CHASE }

var state: State = State.IDLE
## Last position the enemy has information about. Vector2.INF = none yet.
var last_known: Vector2 = Vector2.INF
## Goes up every time last_known changes outside CHASE, so the enemy knows to plan a new path.
var target_version: int = 0
## Seconds since last_known was last updated (by seeing or hearing). Old leads are worth less.
var lead_age: float = 0.0
## How provoking the current lead was, 0..1: a gunshot right next to us is 1, one at the edge
## of earshot or a distant order (the spawn Pulse) is about 0. Lazy enemies only react to strong leads.
var lead_strength: float = 0.0
## How sure the enemy is that it saw someone, 0..1. 1 while chasing.
var suspicion: float = 0.0
## Where the player was when last glimpsed (suspicion rising). Vector2.INF = never.
var glimpse: Vector2 = Vector2.INF
## How long wariness lasts after losing a player it saw (set by the enemy from PerceptionSettings).
## 0 = never wary (bare test enemies, the rule before V2).
var wary_seconds: float = 0.0
## Seconds of wariness left (0 = calm).
var wary_left: float = 0.0

var _search_left: float = 0.0


## Called every frame the player is visible and the enemy is sure (suspicion full, or within
## sense_radius where there is no doubt).
func see(player_position: Vector2) -> void:
	state = State.CHASE
	last_known = player_position
	glimpse = player_position
	lead_age = 0.0
	suspicion = 1.0


## The player is in view but further out than sense_radius: suspicion rises by `rate` per second.
## Full -> see(). Crossing `investigate_threshold` (not chasing yet) -> a lead to the glimpse spot,
## as strong as the suspicion, so lazy enemies may still shrug it off (InvestigateAction).
func notice(player_position: Vector2, rate: float, delta: float, investigate_threshold: float) -> void:
	glimpse = player_position
	var before: float = suspicion
	suspicion = minf(1.0, suspicion + rate * delta)
	if suspicion >= 1.0:
		see(player_position)
	elif state != State.CHASE and before < investigate_threshold and suspicion >= investigate_threshold:
		hear(player_position, suspicion)


## The player is not in view this frame: a chase becomes an investigation (lose_sight) and the
## suspicion drains by `decay_per_second`.
func unnoticed(delta: float, lost_sight_strength: float, decay_per_second: float) -> void:
	lose_sight(lost_sight_strength)
	suspicion = maxf(0.0, suspicion - decay_per_second * delta)


## True while following up a lead, searching or still wary: suspicion fills faster then.
func is_alert() -> bool:
	return state == State.INVESTIGATE or state == State.SEARCH or wary_left > 0.0


## True for wary_seconds after losing a player it saw (it looks around harder).
func is_wary() -> bool:
	return wary_left > 0.0


## Called every frame the player is NOT visible. A chase turns into an investigation of the
## spot where the player was last seen - the enemy does not get the new position.
## `strength` = how provoking losing the player is (only used on the frame the chase ends).
func lose_sight(strength: float = 1.0) -> void:
	if state == State.CHASE:
		state = State.INVESTIGATE
		target_version += 1
		lead_strength = clampf(strength, 0.0, 1.0)
		wary_left = wary_seconds  # it saw someone: stays on edge for a while


## A noise reached us. While chasing, sight is better information, so noises are ignored;
## otherwise the newest noise becomes the place to investigate. `strength` 0..1 = how loud it
## was where we stand (see Enemy._on_noise_emitted).
func hear(noise_position: Vector2, strength: float = 0.0) -> void:
	if state == State.CHASE:
		return
	last_known = noise_position
	state = State.INVESTIGATE
	target_version += 1
	lead_age = 0.0
	lead_strength = clampf(strength, 0.0, 1.0)


## Reached last_known (or found it unreachable): look around for a while.
func arrive(search_time: float) -> void:
	if state == State.INVESTIGATE:
		state = State.SEARCH
		_search_left = search_time


## True if there is a last known position nobody has checked yet (worth investigating).
func has_lead() -> bool:
	return state == State.INVESTIGATE


## Ages the information, counts down the wariness and the search; afterwards the enemy goes idle.
func tick(delta: float) -> void:
	lead_age += delta
	wary_left = maxf(wary_left - delta, 0.0)
	if state == State.SEARCH:
		_search_left -= delta
		if _search_left <= 0.0:
			state = State.IDLE

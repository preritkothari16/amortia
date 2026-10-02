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

enum State { IDLE, INVESTIGATE, SEARCH, CHASE }

var state: State = State.IDLE
## Last position the enemy has information about. Vector2.INF = none yet.
var last_known: Vector2 = Vector2.INF
## Goes up every time last_known changes outside CHASE, so the enemy knows to plan a new path.
var target_version: int = 0
## Seconds since last_known was last updated (by seeing or hearing). Old leads are worth less.
var lead_age: float = 0.0

var _search_left: float = 0.0


## Called every frame the player is visible.
func see(player_position: Vector2) -> void:
	state = State.CHASE
	last_known = player_position
	lead_age = 0.0


## Called every frame the player is NOT visible. A chase turns into an investigation of the
## spot where the player was last seen - the enemy does not get the new position.
func lose_sight() -> void:
	if state == State.CHASE:
		state = State.INVESTIGATE
		target_version += 1


## A noise reached us. While chasing, sight is better information, so noises are ignored;
## otherwise the newest noise becomes the place to investigate.
func hear(noise_position: Vector2) -> void:
	if state == State.CHASE:
		return
	last_known = noise_position
	state = State.INVESTIGATE
	target_version += 1
	lead_age = 0.0


## Reached last_known (or found it unreachable): look around for a while.
func arrive(search_time: float) -> void:
	if state == State.INVESTIGATE:
		state = State.SEARCH
		_search_left = search_time


## True if there is a last known position nobody has checked yet (worth investigating).
func has_lead() -> bool:
	return state == State.INVESTIGATE


## Ages the information and counts down the search; afterwards the enemy goes idle.
func tick(delta: float) -> void:
	lead_age += delta
	if state == State.SEARCH:
		_search_left -= delta
		if _search_left <= 0.0:
			state = State.IDLE

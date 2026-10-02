class_name AttackRing
extends RefCounted
## Attack ring (GDD 6.4): N slots on a circle around the player, at most `max_attackers`
## slot holders attack at once. Pure logic - enemies are plain integer ids with positions,
## so it can be tested headless.
##
## Each frame:
##   1. every eligible enemy calls engage(id, position); ineligible or dead ones disengage(id)
##   2. the owner (main.gd) calls update(player_position, delta), which
##        - frees slots that became unusable (player moved next to a wall)
##        - gives free slots to waiting members, nearest to the player first
##        - rotates attack tokens and hands free tokens to the holder that waited longest
##   3. enemies read get_role(id) and get_target(id) and steer there
## All choices are sorted by (distance, id), so the same situation always gives the same result.

enum Role { NONE, WAITING, HOLDING, ATTACKING }

## Marks a free slot. Node instance ids are never 0.
const FREE: int = 0

var settings: AttackRingSettings
var flow_field: FlowField
## The player's position at the last update().
var center: Vector2 = Vector2.ZERO

## Slot index -> owner id (FREE = nobody).
var _slot_owner: Array[int] = []
## Every engaged enemy -> its last reported position.
var _member_pos: Dictionary[int, Vector2] = {}
## Slot holders -> slot index.
var _slot_of: Dictionary[int, int] = {}
## Attackers -> time they got the token.
var _attack_since: Dictionary[int, float] = {}
## Time each id last lost a token (for fair rotation). Missing = never attacked.
var _last_attack_end: Dictionary[int, float] = {}
var _time: float = 0.0


func _init(field: FlowField, ring_settings: AttackRingSettings) -> void:
	flow_field = field
	settings = ring_settings
	_slot_owner.resize(settings.slot_count)
	_slot_owner.fill(FREE)


# --- Called by enemies ---------------------------------------------------------------

## "I am close enough to join (or stay in) the ring, and I am here."
func engage(id: int, position: Vector2) -> void:
	_member_pos[id] = position


## "I left, lost eligibility or died." Frees my slot and token. Unknown ids are ignored.
func disengage(id: int) -> void:
	_release_token(id)
	_release_slot(id)
	_member_pos.erase(id)


func is_member(id: int) -> bool:
	return _member_pos.has(id)


func get_role(id: int) -> Role:
	if _attack_since.has(id):
		return Role.ATTACKING
	if _slot_of.has(id):
		return Role.HOLDING
	if _member_pos.has(id):
		return Role.WAITING
	return Role.NONE


## Where this enemy should stand: its attack point, its slot, or a point on the waiting ring
## on its own side of the player. NONE -> the player's position.
func get_target(id: int) -> Vector2:
	match get_role(id):
		Role.ATTACKING:
			return center + slot_direction(_slot_of[id]) * settings.attack_distance
		Role.HOLDING:
			return slot_position(_slot_of[id])
		Role.WAITING:
			var away: Vector2 = _member_pos[id] - center
			var dir: Vector2 = away.normalized() if away.length() > 0.001 else slot_direction(0)
			return center + dir * settings.wait_radius
	return center


# --- Called once per frame by the owner ----------------------------------------------

func update(player_position: Vector2, delta: float) -> void:
	center = player_position
	_time += delta
	# 1. Slots that moved into a wall or behind a fence are given up (holder waits again).
	for i: int in settings.slot_count:
		if _slot_owner[i] != FREE and not is_slot_valid(i):
			var owner: int = _slot_owner[i]
			_release_token(owner)
			_release_slot(owner)
	_assign_free_slots()
	_rotate_tokens()


## Free usable slots go to waiting members, nearest to the player first; each takes the free
## slot closest to where it stands, so enemies spread out on their own side.
func _assign_free_slots() -> void:
	var waiting: Array[int] = []
	for id: int in _member_pos:
		if not _slot_of.has(id):
			waiting.append(id)
	waiting.sort_custom(func(a: int, b: int) -> bool: return _closer_to_center(a, b))
	for id: int in waiting:
		var best: int = -1
		var best_dist: float = INF
		for i: int in settings.slot_count:
			if _slot_owner[i] != FREE or not is_slot_valid(i):
				continue
			var d: float = _member_pos[id].distance_squared_to(slot_position(i))
			if d < best_dist:  # strict <: ties keep the lower slot index
				best = i
				best_dist = d
		if best < 0:
			return  # no free usable slots left
		_slot_owner[best] = id
		_slot_of[id] = best


## Attackers past token_duration hand over if someone is waiting for a token; then free
## tokens go to the holders who have waited longest (never attacked first, then nearest).
func _rotate_tokens() -> void:
	var holders_without_token: Array[int] = []
	for id: int in _slot_of:
		if not _attack_since.has(id):
			holders_without_token.append(id)
	if settings.token_duration > 0.0 and not holders_without_token.is_empty():
		var expired: Array[int] = []
		for id: int in _attack_since:
			if _time - _attack_since[id] >= settings.token_duration:
				expired.append(id)
		expired.sort()
		for id: int in expired:
			_release_token(id)
	holders_without_token.clear()
	for id: int in _slot_of:
		if not _attack_since.has(id):
			holders_without_token.append(id)
	holders_without_token.sort_custom(_waited_longer)
	for id: int in holders_without_token:
		if _attack_since.size() >= settings.max_attackers:
			break
		_attack_since[id] = _time


# --- Slots ---------------------------------------------------------------------------

func slot_direction(i: int) -> Vector2:
	return Vector2.RIGHT.rotated(TAU * i / settings.slot_count)


func slot_position(i: int) -> Vector2:
	return center + slot_direction(i) * settings.slot_radius


## A slot is usable if its tile is cheap to stand on and is a short walk from the player.
func is_slot_valid(i: int) -> bool:
	if not flow_field.is_built():
		return false
	var cell: Vector2i = flow_field.grid.coords.world_to_cell(slot_position(i))
	return flow_field.grid.get_cost(cell) <= settings.max_slot_tile_cost \
		and flow_field.get_cost(cell) <= settings.max_slot_path_cost


## Owner of slot i, or FREE.
func get_slot_owner(i: int) -> int:
	return _slot_owner[i]


func get_attacker_count() -> int:
	return _attack_since.size()


func get_member_ids() -> Array[int]:
	var ids: Array[int] = []
	ids.assign(_member_pos.keys())
	return ids


func get_member_position(id: int) -> Vector2:
	return _member_pos.get(id, center)


# --- Internals -----------------------------------------------------------------------

func _release_slot(id: int) -> void:
	if _slot_of.has(id):
		_slot_owner[_slot_of[id]] = FREE
		_slot_of.erase(id)


func _release_token(id: int) -> void:
	if _attack_since.has(id):
		_attack_since.erase(id)
		_last_attack_end[id] = _time


func _closer_to_center(a: int, b: int) -> bool:
	var da: float = _member_pos[a].distance_squared_to(center)
	var db: float = _member_pos[b].distance_squared_to(center)
	if da != db:
		return da < db
	return a < b


## Sort order for token hand-out: never attacked before anyone else, then the one whose last
## turn ended earliest, then nearest to the player, then lowest id.
func _waited_longer(a: int, b: int) -> bool:
	var la: float = _last_attack_end.get(a, -INF)
	var lb: float = _last_attack_end.get(b, -INF)
	if la != lb:
		return la < lb
	return _closer_to_center(a, b)

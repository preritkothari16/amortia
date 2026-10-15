class_name PackCoordination
extends RefCounted
## The pure rules behind cohesion (pack tactics). Takes plain numbers and positions, so it can
## be tested without a scene. The Enemy node gathers the facts and executes the result.
##
##   Sharing   when an enemy starts seeing the player, packmates within pack_radius get a lead
##             (where the player was seen). How strongly they believe it:
##                 strength = min(sender cohesion, receiver cohesion) * pack_share_strength
##             The lead is an ordinary Awareness.hear(), so it feeds the normal Investigate
##             score: a loner (low cohesion) ignores it, a pack animal follows it.
##   Regroup   a lonely cohesive enemy walks to the centroid of its engaged packmates before it
##             charges (RegroupAction); it goes once pack_needed are together or time is up.
## Nothing here changes damage, speed or aggression, and the attack ring is untouched.


## Strength (0..1) of a lead passed from one enemy to another. Both must be cohesive.
static func share_strength(sender_cohesion: float, receiver_cohesion: float, settings: UtilitySettings) -> float:
	return clampf(minf(sender_cohesion, receiver_cohesion) * settings.pack_share_strength, 0.0, 1.0)


## How many of `positions` are within `radius` of `from`.
static func count_within(from: Vector2, positions: PackedVector2Array, radius: float) -> int:
	var count: int = 0
	var r2: float = radius * radius
	for p: Vector2 in positions:
		if from.distance_squared_to(p) <= r2:
			count += 1
	return count


## Where to regroup: the centroid of the packmates within `search_radius`, or Vector2.INF if
## there are none (nobody to wait for: just go).
static func anchor(from: Vector2, positions: PackedVector2Array, search_radius: float) -> Vector2:
	var sum: Vector2 = Vector2.ZERO
	var count: int = 0
	var r2: float = search_radius * search_radius
	for p: Vector2 in positions:
		if from.distance_squared_to(p) <= r2:
			sum += p
			count += 1
	return sum / count if count > 0 else Vector2.INF


## Time an enemy has spent regrouping in this chase. Time only counts while regrouping with the
## player in view; it is forgiven after regroup_reset_seconds without seeing the player at all.
## So an enemy cannot wait indefinitely, and flickering sight cannot restart its clock.
class RegroupBudget extends RefCounted:
	var spent: float = 0.0
	var unseen: float = 0.0

	func tick(delta: float, regrouping: bool, player_seen: bool, settings: UtilitySettings) -> void:
		if player_seen:
			unseen = 0.0
			if regrouping:
				spent += delta
		else:
			unseen += delta
			if unseen >= settings.regroup_reset_seconds:
				spent = 0.0

	func expired(settings: UtilitySettings) -> bool:
		return spent >= settings.regroup_timeout

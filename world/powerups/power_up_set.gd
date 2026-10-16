class_name PowerUpSet
extends Resource
## Which power-ups exist and how they spawn (data/power_up_set.tres). Every number is data.

@export var types: Array[PowerUpType] = []
@export_group("Spawning")
## Seconds of an open wave (enemies arrived) before the first power-up, then between spawns.
@export var first_delay: float = 12.0
@export var interval: float = 25.0
## Most power-ups spawned per wave, and most lying on the map at once.
@export var max_per_wave: int = 3
@export var max_on_map: int = 2
## A power-up nobody takes disappears after this many seconds.
@export var lifetime: float = 20.0
## Spawn cells are reachable by the player and this many cells (straight line) from it: not on top
## of it, not across the whole map.
@export var min_player_distance_cells: float = 8.0
@export var max_player_distance_cells: float = 40.0
@export_group("Limits")
## No effect lasts longer than this, whatever a type says.
@export var max_duration: float = 12.0
## At most this many different timed effects (boosts, shield) at once. A power-up that would be the
## next one stays on the map until one runs out. The same kind never stacks, it refreshes.
@export var max_concurrent: int = 3


func get_type(id: StringName) -> PowerUpType:
	for t: PowerUpType in types:
		if t.id == id:
			return t
	return null


func total_weight() -> float:
	var total: float = 0.0
	for t: PowerUpType in types:
		total += maxf(t.weight, 0.0)
	return total


## The type at weighted position `roll` (0..total_weight), in list order.
func pick(roll: float) -> PowerUpType:
	var acc: float = 0.0
	for t: PowerUpType in types:
		acc += maxf(t.weight, 0.0)
		if roll < acc:
			return t
	return types[-1] if not types.is_empty() else null

class_name TerrainCosts
extends Resource
## Movement cost of each terrain type for enemy pathfinding (GDD section 4.2).
## Cost = how expensive it is to step INTO a tile of that terrain. 1 = normal ground.
## Edit data/terrain_costs.tres, not this file.

## Terrain name -> cost of entering one tile of it. Must be > 0.
@export var costs: Dictionary[String, float] = {}
## Terrain names nobody can walk through (walls, houses, map border).
@export var impassable: PackedStringArray = PackedStringArray()


## Cost of entering a tile of this terrain, or INF if it cannot be entered.
## Unknown terrain is treated as impassable so a typo can never open a hole in a wall.
func cost_of(terrain: String) -> float:
	if impassable.has(terrain) or not costs.has(terrain):
		return INF
	return costs[terrain]

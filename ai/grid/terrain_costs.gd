class_name TerrainCosts
extends Resource
## Movement-cost rules for enemy pathfinding (GDD sections 4.2 and 4.5).
## Cost = how expensive it is to step INTO a tile of that terrain. 1 = normal ground.
## Edit data/terrain_costs.tres, not this file.

## Terrain name -> base cost of entering one tile of it. Must be > 0.
@export var costs: Dictionary[String, float] = {}
## Terrain names that cannot be entered without an adaptation gene (walls, deep water, vents).
@export var impassable: PackedStringArray = PackedStringArray()
## Terrain genes: trait name -> { terrain name: cost for a fully adapted (gene = 1) creature }.
## Example: "climber": { "fence": 2.0 }. "Genes modify costs, never rules" (GDD 4.1).
@export var adaptations: Dictionary[String, Dictionary] = {}
## For terrain that is normally impassable (deep water, vents): the gene value needed
## before a creature can enter it at all.
@export_range(0.0, 1.0) var unlock_threshold: float = 0.5
## Terrain that blocks line of sight (GDD 4.2 "Blocks vision"). Fences do NOT block vision.
## Tall grass also blocks vision in the GDD - add it here when stealth is implemented.
@export var blocks_vision: PackedStringArray = PackedStringArray(["wall", "house"])


## Every terrain name these rules know about, sorted. A terrain's position in this list is
## its id, so TerrainGrid and TerrainCostProfile always agree on ids.
func get_terrain_names() -> PackedStringArray:
	var seen: Dictionary[String, bool] = {}
	for terrain: String in costs:
		seen[terrain] = true
	for terrain: String in impassable:
		seen[terrain] = true
	for trait_name: String in adaptations:
		for terrain: String in adaptations[trait_name]:
			seen[terrain] = true
	var names: PackedStringArray = PackedStringArray(seen.keys())
	names.sort()
	return names


## Base cost (no genes) of entering this terrain, or INF if it cannot be entered.
## Unknown terrain is treated as impassable so a typo can never open a hole in a wall.
func cost_of(terrain: String) -> float:
	if impassable.has(terrain) or not costs.has(terrain):
		return INF
	return costs[terrain]

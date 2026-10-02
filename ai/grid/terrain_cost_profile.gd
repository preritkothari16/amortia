class_name TerrainCostProfile
extends RefCounted
## The cost of every terrain type for one kind of mover, e.g. "base" or "climber 0.8".
## Built once from TerrainCosts + terrain genes, then looked up by terrain id: one array read.
## Enemies with similar genes can share a profile (and later, a flow field).

## Label for debug output.
var label: String = ""
## The rules this profile was built from. TerrainGrid checks it matches its own rules.
var source: TerrainCosts

## Terrain id -> cost of entering. Ids come from source.get_terrain_names().
var _cost_by_id: PackedFloat32Array = PackedFloat32Array()


## Builds a profile. `genes` maps trait name -> 0..1, e.g. {"climber": 0.8}. No genes = base costs.
##
## For each terrain, every trait that adapts it offers a cost and the cheapest wins:
##   normally passable (base b, adapted a):  cost = lerp(b, a, gene)
##   normally impassable (base INF):         cost = a once gene >= unlock_threshold, else INF
static func create(rules: TerrainCosts, genes: Dictionary[String, float] = {}, profile_label: String = "base") -> TerrainCostProfile:
	var profile: TerrainCostProfile = TerrainCostProfile.new()
	profile.label = profile_label
	profile.source = rules
	var names: PackedStringArray = rules.get_terrain_names()
	profile._cost_by_id.resize(names.size())
	for id: int in names.size():
		var terrain: String = names[id]
		var base: float = rules.cost_of(terrain)
		var best: float = base
		for trait_name: String in genes:
			var gene: float = clampf(genes[trait_name], 0.0, 1.0)
			if gene <= 0.0 or not rules.adaptations.has(trait_name):
				continue
			var adapted_costs: Dictionary = rules.adaptations[trait_name]
			if not adapted_costs.has(terrain):
				continue
			var adapted: float = adapted_costs[terrain]
			var cost: float
			if base == INF:
				cost = adapted if gene >= rules.unlock_threshold else INF
			else:
				cost = lerpf(base, adapted, gene)
			best = minf(best, cost)
		profile._cost_by_id[id] = best
	return profile


## Cost of entering a terrain by id. Ids outside the table (unknown terrain) are impassable.
func cost_of_id(id: int) -> float:
	if id < 0 or id >= _cost_by_id.size():
		return INF
	return _cost_by_id[id]


## Cheapest cost of any enterable terrain. Heuristics (A*, Greedy) multiply by this so they
## never overestimate, even for a mover with adapted costs.
func get_min_cost() -> float:
	var lowest: float = INF
	for cost: float in _cost_by_id:
		lowest = minf(lowest, cost)
	return lowest


## Same as cost_of_id but by name. Slower; meant for tests and debug output.
func cost_of(terrain: String) -> float:
	return cost_of_id(source.get_terrain_names().find(terrain))

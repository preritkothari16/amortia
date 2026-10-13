class_name TerrainCosts
extends Resource
## The shared terrain rulebook (GDD 4.1 "one rulebook for everyone", 4.2, 4.5).
## Author it as one TerrainDefinition per terrain in `definitions` (data/terrain_costs.tres):
## enemy cost, player speed, vision, noise, collision, HP, hazards, zones, greybox look.
##
## Pathfinding reads the compiled view below (`costs`, `impassable`, `adaptations`,
## `blocks_vision`), which is rebuilt from the definitions whenever they are set. Rules
## without definitions (small hand-made test rules) can fill those four fields directly.
## Cost = how expensive it is to step INTO a tile of that terrain. 1 = normal ground.

## The compiled fields; hidden and not saved when definitions exist (one source of truth).
const COMPILED_FIELDS: Array[StringName] = [&"costs", &"impassable", &"adaptations", &"blocks_vision"]

## One entry per terrain. Setting this recompiles the pathfinding view.
@export var definitions: Array[TerrainDefinition] = []:
	set(value):
		definitions = value
		rebuild()
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
## Terrain that blocks line of sight. Fences, tall grass and fog do NOT (tall grass conceals
## units inside it instead - stealth, Phase 3).
@export var blocks_vision: PackedStringArray = PackedStringArray(["wall", "house"])

var _by_id: Dictionary[String, TerrainDefinition] = {}


## Recompiles costs / impassable / adaptations / blocks_vision from `definitions`.
## Call it after editing a definition in code (setting `definitions` calls it for you).
func rebuild() -> void:
	_by_id.clear()
	if definitions.is_empty():
		return
	var new_costs: Dictionary[String, float] = {}
	var new_impassable: PackedStringArray = PackedStringArray()
	var new_adaptations: Dictionary[String, Dictionary] = {}
	var new_blocks: PackedStringArray = PackedStringArray()
	for d: TerrainDefinition in definitions:
		assert(d != null and d.id != "", "TerrainCosts: empty terrain definition")
		assert(not _by_id.has(d.id), "TerrainCosts: terrain '%s' defined twice" % d.id)
		_by_id[d.id] = d
		if d.impassable:
			new_impassable.append(d.id)
		else:
			new_costs[d.id] = d.enemy_cost
		for trait_name: String in d.adaptations:
			if not new_adaptations.has(trait_name):
				new_adaptations[trait_name] = {}
			new_adaptations[trait_name][d.id] = d.adaptations[trait_name]
		if d.vision == TerrainDefinition.Vision.BLOCKS:
			new_blocks.append(d.id)
	costs = new_costs
	impassable = new_impassable
	adaptations = new_adaptations
	blocks_vision = new_blocks
	notify_property_list_changed()


func _validate_property(property: Dictionary) -> void:
	if not definitions.is_empty() and StringName(property["name"]) in COMPILED_FIELDS:
		property["usage"] = PROPERTY_USAGE_NONE


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
	for terrain: String in _by_id:
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


## The full definition of a terrain, or null (unknown terrain, or rules without definitions).
func get_definition(terrain: String) -> TerrainDefinition:
	return _by_id.get(terrain, null)

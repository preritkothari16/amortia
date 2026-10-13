class_name TerrainDefinition
extends Resource
## Everything the game knows about one terrain type (GDD 4.2): one row of the shared rulebook.
## Player movement, enemy pathfinding, vision, noise, collision and the greybox tile all read
## these values, so the same rules apply to everyone; genes only change the enemy cost.
## Listed in data/terrain_costs.tres (TerrainCosts.definitions). Plain data, no Node use.

## How an ENEMY gets through a tile it is allowed to path into.
enum Traversal {
	WALK,   ## ordinary ground (incl. wading, hazards): move with normal collision
	CLIMB,  ## solid for physics: crossed tile centre to tile centre with collision off
	SWIM,   ## like CLIMB, through deep water (swimmer gene) - behaviour pending (Phase 2)
	CRAWL,  ## like CLIMB, through vents (crawler gene) - behaviour pending (Phase 2)
	BREAK,  ## must be destroyed first; cost = planning cost of breaking through (Phase 4)
	OPEN,   ## a closed door: opened (or broken) first; cost includes that (Phase 4)
	NONE,   ## never entered (walls, houses, trees)
}
## What the tile does to line of sight.
enum Vision {
	CLEAR,     ## see through
	BLOCKS,    ## stops line of sight (TerrainGrid.has_line_of_sight)
	CONCEALS,  ## see through, but units INSIDE are hidden (tall grass; stealth = Phase 3)
	REDUCES,   ## see through, vision range x vision_multiplier (fog)
	PARTIAL,   ## smoke: partly obscures; amount not designed yet (Phase 3/4)
}
## How loud moving through / interacting with the tile is (GDD 4.2 "Noise"). Consumed in Phase 3.
enum NoiseLevel { SILENT, QUIET, NORMAL, LOUD }
## Physical tile collision.
enum Collision {
	NONE,   ## no collision
	SOLID,  ## physics layer 1 "world": blocks movement and bullets
	WATER,  ## physics layer 7 "water": blocks walking but not bullets (deep water)
}
## Damage-over-time kind (GDD "Damage over time"); the damage itself is Phase 4.
enum Hazard { NONE, TOXIC, FIRE }
## Greybox tile pattern drawn on top of `color` (tools/build_maple_hollow.gd).
enum Pattern { FLAT, SPECKLE, BLADES, PICKETS, BRICK, OUTLINE, WAVES, RIPPLES, PLANKS, GRATE, CROSSHATCH, BLOBS, CANOPY, DOTS, FLAMES }

## Name used everywhere (tile custom data, saves, tests), e.g. "shallow_water".
@export var id: String = ""

@export_group("Enemy pathfinding")
## Cost of stepping INTO this tile in A* and the flow field (1 = normal ground).
## Ignored when `impassable` is on.
@export var enemy_cost: float = 1.0
## Cannot be entered without an adaptation gene (deep water, vents) or at all (walls).
@export var impassable: bool = false
## How an enemy physically gets through when its cost profile lets it path in.
@export var enemy_traversal: Traversal = Traversal.WALK
## Terrain genes: trait name -> cost for a fully adapted (gene = 1) creature, e.g. {"climber": 2}.
## Normally passable: cost = lerp(enemy_cost, adapted, gene). Impassable: adapted once
## gene >= TerrainCosts.unlock_threshold. See TerrainCostProfile.
@export var adaptations: Dictionary[String, float] = {}

@export_group("Player")
## Can the player walk onto it? Must match `collision` (checked by tests).
@export var player_passable: bool = true
## Player walking speed on this tile, x PlayerStats.move_speed (mud 0.6, tall grass 0.8).
@export_range(0.0, 1.0) var player_speed_multiplier: float = 1.0

@export_group("Senses")
@export var vision: Vision = Vision.CLEAR
## Vision range multiplier while looking through / standing in it (fog 0.5). Only for REDUCES.
@export_range(0.0, 1.0) var vision_multiplier: float = 1.0
@export var noise: NoiseLevel = NoiseLevel.NORMAL

@export_group("Physics and state")
@export var collision: Collision = Collision.NONE
## Hit points if destructible (fence 40, barricade 50, door 60); 0 = indestructible.
@export var max_health: float = 0.0
## Fire can spread into it (tall grass / bushes).
@export var burnable: bool = false
## Collapses after crossings / explosions (bridge). Event logic is Phase 4.
@export var collapsible: bool = false
@export var hazard: Hazard = Hazard.NONE
## Damage per second to units standing in it. 0 until designed (Phase 4).
@export var hazard_damage_per_second: float = 0.0
## Meant to sit on top of another tile (fog, fire) instead of replacing it. A second grid
## layer that combines both is Phase 4; until then it is painted as a normal tile.
@export var is_overlay: bool = false
## Zones it appears in (GDD 4.2 "Zones"): 1 Maple Hollow, 2 Lowtide, 3 Greywood, 4 Labs.
@export var zones: PackedInt32Array = PackedInt32Array([1, 2, 3, 4])

@export_group("Greybox look")
@export var color: Color = Color.MAGENTA
@export var pattern: Pattern = Pattern.FLAT


## Base enemy cost: INF when impassable.
func get_enemy_cost() -> float:
	return INF if impassable else enemy_cost


## True if the tile has physical collision that a walking unit bumps into.
func blocks_walking() -> bool:
	return collision != Collision.NONE


## Enemy traversals where the enemy turns its collision off and moves tile centre to tile
## centre (the tile is solid for physics but allowed by the cost profile).
static func crosses_solid(traversal: Traversal) -> bool:
	return traversal in [Traversal.CLIMB, Traversal.SWIM, Traversal.CRAWL]

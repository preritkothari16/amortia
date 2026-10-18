class_name GeneratedArea
extends RefCounted
## Turns a CspLevelGenerator layout into a playable area scene (a ZoneMap with its TileMap,
## player spawn, exit, enemy and behind spawns) - the same shape as the hand-made areas, so
## LevelFlow and main.gd load it like any other area.

const TILESET_PATH: String = "res://world/tilesets/greybox_tileset.tres"
const RULES_PATH: String = "res://data/terrain_costs.tres"
const ZONE_MAP_SCRIPT: String = "res://world/zones/zone_map.gd"
## Most enemy spawn markers per area (WaveManager cycles through them).
const MAX_SPAWNS: int = 8


const FAIRNESS_PATH: String = "res://data/objective_fairness.tres"


## Generates the layout for `seed_value` and packs it as a scene. null (with an error) if the
## generator fails. Stealth and Escort areas must also pass ObjectiveFairness; a layout that
## fails is replaced by the next seed of a fixed sequence (seed + k x seed_stride, at most
## max_attempts), so the same level always gets the same map. If none passes, the first one
## that generated is kept (with a warning).
static func build_scene(settings: LevelGenSettings, seed_value: int, objective_type: int = -1) -> PackedScene:
	var rules: TerrainCosts = load(RULES_PATH)
	var gen: CspLevelGenerator = CspLevelGenerator.new(settings, rules)
	var needs_check: bool = objective_type == ObjectiveConfig.Type.STEALTH or objective_type == ObjectiveConfig.Type.ESCORT
	var fairness: ObjectiveFairnessSettings = load(FAIRNESS_PATH) if needs_check else null
	var attempts: int = fairness.max_attempts if fairness != null else 1
	var first: Dictionary = {}
	for k: int in maxi(attempts, 1):
		var s: int = seed_value + k * (fairness.seed_stride if fairness != null else 0)
		var result: Dictionary = gen.generate(s)
		if not result["ok"]:
			continue
		if first.is_empty():
			first = result["layout"]
		if fairness == null or check_layout(result["layout"], rules, objective_type, fairness)["ok"]:
			return pack_layout(result["layout"], rules)
	if first.is_empty():
		push_error("Level generation failed (seed %d)" % seed_value)
		return null
	push_warning("No fair layout in %d tries from seed %d; keeping the first" % [attempts, seed_value])
	return pack_layout(first, rules)


## ObjectiveFairness on a generator layout (cells, spawn markers as GeneratedArea packs them).
static func check_layout(layout: Dictionary, rules: TerrainCosts, objective_type: int,
		fairness: ObjectiveFairnessSettings) -> Dictionary:
	var grid: TerrainGrid = TerrainGrid.from_rows(layout["rows"], rules)
	return ObjectiveFairness.check(grid, layout["player_spawn"], layout["exit"], spawn_markers(layout),
			objective_type == ObjectiveConfig.Type.STEALTH, fairness)


## The enemy spawn cells that become markers (at most MAX_SPAWNS, evenly picked).
static func spawn_markers(layout: Dictionary) -> Array[Vector2i]:
	var spawns: Array = layout["enemy_spawns"]
	var step: int = maxi(1, ceili(spawns.size() / float(MAX_SPAWNS)))
	var out: Array[Vector2i] = []
	for i: int in range(0, spawns.size(), step):
		out.append(spawns[i])
	return out


static func pack_layout(layout: Dictionary, rules: TerrainCosts) -> PackedScene:
	var column: Dictionary = {}
	for i: int in rules.definitions.size():
		column[rules.definitions[i].id] = i
	var root: Node2D = Node2D.new()
	root.name = "GeneratedArea"
	root.set_script(load(ZONE_MAP_SCRIPT))
	var layer: TileMapLayer = TileMapLayer.new()
	layer.name = "Terrain"
	layer.tile_set = load(TILESET_PATH)
	root.add_child(layer)
	layer.owner = root
	var rows: Array[PackedStringArray] = layout["rows"]
	for y: int in rows.size():
		for x: int in rows[y].size():
			layer.set_cell(Vector2i(x, y), 0, Vector2i(column.get(rows[y][x], 0), 0))
	_marker(root, root, "PlayerSpawn", layout["player_spawn"])
	_marker(root, root, "Exit", layout["exit"])
	var groups: Array = [["EnemySpawns", spawn_markers(layout)], ["BehindSpawns", (layout["behind_spawns"] as Array).slice(0, 2)]]
	for group: Array in groups:
		var parent: Node2D = Node2D.new()
		parent.name = group[0]
		root.add_child(parent)
		parent.owner = root
		for i: int in (group[1] as Array).size():
			_marker(root, parent, "Spawn%d" % (i + 1), group[1][i])
	var packed: PackedScene = PackedScene.new()
	packed.pack(root)
	root.free()
	return packed


static func _marker(root: Node, parent: Node, marker_name: String, cell: Vector2i) -> void:
	var m: Marker2D = Marker2D.new()
	m.name = marker_name
	m.position = Vector2(cell * 16) + Vector2(8, 8)
	parent.add_child(m)
	m.owner = root

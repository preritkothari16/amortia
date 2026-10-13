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


## Generates the layout for `seed_value` and packs it as a scene. null (with an error) if the
## generator fails.
static func build_scene(settings: LevelGenSettings, seed_value: int) -> PackedScene:
	var rules: TerrainCosts = load(RULES_PATH)
	var gen: CspLevelGenerator = CspLevelGenerator.new(settings, rules)
	var result: Dictionary = gen.generate(seed_value)
	if not result["ok"]:
		push_error("Level generation failed (seed %d): %s" % [seed_value, result["error"]])
		return null
	return pack_layout(result["layout"], rules)


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
	var spawns: Array = layout["enemy_spawns"]
	var step: int = maxi(1, ceili(spawns.size() / float(MAX_SPAWNS)))
	var groups: Array = [["EnemySpawns", []], ["BehindSpawns", (layout["behind_spawns"] as Array).slice(0, 2)]]
	for i: int in range(0, spawns.size(), step):
		groups[0][1].append(spawns[i])
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

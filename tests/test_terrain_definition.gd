extends GutTest
## Tests for the shared terrain rulebook: TerrainDefinition entries in data/terrain_costs.tres,
## the pathfinding view TerrainCosts compiles from them, the per-cell lookups on TerrainGrid,
## and that collision, the tileset and A* / flow field all agree with the definitions.

const T: GDScript = preload("res://ai/grid/terrain_definition.gd")
const RULES_PATH: String = "res://data/terrain_costs.tres"
const TILESET_PATH: String = "res://world/tilesets/greybox_tileset.tres"
const WATER_LAYER_BIT: int = 1 << 6
## Traversals the Enemy node can perform: WALK, CLIMB / SWIM / CRAWL (collision off, tile to
## tile), BREAK (hit a barricade until it breaks), OPEN (open a door), NONE.
const IMPLEMENTED_TRAVERSALS: Array[int] = [T.Traversal.WALK, T.Traversal.CLIMB, T.Traversal.SWIM,
	T.Traversal.CRAWL, T.Traversal.BREAK, T.Traversal.OPEN, T.Traversal.NONE]

var _rules: TerrainCosts


func before_each() -> void:
	_rules = load(RULES_PATH)


func _def(id: String) -> TerrainDefinition:
	var d: TerrainDefinition = _rules.get_definition(id)
	assert_not_null(d, id)
	return d


# --- The table (GDD 4.2 / expansion spec section A) -----------------------------------

func test_every_required_terrain_is_defined_once() -> void:
	var ids: Array[String] = []
	for d: TerrainDefinition in _rules.definitions:
		assert_false(ids.has(d.id), "duplicate " + d.id)
		ids.append(d.id)
	for id: String in ["road", "grass", "mud", "shallow_water", "deep_water", "tall_grass", "fence",
			"tree", "wall", "house", "barricade", "door", "vent", "bridge", "fog", "toxic_pool", "fire",
			"ash", "door_open", "living_wall", "gate"]:
		assert_true(ids.has(id), id)


func test_maple_hollow_tiles_keep_their_atlas_columns() -> void:
	# The existing map stores atlas columns 0-5; reordering the rulebook would repaint it.
	var expected: Array[String] = ["road", "grass", "tall_grass", "fence", "wall", "house"]
	for i: int in expected.size():
		assert_eq(_rules.definitions[i].id, expected[i])


func test_enemy_costs_and_adaptations_match_the_table() -> void:
	var cost: Dictionary = {
		"road": 1.0, "grass": 1.0, "mud": 3.0, "shallow_water": 3.0, "deep_water": INF,
		"tall_grass": 2.0, "fence": 6.0, "tree": INF, "wall": INF, "house": INF, "barricade": 5.0,
		"door": 2.0, "vent": INF, "bridge": 1.0, "fog": 1.0, "toxic_pool": 8.0, "fire": 20.0,
	}
	for id: String in cost:
		assert_eq(_def(id).get_enemy_cost(), cost[id], id)
		assert_eq(_rules.cost_of(id), cost[id], id + " (compiled)")
	assert_eq(_def("shallow_water").adaptations, {"swimmer": 1.0} as Dictionary[String, float])
	assert_eq(_def("deep_water").adaptations, {"swimmer": 2.0} as Dictionary[String, float])
	assert_eq(_def("fence").adaptations, {"climber": 2.0} as Dictionary[String, float])
	assert_eq(_def("vent").adaptations, {"crawler": 1.0} as Dictionary[String, float])
	assert_eq(_def("toxic_pool").adaptations, {"toxin_resistance": 2.0} as Dictionary[String, float])


func test_player_columns_match_the_table() -> void:
	var speed: Dictionary = {
		"road": 1.0, "grass": 1.0, "mud": 0.6, "shallow_water": 0.6, "tall_grass": 0.8,
		"door": 1.0, "bridge": 1.0, "fog": 1.0, "toxic_pool": 1.0, "fire": 1.0,
	}
	for id: String in speed:
		assert_almost_eq(_def(id).player_speed_multiplier, speed[id], 0.0001, id)
	for id: String in ["road", "grass", "mud", "shallow_water", "tall_grass", "bridge", "fog", "toxic_pool", "fire"]:
		assert_true(_def(id).player_passable, id)
	# A closed door is solid; "100% when accessible" = once opened (Phase 4 door states).
	for id: String in ["deep_water", "fence", "tree", "wall", "house", "barricade", "door", "vent"]:
		assert_false(_def(id).player_passable, id)


func test_vision_noise_and_state_columns() -> void:
	for id: String in ["wall", "tree", "house", "barricade", "door", "vent"]:
		assert_eq(_def(id).vision, T.Vision.BLOCKS, id)
	assert_eq(_def("tall_grass").vision, T.Vision.CONCEALS)
	assert_eq(_def("fog").vision, T.Vision.REDUCES)
	assert_almost_eq(_def("fog").vision_multiplier, 0.5, 0.0001)
	assert_eq(_def("fire").vision, T.Vision.PARTIAL)
	for id: String in ["road", "grass", "mud", "shallow_water", "deep_water", "fence", "bridge", "toxic_pool"]:
		assert_eq(_def(id).vision, T.Vision.CLEAR, id)
	assert_eq(_def("grass").noise, T.NoiseLevel.QUIET)
	assert_eq(_def("tall_grass").noise, T.NoiseLevel.QUIET)
	assert_eq(_def("mud").noise, T.NoiseLevel.LOUD)
	assert_eq(_def("shallow_water").noise, T.NoiseLevel.LOUD)
	assert_eq(_def("fence").noise, T.NoiseLevel.LOUD)
	assert_eq(_def("road").noise, T.NoiseLevel.NORMAL)
	assert_eq(_def("fence").max_health, 40.0)
	assert_eq(_def("barricade").max_health, 50.0)
	assert_eq(_def("door").max_health, 60.0)
	assert_true(_def("tall_grass").burnable)
	assert_true(_def("bridge").collapsible)
	assert_eq(_def("toxic_pool").hazard, T.Hazard.TOXIC)
	assert_eq(_def("fire").hazard, T.Hazard.FIRE)
	assert_true(_def("fog").is_overlay)
	assert_true(_def("fire").is_overlay)
	assert_false(_def("road").is_overlay)


# --- Compiled pathfinding view --------------------------------------------------------

func test_compiled_view_comes_from_the_definitions() -> void:
	var blocks: PackedStringArray = _rules.blocks_vision.duplicate()
	blocks.sort()
	assert_eq(blocks, PackedStringArray(["barricade", "door", "gate", "house", "living_wall", "tree", "vent", "wall"]))
	assert_false(_rules.blocks_vision.has("fence"), "fences don't block vision")
	assert_false(_rules.blocks_vision.has("tall_grass"), "tall grass conceals, it doesn't block lines")
	var impassable: PackedStringArray = _rules.impassable.duplicate()
	impassable.sort()
	assert_eq(impassable, PackedStringArray(["deep_water", "gate", "house", "living_wall", "tree", "vent", "wall"]))
	assert_eq(_rules.adaptations["swimmer"], {"shallow_water": 1.0, "deep_water": 2.0})
	assert_eq(_rules.get_terrain_names().size(), _rules.definitions.size())


func test_compiled_fields_are_not_saved_when_definitions_exist() -> void:
	for p: Dictionary in _rules.get_property_list():
		if StringName(p["name"]) in TerrainCosts.COMPILED_FIELDS:
			assert_eq(p["usage"] & PROPERTY_USAGE_STORAGE, 0, "%s must not be stored" % p["name"])


func test_setting_definitions_in_code_recompiles() -> void:
	var rules: TerrainCosts = TerrainCosts.new()
	var mud: TerrainDefinition = TerrainDefinition.new()
	mud.id = "mud"
	mud.enemy_cost = 3.0
	mud.adaptations = {"swimmer": 1.0}
	var rock: TerrainDefinition = TerrainDefinition.new()
	rock.id = "rock"
	rock.impassable = true
	rock.vision = T.Vision.BLOCKS
	rules.definitions = [mud, rock]
	assert_eq(rules.cost_of("mud"), 3.0)
	assert_eq(rules.cost_of("rock"), INF)
	assert_eq(rules.blocks_vision, PackedStringArray(["rock"]))
	assert_eq(rules.adaptations, {"swimmer": {"mud": 1.0}} as Dictionary[String, Dictionary])
	assert_eq(rules.get_definition("mud"), mud)
	assert_null(rules.get_definition("lava"))


func test_hand_written_rules_without_definitions_still_work() -> void:
	var rules: TerrainCosts = TerrainCosts.new()
	rules.costs = {"road": 1.0}
	rules.impassable = PackedStringArray(["wall"])
	assert_eq(rules.cost_of("road"), 1.0)
	assert_null(rules.get_definition("road"))
	var g: TerrainGrid = TerrainGrid.from_rows([PackedStringArray(["road", "wall"])], rules)
	assert_eq(g.player_speed_multiplier(Vector2i(0, 0)), 1.0)
	assert_eq(g.enemy_traversal(Vector2i(0, 0)), T.Traversal.WALK)


# --- Consistency between collision, the player and enemy traversal --------------------

func test_player_passable_means_no_collision() -> void:
	for d: TerrainDefinition in _rules.definitions:
		assert_eq(d.player_passable, not d.blocks_walking(), d.id)


func test_every_enterable_tile_has_a_traversal_mechanic() -> void:
	# Enterable = base cost < INF, or some adaptation gene at 1.0 opens it.
	for d: TerrainDefinition in _rules.definitions:
		var enterable: bool = d.get_enemy_cost() < INF or not d.adaptations.is_empty()
		if not enterable:
			assert_eq(d.enemy_traversal, T.Traversal.NONE, d.id + ": never entered")
		elif not d.blocks_walking():
			assert_eq(d.enemy_traversal, T.Traversal.WALK, d.id + ": open ground is walked")
		else:
			assert_true(d.enemy_traversal in [T.Traversal.CLIMB, T.Traversal.SWIM, T.Traversal.CRAWL,
				T.Traversal.BREAK, T.Traversal.OPEN], d.id + ": solid but enterable needs a mechanic")


func test_maple_hollow_only_uses_implemented_mechanics() -> void:
	var map: ZoneMap = load("res://world/zones/maple_hollow/maple_hollow.tscn").instantiate()
	add_child_autofree(map)
	var used: Dictionary[String, bool] = {}
	for row: PackedStringArray in map.get_terrain_rows():
		for terrain: String in row:
			used[terrain] = true
	for terrain: String in used:
		var d: TerrainDefinition = _rules.get_definition(terrain)
		assert_not_null(d, terrain)
		assert_true(d.enemy_traversal in IMPLEMENTED_TRAVERSALS, "%s needs a pending mechanic" % terrain)
	assert_eq(used.keys().size(), 6, "Maple Hollow still uses its 6 terrains")


# --- TerrainGrid lookups --------------------------------------------------------------

func _rows(lines: Array) -> Array[PackedStringArray]:
	var rows: Array[PackedStringArray] = []
	for line: Array in lines:
		rows.append(PackedStringArray(line))
	return rows


func test_grid_lookups_read_the_definitions() -> void:
	var g: TerrainGrid = TerrainGrid.from_rows(_rows([
		["road", "mud", "tall_grass", "shallow_water"],
		["fence", "deep_water", "vent", "barricade"],
	]), _rules)
	assert_eq(g.player_speed_multiplier(Vector2i(0, 0)), 1.0)
	assert_almost_eq(g.player_speed_multiplier(Vector2i(1, 0)), 0.6, 0.0001)
	assert_almost_eq(g.player_speed_multiplier(Vector2i(2, 0)), 0.8, 0.0001)
	assert_almost_eq(g.player_speed_multiplier(Vector2i(3, 0)), 0.6, 0.0001)
	assert_eq(g.player_speed_multiplier(Vector2i(-1, 0)), 1.0, "off the map")
	assert_eq(g.enemy_traversal(Vector2i(0, 0)), T.Traversal.WALK)
	assert_eq(g.enemy_traversal(Vector2i(0, 1)), T.Traversal.CLIMB)
	assert_eq(g.enemy_traversal(Vector2i(1, 1)), T.Traversal.SWIM)
	assert_eq(g.enemy_traversal(Vector2i(2, 1)), T.Traversal.CRAWL)
	assert_eq(g.enemy_traversal(Vector2i(3, 1)), T.Traversal.BREAK)
	assert_eq(g.enemy_traversal(Vector2i(9, 9)), T.Traversal.NONE, "off the map")
	assert_eq(g.get_definition(Vector2i(1, 0)), _def("mud"))
	assert_true(g.blocks_vision(Vector2i(2, 1)), "vents block vision")
	assert_false(g.blocks_vision(Vector2i(0, 1)), "fences don't")


func test_gene_profiles_from_the_data() -> void:
	var g: TerrainGrid = TerrainGrid.from_rows(_rows([["fence", "deep_water", "vent", "toxic_pool", "shallow_water"]]), _rules)
	assert_eq(g.get_cost(Vector2i(0, 0), g.make_profile({"climber": 1.0})), 2.0)
	assert_eq(g.get_cost(Vector2i(1, 0), g.make_profile({"swimmer": 0.5})), 2.0, "unlocked at the threshold")
	assert_eq(g.get_cost(Vector2i(1, 0), g.make_profile({"swimmer": 0.49})), INF)
	assert_eq(g.get_cost(Vector2i(2, 0), g.make_profile({"crawler": 0.4})), INF)
	assert_eq(g.get_cost(Vector2i(3, 0), g.make_profile({"toxin_resistance": 0.5})), 5.0)
	assert_eq(g.get_cost(Vector2i(4, 0), g.make_profile({"swimmer": 1.0})), 1.0)


func test_flow_field_matches_astar_on_every_data_terrain() -> void:
	# Same costs feed both searches: field cost at every cell = A* cost to the target, for the
	# base profile and for adapted profiles, on random grids using every terrain in the data.
	var names: PackedStringArray = _rules.get_terrain_names()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 29
	var gene_sets: Array[Dictionary] = [{}, {"swimmer": 0.8, "climber": 0.6}, {"crawler": 1.0, "toxin_resistance": 0.7}]
	for trial: int in 9:
		var rows: Array[PackedStringArray] = []
		for y: int in 7:
			var row: PackedStringArray = PackedStringArray()
			for x: int in 9:
				# Half road so most grids stay connected.
				row.append("road" if rng.randf() < 0.5 else names[rng.randi_range(0, names.size() - 1)])
			rows.append(row)
		var g: TerrainGrid = TerrainGrid.from_rows(rows, _rules)
		var genes: Dictionary[String, float] = {}
		genes.assign(gene_sets[trial % gene_sets.size()])
		var profile: TerrainCostProfile = g.make_profile(genes) if not genes.is_empty() else null
		var target: Vector2i = Vector2i(rng.randi_range(0, 8), rng.randi_range(0, 6))
		g.set_terrain(target, "road")
		var field: FlowField = FlowField.new(g)
		field.build(target, profile)
		var astar: AStar = AStar.new(g)
		for y: int in g.height:
			for x: int in g.width:
				var cell: Vector2i = Vector2i(x, y)
				astar.find_path(cell, target, profile)
				if astar.last_cost == INF:
					assert_false(field.is_reachable(cell), "trial %d %s" % [trial, cell])
				else:
					assert_almost_eq(field.get_cost(cell), astar.last_cost, 0.0001, "trial %d %s" % [trial, cell])


# --- Tileset and physics --------------------------------------------------------------

func test_tileset_tiles_follow_the_definitions() -> void:
	var tileset: TileSet = load(TILESET_PATH)
	var source: TileSetAtlasSource = tileset.get_source(0)
	assert_eq(tileset.get_physics_layer_collision_layer(0), 1, "SOLID -> layer 1 world")
	assert_eq(tileset.get_physics_layer_collision_layer(1), WATER_LAYER_BIT, "WATER -> layer 7 water")
	for i: int in _rules.definitions.size():
		var d: TerrainDefinition = _rules.definitions[i]
		var data: TileData = source.get_tile_data(Vector2i(i, 0), 0)
		assert_not_null(data, d.id)
		assert_eq(data.get_custom_data(ZoneMap.TERRAIN_DATA_LAYER), d.id)
		assert_eq(data.get_collision_polygons_count(0) > 0, d.collision == T.Collision.SOLID, d.id + " solid")
		assert_eq(data.get_collision_polygons_count(1) > 0, d.collision == T.Collision.WATER, d.id + " water")


func test_every_tile_looks_different() -> void:
	var tileset: TileSet = load(TILESET_PATH)
	var image: Image = (tileset.get_source(0) as TileSetAtlasSource).texture.get_image()
	var tiles: Array[PackedByteArray] = []
	var means: Array[Color] = []
	for i: int in _rules.definitions.size():
		var tile: Image = image.get_region(Rect2i(i * 16, 0, 16, 16))
		tiles.append(tile.get_data())
		var sum: Vector3 = Vector3.ZERO
		for y: int in 16:
			for x: int in 16:
				var c: Color = tile.get_pixel(x, y)
				sum += Vector3(c.r, c.g, c.b)
		sum /= 256.0
		means.append(Color(sum.x, sum.y, sum.z))
	for a: int in tiles.size():
		for b: int in range(a + 1, tiles.size()):
			var names: String = "%s vs %s" % [_rules.definitions[a].id, _rules.definitions[b].id]
			assert_ne(tiles[a], tiles[b], names)
			var diff: Color = means[a] - means[b]
			# Average colours far enough apart to tell at native resolution (RGB distance).
			assert_gt(Vector3(diff.r, diff.g, diff.b).length(), 0.08, names)


func _tile_layer(rows: Array[PackedStringArray]) -> TileMapLayer:
	var layer: TileMapLayer = TileMapLayer.new()
	layer.tile_set = load(TILESET_PATH)
	for y: int in rows.size():
		for x: int in rows[y].size():
			var column: int = _rules.definitions.find(_rules.get_definition(rows[y][x]))
			layer.set_cell(Vector2i(x, y), 0, Vector2i(column, 0))
	add_child_autofree(layer)
	return layer


func test_deep_water_blocks_walking_but_not_bullets() -> void:
	_tile_layer(_rows([["road", "deep_water", "fence"]]))
	await wait_physics_frames(2)
	var space: PhysicsDirectSpaceState2D = get_tree().root.world_2d.direct_space_state
	var query: PhysicsPointQueryParameters2D = PhysicsPointQueryParameters2D.new()
	query.position = Vector2(24, 8)  # centre of the deep water tile
	var player: Player = load("res://entities/player/player.tscn").instantiate()
	var enemy: Enemy = load("res://entities/enemies/base_enemy.tscn").instantiate()
	var bullet: Node = load("res://entities/projectiles/bullet.tscn").instantiate()
	query.collision_mask = player.collision_mask
	assert_false(space.intersect_point(query).is_empty(), "player collides with deep water")
	query.collision_mask = enemy.collision_mask
	assert_false(space.intersect_point(query).is_empty(), "walking enemies collide with deep water")
	query.collision_mask = bullet.get("collision_mask")
	assert_true(space.intersect_point(query).is_empty(), "bullets fly over water")
	query.position = Vector2(40, 8)  # fence
	assert_false(space.intersect_point(query).is_empty(), "bullets still hit fences (world layer)")
	query.position = Vector2(8, 8)  # road
	query.collision_mask = player.collision_mask
	assert_true(space.intersect_point(query).is_empty())
	player.free()
	enemy.free()
	bullet.free()


func test_player_walks_slower_on_mud_and_tall_grass() -> void:
	var rows: Array[PackedStringArray] = []
	for terrain: String in ["road", "mud", "tall_grass"]:
		var row: PackedStringArray = PackedStringArray()
		row.resize(30)
		row.fill(terrain)
		rows.append(row)
	_tile_layer(rows)
	var player: Player = load("res://entities/player/player.tscn").instantiate()
	player.terrain_grid = TerrainGrid.from_rows(rows, _rules)
	add_child_autofree(player)
	var measured: Dictionary = {}
	Input.action_press("move_right")
	for lane: int in 3:
		player.global_position = Vector2(24, lane * 16 + 8)
		player.velocity = Vector2.ZERO
		await wait_physics_frames(30)
		var start: float = player.global_position.x
		await wait_physics_frames(30)
		measured[rows[lane][0]] = (player.global_position.x - start) / 0.5  # px per second
	Input.action_release("move_right")
	var full: float = player.stats.move_speed
	assert_almost_eq(measured["road"], full, full * 0.05)
	assert_almost_eq(measured["mud"], full * 0.6, full * 0.05)
	assert_almost_eq(measured["tall_grass"], full * 0.8, full * 0.05)

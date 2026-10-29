extends GutTest
## Atmosphere layers are look-only: they must stay where they belong (lamps on walkable ground),
## be the same every time for the same map, and show the damage stages of breakable tiles at the
## right HP. The buildings themselves are covered by test_architecture.gd.

const MAP: Array[String] = [
	"gggggggggggg",
	"ghhhhhhhgggg",
	"ghhhhhhhgfff",
	"ghhhhhhhgggg",
	"ghhhhhhhgggg",
	"gggggggggggg",
	"rrrrrrrrrrrr",
	"rrrrrrrrrrrr",
	"gggwwwwggggg",
	"gggggggggggg",
]
const NAMES: Dictionary[String, String] = {"g": "grass", "h": "house", "r": "road", "w": "wall", "f": "fence"}

var _rules: TerrainCosts = load("res://data/terrain_costs.tres")


func before_all() -> void:
	BuildingDetail.bake_buildings = true  # headless runs skip the bake by default


func after_all() -> void:
	BuildingDetail.bake_buildings = DisplayServer.get_name() != "headless"


func _grid() -> TerrainGrid:
	var rows: Array[PackedStringArray] = []
	for line: String in MAP:
		var row: PackedStringArray = PackedStringArray()
		for c: String in line:
			row.append(NAMES[c])
		rows.append(row)
	return TerrainGrid.from_rows(rows, _rules)


func _detail(grid: TerrainGrid, zone: int) -> BuildingDetail:
	var d: BuildingDetail = BuildingDetail.new()
	add_child_autofree(d)
	d.setup(grid, zone, 99)
	return d


func test_damage_stages_follow_the_hp_thirds() -> void:
	assert_eq(TerrainView.damage_stage(1.0), TerrainView.DamageStage.INTACT)
	assert_eq(TerrainView.damage_stage(0.7), TerrainView.DamageStage.INTACT)
	assert_eq(TerrainView.damage_stage(0.66), TerrainView.DamageStage.CRACKED)
	assert_eq(TerrainView.damage_stage(0.34), TerrainView.DamageStage.CRACKED)
	assert_eq(TerrainView.damage_stage(1.0 / 3.0), TerrainView.DamageStage.HEAVY)
	assert_eq(TerrainView.damage_stage(0.05), TerrainView.DamageStage.HEAVY)


func test_building_detail_is_the_same_for_the_same_map() -> void:
	var grid: TerrainGrid = _grid()
	for zone: int in 4:
		var a: BuildingDetail = _detail(grid, zone)
		var b: BuildingDetail = _detail(grid, zone)
		assert_gt(a.rect_count(), 0, "zone %d draws detail" % zone)
		assert_eq(a._rects, b._rects, "zone %d: seeded, identical" % zone)


func test_roof_holes_and_facades_never_spill_onto_the_ground() -> void:
	# Pure charcoal (roof holes, collapsed sections, doorways) only ever lies on solid cells, so
	# nothing dark on walkable ground can be mistaken for a pit or a wall.
	var grid: TerrainGrid = _grid()
	for zone: int in 4:
		for entry: Array in _detail(grid, zone)._rects:
			var r: Rect2 = entry[0]
			var c: Color = entry[1]
			if not c.is_equal_approx(BuildingDetail.CHARCOAL):
				continue
			for p: Vector2 in [r.position, r.end - Vector2(0.5, 0.5)]:
				var cell: Vector2i = grid.coords.world_to_cell(p)
				assert_false(grid.get_definition(cell).player_passable,
						"zone %d: charcoal at %s is on walkable %s" % [zone, p, grid.get_terrain(cell)])


func test_building_detail_follows_terrain_changes() -> void:
	var grid: TerrainGrid = _grid()
	var d: BuildingDetail = _detail(grid, 0)
	var before: int = d.rect_count()
	for x: int in range(3, 7):
		grid.set_terrain(Vector2i(x, 8), "grass")  # the wall is gone
	await wait_process_frames(2)
	assert_ne(d.rect_count(), before, "rebuilt after the terrain changed")


func test_lamps_stand_on_walkable_cells_below_buildings_and_keep_their_spacing() -> void:
	var grid: TerrainGrid = _grid()
	var settings: VisualFxSettings = load("res://data/visual_fx.tres")
	var lights: AmbientLights = AmbientLights.new()
	add_child_autofree(lights)
	lights.setup(grid, settings, 0, 5)
	assert_gt(lights.lamp_count(), 0)
	assert_lte(lights.lamp_count(), settings.lamp_count)
	for i: int in lights._lamps.size():
		var at: Vector2 = lights._lamps[i][0]
		var cell: Vector2i = grid.coords.world_to_cell(at)
		assert_true(grid.get_definition(cell).player_passable, "lamp on walkable ground")
		var above: String = grid.get_terrain(cell + Vector2i.UP)
		assert_true(above == "house" or above == "wall", "against a building or wall")
		for j: int in range(i + 1, lights._lamps.size()):
			assert_gte(at.distance_to(lights._lamps[j][0]), settings.lamp_spacing)


func test_broken_tile_leaves_rubble() -> void:
	var decals: GroundDecals = GroundDecals.new()
	add_child_autofree(decals)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	decals.add_rubble(Rect2(32, 32, 16, 16), "fence", rng)
	assert_eq(decals._splats.size(), 1)
	for entry: Array in decals._splats[0]:
		assert_true(Rect2(32, 32, 16, 16).encloses(entry[0]), "rubble stays in the broken cell")


func test_wordmark_bakes_its_textures() -> void:
	var logo: Wordmark = Wordmark.new()
	add_child_autofree(logo)
	assert_not_null(logo._letters)
	assert_gt(logo.custom_minimum_size.x, 150.0)
	assert_lt(logo.custom_minimum_size.x, 480.0, "fits the 480 px screen")

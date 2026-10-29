extends GutTest
## Building architecture (FacadeBuilder, BuildingArchetypes, district data): every type bakes on
## the footprints it claims, stays solid exactly where it collides, never draws over blocked
## cells, shows a facade rather than a big flat roof, and each level gets its own district.

var _rules: TerrainCosts = load("res://data/terrain_costs.tres")
var _arch: ArchitectureSettings = load(ArchitectureSettings.PATH)

const LOOK: Dictionary = {"decay": 0.5, "infection": 0.5, "overgrowth": 0.5, "flood": 1.0, "burned": true, "collapse": true}


func before_all() -> void:
	BuildingDetail.bake_buildings = true  # headless runs skip the bake by default


func after_all() -> void:
	BuildingDetail.bake_buildings = DisplayServer.get_name() != "headless"


func _bake(id: StringName, size: Vector2i, zone: int, look: Dictionary, seed_value: int, blocked: Dictionary = {}) -> FacadeBuilder:
	var b: FacadeBuilder = FacadeBuilder.new()
	b.set_meta("image", b.bake(size, id, zone, look, seed_value, blocked))
	return b


func test_every_type_bakes_solid_on_its_smallest_and_largest_footprint() -> void:
	for id: StringName in BuildingArchetypes.INFO:
		for size: Vector2i in BuildingArchetypes.INFO[id]:
			for zone: int in 4:
				var b: FacadeBuilder = _bake(id, size, zone, LOOK, 7 + zone)
				var img: Image = b.get_meta("image")
				assert_eq(img.get_size(), size * FacadeBuilder.TILE + Vector2i.ONE * FacadeBuilder.MARGIN * 2)
				for fy: int in b.height:
					for fx: int in b.width:
						if img.get_pixel(fx + FacadeBuilder.MARGIN, fy + FacadeBuilder.MARGIN).a < 1.0:
							fail_test("%s %s z%d: see-through at %d,%d" % [id, size, zone, fx, fy])
							return
	pass_test("every footprint fully opaque")


func test_nothing_is_drawn_over_blocked_cells_round_a_building() -> void:
	# A wall west and a fence south-east of a 4x4 building: the shadow and debris skip them.
	var blocked: Dictionary = {Vector2i(-1, 1): true, Vector2i(4, 4): true, Vector2i(2, 4): true}
	for id: StringName in [&"house", &"supermarket", &"warehouse", &"hospital", &"checkpoint", &"lab_tower"]:
		var size: Vector2i = BuildingArchetypes.INFO[id][0]
		var b: FacadeBuilder = _bake(id, Vector2i(maxi(size.x, 5), maxi(size.y, 4)), 0, LOOK, 3, blocked)
		var img: Image = b.get_meta("image")
		for cell: Vector2i in blocked:
			for y: int in 16:
				for x: int in 16:
					var ix: int = cell.x * 16 + x + FacadeBuilder.MARGIN
					var iy: int = cell.y * 16 + y + FacadeBuilder.MARGIN
					if ix >= 0 and iy >= 0 and ix < img.get_width() and iy < img.get_height() and img.get_pixel(ix, iy).a > 0.0:
						fail_test("%s draws over blocked cell %s" % [id, cell])
						return
	pass_test("blocked cells left clear")


func test_buildings_show_a_facade_not_a_flat_roof() -> void:
	# From the game's three-quarter view the front wall is what you see: roof (and the roof's
	# stuff) stays well under half of every footprint.
	for id: StringName in BuildingArchetypes.INFO:
		for size: Vector2i in [BuildingArchetypes.INFO[id][0], Vector2i(7, 5)]:
			if not BuildingArchetypes.fits(id, size):
				continue
			var look: Dictionary = {"decay": 0.3, "infection": 0.0, "overgrowth": 0.0}
			var b: FacadeBuilder = _bake(id, size, 0, look, 11)
			var roof: int = 0
			for fy: int in b.height:
				for fx: int in b.width:
					if b.part_at(fx, fy) == FacadeBuilder.Part.ROOF:
						roof += 1
			assert_lt(float(roof) / (b.width * b.height), 0.4, "%s %s: roof share" % [id, size])


func test_bake_is_deterministic() -> void:
	var a: Image = _bake(&"apartment", Vector2i(5, 4), 1, LOOK, 42).get_meta("image")
	var b: Image = _bake(&"apartment", Vector2i(5, 4), 1, LOOK, 42).get_meta("image")
	assert_eq(a.get_data(), b.get_data())


func test_every_campaign_level_has_a_district_of_its_zone() -> void:
	var seen: Dictionary = {}
	for z: int in range(1, 5):
		for l: int in range(1, 5):
			var level: LevelConfig = load("res://data/levels/z%d_l%d.tres" % [z, l])
			var d: DistrictStyle = _arch.district_for(level.id, level.zone)
			assert_not_null(d, level.id)
			assert_true(d.levels.has(level.id), "%s is named by its district" % level.id)
			assert_eq(d.zone, level.zone, level.id)
			assert_false(seen.has(d.id), "%s: one district per level" % level.id)
			seen[d.id] = true
	for d: DistrictStyle in _arch.districts:
		for id: StringName in d.archetypes:
			assert_true(BuildingArchetypes.INFO.has(id), "%s: unknown type %s" % [d.id, id])
		assert_true(d.landmark == &"" or BuildingArchetypes.INFO.has(d.landmark), d.id)


func test_no_skyscrapers_in_the_forest() -> void:
	for d: DistrictStyle in _arch.districts:
		if d.zone == 3:
			for id: StringName in [&"tower", &"office", &"apartment", &"mall", &"hotel"]:
				assert_false(d.archetypes.has(id), "%s has a %s" % [d.id, id])


func test_sunnyseed_labs_grow_more_infected_level_by_level() -> void:
	var prev: float = -1.0
	for l: int in range(1, 5):
		var d: DistrictStyle = _arch.district_for("z4_l%d" % l, 4)
		assert_gt(d.infection, prev, "z4_l%d more infected than the level before" % l)
		prev = d.infection
	# And it shows: more growth pixels on the same building.
	var clean: FacadeBuilder = _bake(&"lab", Vector2i(5, 4), 3, {"infection": 0.03}, 5)
	var overrun: FacadeBuilder = _bake(&"lab", Vector2i(5, 4), 3, {"infection": 1.0}, 5)
	assert_lt(_count(clean, FacadeBuilder.Part.GROWTH) * 4, _count(overrun, FacadeBuilder.Part.GROWTH))


func _count(b: FacadeBuilder, part: FacadeBuilder.Part) -> int:
	var n: int = 0
	for fy: int in b.height:
		for fx: int in b.width:
			if b.part_at(fx, fy) == part:
				n += 1
	return n


func _grid(rows_text: Array[String]) -> TerrainGrid:
	var rows: Array[PackedStringArray] = []
	for line: String in rows_text:
		var row: PackedStringArray = PackedStringArray()
		for c: String in line:
			row.append("house" if c == "h" else "grass")
		rows.append(row)
	return TerrainGrid.from_rows(rows, _rules)


func test_a_district_raises_a_mix_of_its_own_types_that_fit() -> void:
	var rows: Array[String] = []
	for y: int in 12:
		var line: String = ""
		for x: int in 40:
			line += "h" if (x % 6 < 4 and y % 6 < 4) else "g"
		rows.append(line)
	var grid: TerrainGrid = _grid(rows)  # 14 buildings of 4x4
	var d: DistrictStyle = _arch.district_for("z1_l2", 1)
	var detail: BuildingDetail = BuildingDetail.new()
	add_child_autofree(detail)
	detail.setup(grid, 0, 99, d)
	var types: Dictionary[Vector2i, StringName] = detail.types()
	assert_eq(types.size(), 14)
	var distinct: Dictionary = {}
	for t: StringName in types.values():
		assert_true(d.archetypes.has(t), "%s is a commercial-street type" % t)
		assert_true(BuildingArchetypes.fits(t, Vector2i(4, 4)))
		distinct[t] = true
	assert_gte(distinct.size(), 4, "a street, not one building repeated")


func test_an_l_shaped_group_is_split_into_rectangular_buildings() -> void:
	var grid: TerrainGrid = _grid(["hhhhhhg", "hhhhhhg", "hhhhhhg", "hhhhggg", "hhhhggg", "ggggggg"] as Array[String])
	var detail: BuildingDetail = BuildingDetail.new()
	add_child_autofree(detail)
	detail.setup(grid, 0, 5)
	var covered: int = 0
	for lo: Vector2i in detail.types():
		covered += (detail._baked[lo][4] as Vector2i).x * (detail._baked[lo][4] as Vector2i).y
	assert_eq(covered, 26, "every house cell belongs to exactly one building")


func test_pixel_font() -> void:
	assert_eq(PixelFont.width("HOSPITAL"), 31)
	assert_true(PixelFont.ink("H", 0, 0))
	assert_false(PixelFont.ink("H", 1, 0))
	assert_false(PixelFont.ink("~", 0, 0), "unknown glyphs draw nothing")

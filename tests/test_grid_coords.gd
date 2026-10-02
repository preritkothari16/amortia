extends GutTest
## Tests for GridCoords (world pixels <-> grid cells).


func test_world_to_cell_inside_tiles() -> void:
	var c: GridCoords = GridCoords.new(16)
	assert_eq(c.world_to_cell(Vector2(0, 0)), Vector2i(0, 0))
	assert_eq(c.world_to_cell(Vector2(15.9, 15.9)), Vector2i(0, 0))
	assert_eq(c.world_to_cell(Vector2(16, 0)), Vector2i(1, 0))
	assert_eq(c.world_to_cell(Vector2(488, 280)), Vector2i(30, 17), "Maple Hollow player spawn")


func test_negative_positions_floor() -> void:
	var c: GridCoords = GridCoords.new(16)
	assert_eq(c.world_to_cell(Vector2(-1, -1)), Vector2i(-1, -1), "floors, not truncates towards 0")
	assert_eq(c.world_to_cell(Vector2(-16, 0)), Vector2i(-1, 0))
	assert_eq(c.world_to_cell(Vector2(-16.1, 0)), Vector2i(-2, 0))


func test_cell_to_world_is_centre() -> void:
	var c: GridCoords = GridCoords.new(16)
	assert_eq(c.cell_to_world(Vector2i(0, 0)), Vector2(8, 8))
	assert_eq(c.cell_to_world(Vector2i(2, 1)), Vector2(40, 24))


func test_round_trip() -> void:
	var c: GridCoords = GridCoords.new(16, Vector2(100, -50))
	for cell: Vector2i in [Vector2i(0, 0), Vector2i(5, 9), Vector2i(-3, 2)]:
		assert_eq(c.world_to_cell(c.cell_to_world(cell)), cell)


func test_origin_offset() -> void:
	var c: GridCoords = GridCoords.new(16, Vector2(100, 200))
	assert_eq(c.world_to_cell(Vector2(100, 200)), Vector2i(0, 0))
	assert_eq(c.world_to_cell(Vector2(99, 200)), Vector2i(-1, 0))
	assert_eq(c.cell_to_world(Vector2i(0, 0)), Vector2(108, 208))


func test_cell_rect() -> void:
	var c: GridCoords = GridCoords.new(16)
	assert_eq(c.cell_rect(Vector2i(1, 2)), Rect2(16, 32, 16, 16))


func test_other_tile_size() -> void:
	var c: GridCoords = GridCoords.new(32)
	assert_eq(c.world_to_cell(Vector2(33, 70)), Vector2i(1, 2))
	assert_eq(c.cell_to_world(Vector2i(1, 2)), Vector2(48, 80))

extends GutTest
## Tests for the pure steering helpers.


func test_seek_full_speed_along_direction() -> void:
	assert_eq(Steering.seek(Vector2.RIGHT, 70.0), Vector2(70, 0))
	assert_almost_eq(Steering.seek(Vector2(3, 4), 10.0), Vector2(6, 8), Vector2(0.001, 0.001), "normalises")
	assert_eq(Steering.seek(Vector2.ZERO, 70.0), Vector2.ZERO)


func test_arrive_slows_inside_radius() -> void:
	assert_eq(Steering.arrive(Vector2(100, 0), 60.0, 20.0), Vector2(60, 0), "outside radius: full speed")
	assert_eq(Steering.arrive(Vector2(10, 0), 60.0, 20.0), Vector2(30, 0), "half way in: half speed")
	assert_eq(Steering.arrive(Vector2.ZERO, 60.0, 20.0), Vector2.ZERO, "on target: stop")


func test_separation_pushes_away() -> void:
	var push: Vector2 = Steering.separation(Vector2.ZERO, PackedVector2Array([Vector2(5, 0)]), 10.0)
	assert_almost_eq(push, Vector2(-0.5, 0), Vector2(0.001, 0.001))


func test_separation_closer_pushes_harder() -> void:
	var near: Vector2 = Steering.separation(Vector2.ZERO, PackedVector2Array([Vector2(2, 0)]), 10.0)
	var far: Vector2 = Steering.separation(Vector2.ZERO, PackedVector2Array([Vector2(8, 0)]), 10.0)
	assert_gt(near.length(), far.length())


func test_separation_ignores_far_and_overlapping() -> void:
	var others: PackedVector2Array = PackedVector2Array([Vector2(10, 0), Vector2(50, 50), Vector2.ZERO])
	assert_eq(Steering.separation(Vector2.ZERO, others, 10.0), Vector2.ZERO)


func test_separation_balanced_neighbours_cancel() -> void:
	var others: PackedVector2Array = PackedVector2Array([Vector2(4, 0), Vector2(-4, 0)])
	assert_almost_eq(Steering.separation(Vector2.ZERO, others, 10.0), Vector2.ZERO, Vector2(0.001, 0.001))


func test_blend_caps_speed() -> void:
	var v: Vector2 = Steering.blend(Vector2(70, 0), Vector2(1, 0), 1.0, 70.0)
	assert_almost_eq(v.length(), 70.0, 0.001)
	var sideways: Vector2 = Steering.blend(Vector2(70, 0), Vector2(0, 1), 0.5, 70.0)
	assert_gt(sideways.y, 0.0, "push bends the path")
	assert_almost_eq(sideways.length(), 70.0, 0.001)

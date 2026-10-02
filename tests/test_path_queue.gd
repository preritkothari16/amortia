extends GutTest
## Tests for PathQueue: budgeted, cached A* requests.


func _queue(lines: Array[String]) -> PathQueue:
	var rules: TerrainCosts = TerrainCosts.new()
	rules.costs = {"road": 1.0}
	rules.impassable = PackedStringArray(["wall"])
	var rows: Array[PackedStringArray] = []
	for line: String in lines:
		var row: PackedStringArray = PackedStringArray()
		for c: String in line:
			row.append("wall" if c == "#" else "road")
		rows.append(row)
	return PathQueue.new(AStar.new(TerrainGrid.from_rows(rows, rules)))


func _open(w: int, h: int) -> PathQueue:
	var lines: Array[String] = []
	for y: int in h:
		lines.append(".".repeat(w))
	return _queue(lines)


func test_result_arrives_after_process() -> void:
	var q: PathQueue = _open(5, 1)
	q.request(1, Vector2i(0, 0), Vector2i(4, 0))
	assert_false(q.has_result(1))
	assert_true(q.is_pending(1))
	q.process()
	assert_true(q.has_result(1))
	assert_eq(q.take_result(1), [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0)])
	assert_false(q.has_result(1), "taken results are forgotten")


func test_no_path_gives_empty_result() -> void:
	var q: PathQueue = _queue(["..#.."])
	q.request(1, Vector2i(0, 0), Vector2i(4, 0))
	q.process()
	assert_true(q.has_result(1))
	assert_true(q.take_result(1).is_empty())


func test_max_searches_per_frame() -> void:
	var q: PathQueue = _open(10, 10)
	q.max_per_frame = 2
	q.budget_usec = 1000000
	for id: int in range(1, 6):
		q.request(id, Vector2i(0, id), Vector2i(9, 9 - id))
	q.process()
	assert_eq(q.searches_run, 2)
	assert_eq(q.pending_count(), 3)
	q.process()
	q.process()
	assert_eq(q.pending_count(), 0)
	for id: int in range(1, 6):
		assert_true(q.has_result(id))


func test_time_budget_still_runs_at_least_one() -> void:
	var q: PathQueue = _open(10, 10)
	q.budget_usec = 0
	q.request(1, Vector2i(0, 0), Vector2i(9, 9))
	q.request(2, Vector2i(0, 9), Vector2i(9, 0))
	q.process()
	assert_eq(q.searches_run, 1, "zero budget: exactly one search per frame")
	q.process()
	assert_eq(q.searches_run, 2)


func test_same_request_is_cached() -> void:
	var q: PathQueue = _open(8, 8)
	q.request(1, Vector2i(0, 0), Vector2i(7, 7))
	q.process()
	q.take_result(1)
	q.request(2, Vector2i(0, 0), Vector2i(7, 7))
	assert_true(q.has_result(2), "answered at once from the cache")
	assert_eq(q.cache_hits, 1)
	assert_eq(q.searches_run, 1)


func test_start_on_cached_path_reuses_tail() -> void:
	var q: PathQueue = _open(6, 1)
	q.request(1, Vector2i(0, 0), Vector2i(5, 0))
	q.process()
	q.request(2, Vector2i(2, 0), Vector2i(5, 0))
	assert_true(q.has_result(2))
	assert_eq(q.take_result(2), [Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0), Vector2i(5, 0)])
	assert_eq(q.reuse_hits, 1)
	assert_eq(q.searches_run, 1)


func test_newer_request_replaces_older() -> void:
	var q: PathQueue = _open(6, 6)
	q.request(1, Vector2i(0, 0), Vector2i(5, 5))
	q.request(1, Vector2i(0, 0), Vector2i(5, 0))
	assert_eq(q.pending_count(), 1)
	q.process()
	var path: Array[Vector2i] = q.take_result(1)
	assert_eq(path[-1], Vector2i(5, 0))


func test_cancel_drops_request_and_result() -> void:
	var q: PathQueue = _open(6, 6)
	q.request(1, Vector2i(0, 0), Vector2i(5, 5))
	q.cancel(1)
	assert_eq(q.pending_count(), 0)
	q.request(2, Vector2i(0, 0), Vector2i(5, 5))
	q.process()
	q.cancel(2)
	assert_false(q.has_result(2))


func test_cache_is_bounded() -> void:
	var q: PathQueue = _open(10, 10)
	q.max_cache_size = 3
	q.max_per_frame = 100
	q.budget_usec = 1000000
	for id: int in range(1, 6):
		q.request(id, Vector2i(id, 0), Vector2i(0, 9))
	q.process()
	q.request(99, Vector2i(1, 0), Vector2i(0, 9))
	assert_false(q.has_result(99), "early entries were evicted when the cache filled up")

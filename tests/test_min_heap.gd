extends GutTest
## Tests for MinHeap (priority queue used by A* and Dijkstra).


func test_starts_empty() -> void:
	var h: MinHeap = MinHeap.new()
	assert_true(h.is_empty())
	assert_eq(h.size(), 0)


func test_pops_in_priority_order() -> void:
	var h: MinHeap = MinHeap.new()
	var priorities: Array[float] = [5.0, 1.0, 4.0, 2.0, 3.0, 0.5, 9.0]
	for p: float in priorities:
		h.push(p, p)
	var out: Array = []
	while not h.is_empty():
		out.append(h.pop())
	assert_eq(out, [0.5, 1.0, 2.0, 3.0, 4.0, 5.0, 9.0])


func test_equal_priorities_are_fifo() -> void:
	var h: MinHeap = MinHeap.new()
	h.push("a", 1.0)
	h.push("b", 1.0)
	h.push("c", 0.0)
	h.push("d", 1.0)
	assert_eq([h.pop(), h.pop(), h.pop(), h.pop()], ["c", "a", "b", "d"])


func test_peek_does_not_remove() -> void:
	var h: MinHeap = MinHeap.new()
	h.push(Vector2i(1, 1), 3.0)
	h.push(Vector2i(2, 2), 2.0)
	assert_eq(h.peek_priority(), 2.0)
	assert_eq(h.size(), 2)


func test_interleaved_push_pop_matches_sorted() -> void:
	var h: MinHeap = MinHeap.new()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 42
	var reference: Array[float] = []
	for i: int in 300:
		var p: float = rng.randf_range(0.0, 100.0)
		h.push(p, p)
		reference.append(p)
		if i % 3 == 0:
			reference.sort()
			assert_eq(h.pop(), reference.pop_front())
	reference.sort()
	while not h.is_empty():
		assert_eq(h.pop(), reference.pop_front())
	assert_true(reference.is_empty())

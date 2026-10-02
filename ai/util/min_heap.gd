class_name MinHeap
extends RefCounted
## Binary min-heap priority queue: pop() always returns the item with the lowest priority.
## Used as the "open list" by A* and Dijkstra. push and pop are O(log n).
##
## Stored as an array where the children of index i are at 2i+1 and 2i+2, and every parent
## has a priority <= its children. So the smallest item is always at index 0.
## Equal priorities come out in the order they were pushed (FIFO), which keeps results
## deterministic for tests and experiments.

var _items: Array = []
var _priorities: PackedFloat64Array = PackedFloat64Array()
## Insertion counter per entry, used only to break priority ties.
var _order: PackedInt64Array = PackedInt64Array()
var _next_order: int = 0


func size() -> int:
	return _items.size()


func is_empty() -> bool:
	return _items.is_empty()


func push(item: Variant, priority: float) -> void:
	_items.append(item)
	_priorities.append(priority)
	_order.append(_next_order)
	_next_order += 1
	_sift_up(_items.size() - 1)


## Lowest priority without removing it. Only call when not empty.
func peek_priority() -> float:
	return _priorities[0]


## Removes and returns the item with the lowest priority. Only call when not empty.
func pop() -> Variant:
	assert(not _items.is_empty(), "MinHeap: pop() on empty heap")
	var top: Variant = _items[0]
	# Move the last entry to the root, shrink, then let it sink to its place.
	var last: int = _items.size() - 1
	_swap(0, last)
	_items.resize(last)
	_priorities.resize(last)
	_order.resize(last)
	if last > 0:
		_sift_down(0)
	return top


## True if entry a should come out before entry b.
func _less(a: int, b: int) -> bool:
	if _priorities[a] != _priorities[b]:
		return _priorities[a] < _priorities[b]
	return _order[a] < _order[b]


## Move a new entry up while it is smaller than its parent.
func _sift_up(i: int) -> void:
	while i > 0:
		var parent: int = (i - 1) / 2
		if not _less(i, parent):
			return
		_swap(i, parent)
		i = parent


## Move an entry down while one of its children is smaller.
func _sift_down(i: int) -> void:
	var n: int = _items.size()
	while true:
		var smallest: int = i
		var left: int = 2 * i + 1
		var right: int = left + 1
		if left < n and _less(left, smallest):
			smallest = left
		if right < n and _less(right, smallest):
			smallest = right
		if smallest == i:
			return
		_swap(i, smallest)
		i = smallest


func _swap(a: int, b: int) -> void:
	var item: Variant = _items[a]
	_items[a] = _items[b]
	_items[b] = item
	var p: float = _priorities[a]
	_priorities[a] = _priorities[b]
	_priorities[b] = p
	var o: int = _order[a]
	_order[a] = _order[b]
	_order[b] = o

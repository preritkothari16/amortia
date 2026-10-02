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
	# Take the last entry off the end, then sink it down from the root (the hole left by top).
	var last: int = _items.size() - 1
	var item: Variant = _items[last]
	var priority: float = _priorities[last]
	var order: int = _order[last]
	_items.resize(last)
	_priorities.resize(last)
	_order.resize(last)
	if last > 0:
		_sift_down(item, priority, order)
	return top


## Moves the entry at index i up to its place. Uses a "hole": parents that are larger are
## shifted down one level, and the entry is written once at the end (fewer writes than swapping).
func _sift_up(i: int) -> void:
	var item: Variant = _items[i]
	var priority: float = _priorities[i]
	var order: int = _order[i]
	while i > 0:
		var parent: int = (i - 1) >> 1
		var pp: float = _priorities[parent]
		# Stop when the parent should come out first (smaller priority, or tie and older).
		if pp < priority or (pp == priority and _order[parent] < order):
			break
		_move(parent, i)
		i = parent
	_put(i, item, priority, order)


## Places an entry starting at the root hole and moves it down while a child is smaller.
func _sift_down(item: Variant, priority: float, order: int) -> void:
	var n: int = _items.size()
	var i: int = 0
	while true:
		var child: int = 2 * i + 1
		if child >= n:
			break
		# Pick the smaller of the two children.
		var right: int = child + 1
		if right < n:
			var cp: float = _priorities[child]
			var rp: float = _priorities[right]
			if rp < cp or (rp == cp and _order[right] < _order[child]):
				child = right
		var chp: float = _priorities[child]
		if priority < chp or (priority == chp and order < _order[child]):
			break
		_move(child, i)
		i = child
	_put(i, item, priority, order)


## Copies entry `from` into slot `to`.
func _move(from: int, to: int) -> void:
	_items[to] = _items[from]
	_priorities[to] = _priorities[from]
	_order[to] = _order[from]


func _put(i: int, item: Variant, priority: float, order: int) -> void:
	_items[i] = item
	_priorities[i] = priority
	_order[i] = order

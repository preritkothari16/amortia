class_name PathQueue
extends RefCounted
## Shares one AStar between many enemies without frame spikes (GDD 6.4: limited searches per
## frame, results cached). Enemies request a path and pick up the result a frame or more later.
##
##   request(id, start, goal)
##     1. exact (start, goal) seen before        -> answer at once from the cache
##     2. start lies on a cached path to `goal`  -> answer at once with the rest of that path
##     3. otherwise queue it; a newer request from the same id replaces the older one
##   process()  (once per frame)
##     run queued searches in order until `budget_usec` is used up or `max_per_frame` are done
##     (always at least one, so the queue keeps moving)

var astar: AStar
## Time budget per process() call, in microseconds.
var budget_usec: int = 2000
## Hard cap on searches per process() call (GDD: max 4).
var max_per_frame: int = 4
## The cache is emptied when it grows past this many paths.
var max_cache_size: int = 256

## Stats for debugging / experiments.
var searches_run: int = 0
var cache_hits: int = 0
var reuse_hits: int = 0
var last_process_usec: int = 0

## Waiting requests in arrival order: [id, start, goal].
var _queue: Array[Array] = []
## Finished results waiting to be picked up: id -> path ([] = no path).
var _results: Dictionary[int, Array] = {}
## (start, goal) packed as Vector4i -> path.
var _cache: Dictionary[Vector4i, Array] = {}
## goal -> list of cached paths ending there, for tail reuse.
var _paths_to_goal: Dictionary[Vector2i, Array] = {}


func _init(search: AStar) -> void:
	astar = search


func request(id: int, start: Vector2i, goal: Vector2i) -> void:
	cancel(id)
	var key: Vector4i = Vector4i(start.x, start.y, goal.x, goal.y)
	if _cache.has(key):
		cache_hits += 1
		_results[id] = _cache[key]
		return
	var tail: Array[Vector2i] = _reuse_tail(start, goal)
	if not tail.is_empty():
		reuse_hits += 1
		_results[id] = tail
		return
	_queue.append([id, start, goal])


## Drops any queued request and unread result for this id (e.g. the enemy died).
func cancel(id: int) -> void:
	_results.erase(id)
	for i: int in range(_queue.size() - 1, -1, -1):
		if _queue[i][0] == id:
			_queue.remove_at(i)


func is_pending(id: int) -> bool:
	for entry: Array in _queue:
		if entry[0] == id:
			return true
	return false


func has_result(id: int) -> bool:
	return _results.has(id)


## Returns and forgets the result. [] = no path exists.
func take_result(id: int) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	path.assign(_results.get(id, []))
	_results.erase(id)
	return path


func pending_count() -> int:
	return _queue.size()


## Runs queued searches within the budget. Call once per physics frame.
func process() -> void:
	var start_usec: int = Time.get_ticks_usec()
	var done: int = 0
	while not _queue.is_empty() and done < max_per_frame:
		if done > 0 and Time.get_ticks_usec() - start_usec >= budget_usec:
			break
		var entry: Array = _queue.pop_front()
		var path: Array[Vector2i] = astar.find_path(entry[1], entry[2])
		searches_run += 1
		done += 1
		_store(entry[1], entry[2], path)
		_results[entry[0]] = path
	last_process_usec = Time.get_ticks_usec() - start_usec


## Forget every cached path (call when the terrain changes).
func clear_cache() -> void:
	_cache.clear()
	_paths_to_goal.clear()


func _store(start: Vector2i, goal: Vector2i, path: Array[Vector2i]) -> void:
	if _cache.size() >= max_cache_size:
		clear_cache()
	_cache[Vector4i(start.x, start.y, goal.x, goal.y)] = path
	if not path.is_empty():
		if not _paths_to_goal.has(goal):
			_paths_to_goal[goal] = []
		_paths_to_goal[goal].append(path)


## If `start` is on a cached cheapest path to `goal`, the rest of that path is also a cheapest
## path from `start` (every part of a shortest path is itself shortest).
func _reuse_tail(start: Vector2i, goal: Vector2i) -> Array[Vector2i]:
	var tail: Array[Vector2i] = []
	for path: Array in _paths_to_goal.get(goal, []):
		var i: int = path.find(start)
		if i >= 0:
			tail.assign(path.slice(i))
			return tail
	return tail

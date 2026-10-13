class_name FlowFieldSet
extends RefCounted
## One flow field per KIND of mover (GDD 6.1 #9 "terrain cost profiles"), all pointing at the
## same target (the player's cell).
##
## Why not one field per enemy: a field costs ~8 ms to build and is rebuilt whenever the
## player changes cell. Why not one field for everyone: a climber would follow arrows made for
## a non-climber and never take its shortcut over the fence.
##
## So profiles are put in buckets. The bucket key is the profile's cost of every terrain that
## actually appears on the map, rounded to `cost_step` (INF stays INF):
##     key = "fence:4|grass:1|road:1|..."
## Genes for terrain that isn't on the map don't split buckets (a swimmer on a dry map shares
## the base field). The first profile seen for a key becomes that bucket's REPRESENTATIVE: its
## field, its A* searches and its climbing speed all use the representative's costs, so flow
## field and A* stay consistent for every member of the bucket.
##
## Rebuilds: the base field (bucket of the base profile) is rebuilt at once by set_target();
## other buckets are marked stale and rebuilt by process(), at most `max_rebuilds_per_frame`
## per call, oldest first. A stale field still leads to where the player was a moment ago,
## which is fine for following arrows. Deterministic: depends on frame order, not on time.

## Rounding step for bucket keys (1.0: fence cost 6 / 5 / 4 / 3 / 2 for climber genes).
var cost_step: float = 1.0
## Extra (non-base) rebuilds per process() call.
var max_rebuilds_per_frame: int = 1
## Upper limit on buckets; profiles that would need more fall back to the base field.
var max_fields: int = 16

var grid: TerrainGrid
## The bucket every gene-less enemy, the attack ring and the flank planner use.
var base_field: FlowField

## key -> FlowField, and key -> representative profile.
var _fields: Dictionary[String, FlowField] = {}
var _profiles: Dictionary[String, TerrainCostProfile] = {}
## Keys whose field is out of date, oldest first.
var _stale: Array[String] = []
var _base_key: String = ""
var _target: Vector2i = Vector2i.ZERO
var _has_target: bool = false
## Terrain ids present on the map (only these go into keys). Refreshed by refresh_terrain().
var _present_ids: PackedInt32Array = PackedInt32Array()
var _names: PackedStringArray = PackedStringArray()


func _init(terrain_grid: TerrainGrid) -> void:
	grid = terrain_grid
	refresh_terrain()
	base_field = FlowField.new(grid)
	_base_key = key_of(grid.base_profile)
	_fields[_base_key] = base_field
	_profiles[_base_key] = grid.base_profile


## Re-reads which terrain ids are on the map. Call after the map is swapped or terrain changed.
## Existing buckets keep their keys (they stay valid, just possibly finer than needed).
func refresh_terrain() -> void:
	_present_ids = grid.present_terrain_ids()
	_names = grid.base_profile.source.get_terrain_names()


## The bucket key of a profile (see class comment).
func key_of(profile: TerrainCostProfile) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for id: int in _present_ids:
		var cost: float = profile.cost_of_id(id)
		parts.append("%s:%s" % [_names[id], "INF" if cost == INF else str(snappedf(cost, cost_step))])
	return "|".join(parts)


## The profile an enemy with these costs should navigate with: the representative of its
## bucket (registered on first use). Falls back to the base profile beyond max_fields.
func canonical_profile(profile: TerrainCostProfile) -> TerrainCostProfile:
	if profile == null:
		return grid.base_profile
	var key: String = key_of(profile)
	if not _profiles.has(key):
		if _fields.size() >= max_fields:
			return grid.base_profile
		profile.label = key
		_profiles[key] = profile
		var field: FlowField = FlowField.new(grid)
		_fields[key] = field
		if _has_target:
			field.build(_target, profile)  # first use: build now so it's never empty
	return _profiles[key]


## The field for a (canonical) profile. Unknown profile -> base field.
func field_for(profile: TerrainCostProfile) -> FlowField:
	if profile == null:
		return base_field
	return _fields.get(key_of(profile), base_field)


## New target (player's cell): base field now, the others queued.
func set_target(cell: Vector2i) -> void:
	_target = cell
	_has_target = true
	base_field.build(cell, grid.base_profile)
	for key: String in _fields:
		if key != _base_key and not _stale.has(key):
			_stale.append(key)


## Terrain changed: every field is out of date. Base rebuilt now, the rest queued.
func invalidate_all() -> void:
	if _has_target:
		set_target(_target)


## Rebuilds up to max_rebuilds_per_frame stale fields. Call once per physics frame.
func process() -> void:
	var done: int = 0
	while done < max_rebuilds_per_frame and not _stale.is_empty():
		var key: String = _stale.pop_front()
		if _fields.has(key):
			_fields[key].build(_target, _profiles[key])
			done += 1


## Builds every stale field now (tests, or right after a map swap).
func flush() -> void:
	while not _stale.is_empty():
		var key: String = _stale.pop_front()
		_fields[key].build(_target, _profiles[key])


func field_count() -> int:
	return _fields.size()


func stale_count() -> int:
	return _stale.size()


## Representative profiles of every bucket (debug overlays).
func get_profiles() -> Array[TerrainCostProfile]:
	var list: Array[TerrainCostProfile] = []
	for key: String in _profiles:
		list.append(_profiles[key])
	return list

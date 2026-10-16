class_name PlayerModifiers
extends RefCounted
## The player's stat layers, applied to COPIES of the base resources (data/player_stats.tres and the
## equipped weapon are never modified):
##   base  ->  research (permanent, saved, capped)  ->  temporary effects (power-ups, never saved)
## The two sources are separate lists. Clearing the temporary layer returns exactly to the
## permanent values; nothing a power-up does is ever written into base or research.

signal changed()

## Permanent: from unlocked research (ResearchState.modifiers()).
var research: Array[StatModifier] = []
## Temporary: id -> {"mods": Array[StatModifier], "left": seconds}. One entry per id, so the same
## effect refreshes instead of stacking.
var _temporary: Dictionary = {}


func set_research(mods: Array[StatModifier]) -> void:
	research = mods.duplicate()
	changed.emit()


## Starts (or refreshes) a temporary effect. Same id = refresh the time, never a second copy.
func add_temporary(id: StringName, mods: Array[StatModifier], seconds: float) -> void:
	_temporary[id] = {"mods": mods.duplicate(), "left": seconds}
	changed.emit()


func has_temporary(id: StringName) -> bool:
	return _temporary.has(id)


func temporary_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for id: Variant in _temporary:
		ids.append(id)
	return ids


func time_left(id: StringName) -> float:
	return _temporary[id]["left"] if _temporary.has(id) else 0.0


func clear_temporary() -> void:
	if not _temporary.is_empty():
		_temporary.clear()
		changed.emit()


## Counts the timers down; effects that ran out are removed (and `changed` fires once).
func tick(delta: float) -> void:
	var expired: Array = []
	for id: Variant in _temporary:
		_temporary[id]["left"] -= delta
		if _temporary[id]["left"] <= 0.0:
			expired.append(id)
	for id: Variant in expired:
		_temporary.erase(id)
	if not expired.is_empty():
		changed.emit()


## Copy of `base` with research, then temporary effects, applied. `target` picks which modifiers count.
func apply(base: Resource, target: StatModifier.Target) -> Resource:
	var result: Resource = base.duplicate()
	for m: StatModifier in research:
		_apply_one(result, m, target)
	for id: Variant in _temporary:
		for m: StatModifier in _temporary[id]["mods"]:
			_apply_one(result, m, target)
	return result


func _apply_one(result: Resource, m: StatModifier, target: StatModifier.Target) -> void:
	if m.target == target:
		result.set(m.property, m.apply_to(result.get(m.property)))

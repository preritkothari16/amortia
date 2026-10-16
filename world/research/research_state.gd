class_name ResearchState
extends RefCounted
## Which research projects are finished, and the rules for starting one. Permanent and saved with
## the campaign. Costs come from the tree's data; resources are passed in (GameState holds them),
## so this is plain logic that can be tested without a scene.
##
##   status(id, scrap, samples, zone) -> OK or the reason it can't be done now
##   unlock(...)                      -> checks, then marks it done (caller pays the cost)
##   modifiers()                      -> the StatModifiers of all finished projects (what Player applies)
## Caps are hard: a project that would push its group over the cap is refused (and a damaged save
## that does is trimmed on load).

enum Status { OK, OWNED, UNKNOWN, MISSING_PREREQUISITE, ZONE_TOO_EARLY, CAP_REACHED, NOT_ENOUGH_SCRAP, NOT_ENOUGH_SAMPLES }

var tree: ResearchTree
var unlocked: Array[StringName] = []


func _init(research_tree: ResearchTree) -> void:
	tree = research_tree


func is_unlocked(id: StringName) -> bool:
	return unlocked.has(id)


## Total the finished projects of `group` already add.
func group_total(group: StringName) -> float:
	var total: float = 0.0
	for id: StringName in unlocked:
		var n: ResearchNode = tree.get_node_by_id(id)
		if n != null and n.cap_group == group:
			total += n.group_amount()
	return total


func status(id: StringName, scrap: int, samples: int, zone: int) -> Status:
	var n: ResearchNode = tree.get_node_by_id(id)
	if n == null:
		return Status.UNKNOWN
	if is_unlocked(id):
		return Status.OWNED
	for required: StringName in n.requires:
		if not is_unlocked(required):
			return Status.MISSING_PREREQUISITE
	if zone < n.min_zone:
		return Status.ZONE_TOO_EARLY
	if n.cap_group != &"" and tree.group_caps.has(n.cap_group) \
			and group_total(n.cap_group) + n.group_amount() > tree.group_caps[n.cap_group] + 0.0001:
		return Status.CAP_REACHED
	if scrap < n.cost_scrap:
		return Status.NOT_ENOUGH_SCRAP
	if samples < n.cost_samples:
		return Status.NOT_ENOUGH_SAMPLES
	return Status.OK


## Marks the project done if status() is OK. The caller subtracts n.cost_* from the resources.
func unlock(id: StringName, scrap: int, samples: int, zone: int) -> bool:
	if status(id, scrap, samples, zone) != Status.OK:
		return false
	unlocked.append(id)
	return true


## Every modifier of every finished project, in the order they were finished.
func modifiers() -> Array[StatModifier]:
	var list: Array[StatModifier] = []
	for id: StringName in unlocked:
		var n: ResearchNode = tree.get_node_by_id(id)
		if n != null:
			list.append_array(n.modifiers)
	return list


static func describe(s: Status) -> String:
	match s:
		Status.OK: return ""
		Status.OWNED: return "done"
		Status.UNKNOWN: return "unknown"
		Status.MISSING_PREREQUISITE: return "needs an earlier project"
		Status.ZONE_TOO_EARLY: return "not available yet"
		Status.CAP_REACHED: return "at the permanent limit"
		Status.NOT_ENOUGH_SCRAP: return "not enough scrap"
		Status.NOT_ENOUGH_SAMPLES: return "not enough samples"
	return ""


func to_array() -> Array:
	return Array(unlocked).map(func(i: StringName) -> String: return String(i))


## Restores finished projects from a saved list: unknown ids, duplicates, projects whose
## prerequisites are missing and projects past a cap are dropped (in order).
func restore(ids: Variant) -> PackedStringArray:
	var dropped: PackedStringArray = PackedStringArray()
	unlocked.clear()
	if not ids is Array:
		return dropped
	for raw: Variant in ids:
		var id: StringName = StringName(str(raw))
		var n: ResearchNode = tree.get_node_by_id(id) if raw is String else null
		if n == null or unlocked.has(id):
			dropped.append("research %s dropped" % [raw])
			continue
		if not n.requires.all(func(r: StringName) -> bool: return unlocked.has(r)):
			dropped.append("research %s dropped: prerequisite missing" % id)
			continue
		if n.cap_group != &"" and tree.group_caps.has(n.cap_group) \
				and group_total(n.cap_group) + n.group_amount() > tree.group_caps[n.cap_group] + 0.0001:
			dropped.append("research %s dropped: over the cap" % id)
			continue
		unlocked.append(id)
	return dropped

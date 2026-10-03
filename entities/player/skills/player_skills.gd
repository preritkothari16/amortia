class_name PlayerSkills
extends RefCounted
## Which skill nodes the player owns, and the rules for buying them. Plain data so it can be
## tested headless; points come from PlayerProgression. Lives on the Player like the XP.

## Emitted after a node is unlocked. The player rebuilds its stats from this.
signal changed()

## Why a node can't be bought. OK = it can.
enum Status { OK, OWNED, MISSING_PREREQUISITE, NOT_ENOUGH_POINTS, UNKNOWN }

var tree: SkillTree
var progression: PlayerProgression
## Unlocked node ids, in the order they were bought.
var unlocked: Array[StringName] = []


func _init(p_tree: SkillTree, p_progression: PlayerProgression) -> void:
	tree = p_tree
	progression = p_progression


func is_unlocked(id: StringName) -> bool:
	return unlocked.has(id)


## Whether `id` can be bought now, and if not, why.
func check(id: StringName) -> Status:
	var node: SkillNode = tree.get_node_by_id(id)
	if node == null:
		return Status.UNKNOWN
	if is_unlocked(id):
		return Status.OWNED
	for required: StringName in node.requires:
		if not is_unlocked(required):
			return Status.MISSING_PREREQUISITE
	if progression.skill_points < node.cost:
		return Status.NOT_ENOUGH_POINTS
	return Status.OK


## Spends the points and unlocks the node. Returns false (and changes nothing) if not allowed.
func unlock(id: StringName) -> bool:
	if check(id) != Status.OK:
		return false
	var node: SkillNode = tree.get_node_by_id(id)
	for i: int in node.cost:
		progression.spend_skill_point()
	unlocked.append(id)
	changed.emit()
	return true


## Sets the owned nodes from a validated save without spending points (the save's
## skill_points already account for them).
func restore(ids: Array[StringName]) -> void:
	unlocked = ids.duplicate()
	changed.emit()


## Copy of `base` with every unlocked node aimed at `target` applied (in purchase order).
## The base resource is never modified, so this can be rebuilt at any time.
func apply(base: Resource, target: SkillNode.Target) -> Resource:
	var result: Resource = base.duplicate()
	for id: StringName in unlocked:
		var node: SkillNode = tree.get_node_by_id(id)
		if node.target == target:
			result.set(node.property, node.apply_to(result.get(node.property)))
	return result

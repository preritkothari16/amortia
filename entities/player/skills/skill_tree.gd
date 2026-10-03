class_name SkillTree
extends Resource
## All skill nodes the player can buy (data/skill_tree.tres).

@export var nodes: Array[SkillNode] = []


func get_node_by_id(id: StringName) -> SkillNode:
	for node: SkillNode in nodes:
		if node.id == id:
			return node
	return null


## Nodes of one branch, ordered by tier.
func branch_nodes(branch: SkillNode.Branch) -> Array[SkillNode]:
	var result: Array[SkillNode] = nodes.filter(func(n: SkillNode) -> bool: return n.branch == branch)
	result.sort_custom(func(a: SkillNode, b: SkillNode) -> bool: return a.tier < b.tier)
	return result

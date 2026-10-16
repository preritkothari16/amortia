class_name ResearchTree
extends Resource
## The list of research projects and the caps on what they can add in total.

@export var nodes: Array[ResearchNode] = []
## cap group -> most the group's nodes may add in total (e.g. "health" -> 30 extra max HP).
@export var group_caps: Dictionary[StringName, float] = {}


func get_node_by_id(id: StringName) -> ResearchNode:
	for n: ResearchNode in nodes:
		if n.id == id:
			return n
	return null

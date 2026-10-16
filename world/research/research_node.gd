class_name ResearchNode
extends Resource
## One Safehouse research project (GDD 7.5): costs samples and scrap, needs earlier projects and
## a zone, and gives a rare PERMANENT improvement. Data only; ResearchState holds the rules.

@export var id: StringName
@export var display_name: String = ""
@export var description: String = ""
## Costs (configurable per node in data/research/*.tres).
@export var cost_samples: int = 0
@export var cost_scrap: int = 0
## Projects that must be finished first.
@export var requires: Array[StringName] = []
## The campaign zone that must have been reached (the Safehouse after zone N has zone N).
@export var min_zone: int = 1
## Nodes with the same group share a cap on the total they can add (ResearchTree.group_caps).
@export var cap_group: StringName = &""
## What it changes: ADD / MULTIPLY on player stats (only max health is used for now).
@export var modifiers: Array[StatModifier] = []

## Total ADD amount this node contributes to its cap group.
func group_amount() -> float:
	var total: float = 0.0
	for m: StatModifier in modifiers:
		if m.mode == StatModifier.Mode.ADD:
			total += m.amount
	return total

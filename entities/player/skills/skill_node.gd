class_name SkillNode
extends Resource
## One skill in the skill tree (GDD 7.3). Pure data: one .tres per node in data/skills/.
## Its effect changes one property on the player's PlayerStats or WeaponStats, so new
## skills that tweak an existing stat need no code.

enum Branch { FIREPOWER, FORTIFY, ADAPT }
## Which tuning resource the effect changes.
enum Target { PLAYER, WEAPON }
## MULTIPLY: value × amount (0.8 = −20 %). ADD: value + amount.
enum Mode { MULTIPLY, ADD }

@export var id: StringName
@export var display_name: String = ""
## Short effect text shown in the UI, e.g. "+25% bullet damage".
@export var description: String = ""
@export var branch: Branch = Branch.FIREPOWER
## Row inside the branch (0 = first). Only used for layout.
@export var tier: int = 0
## Skill points it costs.
@export var cost: int = 1
## Ids of nodes that must be unlocked first.
@export var requires: Array[StringName] = []

@export_group("Effect")
@export var target: Target = Target.PLAYER
## Property name on PlayerStats / WeaponStats, e.g. &"move_speed", &"fire_cooldown".
@export var property: StringName
@export var mode: Mode = Mode.MULTIPLY
@export var amount: float = 1.0


## The property's value after this node's effect.
func apply_to(value: float) -> float:
	return value * amount if mode == Mode.MULTIPLY else value + amount

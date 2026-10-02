class_name UtilityAction
extends RefCounted
## Base class for one thing an enemy can choose to do. Subclasses only answer one question:
## "how good is this action right now?" as a number, usually 0..1. They never move anything.

enum Type { IDLE, CHASE, FLANK, INVESTIGATE }

## Which action this is (set by the subclass).
var type: Type = Type.IDLE


## Score for doing this action now. Override in subclasses.
func score(_inputs: DecisionInputs, _genes: BehaviourWeights, _settings: UtilitySettings) -> float:
	return 0.0


## Human-readable name for debug output.
static func type_name(t: Type) -> String:
	return Type.keys()[t]

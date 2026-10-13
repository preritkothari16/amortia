class_name ObjectiveFactory
extends RefCounted
## Makes the Objective node for an ObjectiveConfig.


static func create(config: ObjectiveConfig) -> Objective:
	match config.type:
		_:
			return SurviveObjective.new()

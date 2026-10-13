class_name ObjectiveFactory
extends RefCounted
## Makes the Objective node for an ObjectiveConfig.


static func create(config: ObjectiveConfig) -> Objective:
	match config.type:
		ObjectiveConfig.Type.HOLD:
			return HoldObjective.new()
		ObjectiveConfig.Type.ESCORT:
			return EscortObjective.new()
		ObjectiveConfig.Type.PURGE:
			return PurgeObjective.new()
		ObjectiveConfig.Type.EXTRACT:
			return ExtractObjective.new()
		ObjectiveConfig.Type.STEALTH:
			return StealthObjective.new()
		ObjectiveConfig.Type.APEX:
			return ApexObjective.new()
		_:
			return SurviveObjective.new()

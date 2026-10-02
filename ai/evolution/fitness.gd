class_name Fitness
extends RefCounted
## Turns a FitnessRecord (raw facts) into the GDD fitness (5.4):
##   F = weight_damage * D + weight_pressure * P + weight_survival * S + weight_objective * O
## with each term normalised explicitly: term = clamp(raw / cap, 0, 1). A cap of 0 for P or S
## means "use the wave's duration". Nothing else is applied.

## Keys of the component dictionary.
const D: StringName = &"D"
const P: StringName = &"P"
const S: StringName = &"S"
const O: StringName = &"O"

var settings: FitnessSettings


func _init(fitness_settings: FitnessSettings) -> void:
	settings = fitness_settings


## The four normalised terms, each 0..1. `wave_seconds` = how long the wave lasted.
func components(record: FitnessRecord, wave_seconds: float) -> Dictionary[StringName, float]:
	return {
		D: normalise(record.damage_dealt, settings.damage_cap),
		P: normalise(record.pressure_seconds, _cap_or_wave(settings.pressure_cap_seconds, wave_seconds)),
		S: normalise(record.alive_seconds, _cap_or_wave(settings.survival_cap_seconds, wave_seconds)),
		O: normalise(record.objective_score, settings.objective_cap),
	}


## Weighted sum of the components.
func score(record: FitnessRecord, wave_seconds: float) -> float:
	return score_components(components(record, wave_seconds))


func score_components(c: Dictionary[StringName, float]) -> float:
	return settings.weight_damage * c[D] + settings.weight_pressure * c[P] \
		+ settings.weight_survival * c[S] + settings.weight_objective * c[O]


## raw / cap clamped to 0..1. A cap of 0 or less gives 0 (nothing to compare against).
static func normalise(raw: float, cap: float) -> float:
	if cap <= 0.0:
		return 0.0
	return clampf(raw / cap, 0.0, 1.0)


## e.g. "D 0.00 P 0.42 S 1.00 O 0.00 -> F 0.255"
func describe(record: FitnessRecord, wave_seconds: float) -> String:
	var c: Dictionary[StringName, float] = components(record, wave_seconds)
	return "D %.2f P %.2f S %.2f O %.2f -> F %.3f" % [c[D], c[P], c[S], c[O], score_components(c)]


func _cap_or_wave(cap: float, wave_seconds: float) -> float:
	return cap if cap > 0.0 else wave_seconds

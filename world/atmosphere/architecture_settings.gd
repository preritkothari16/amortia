class_name ArchitectureSettings
extends Resource
## Every district's architecture (data/architecture.tres). Atmosphere looks the current level up
## here and hands its district to BuildingDetail.

const PATH: String = "res://data/architecture.tres"

@export var districts: Array[DistrictStyle] = []


## District dressing `level_id`, else the first district of `zone` (1-4), else null.
func district_for(level_id: String, zone: int) -> DistrictStyle:
	if level_id != "":
		for d: DistrictStyle in districts:
			if d.levels.has(level_id):
				return d
	for d: DistrictStyle in districts:
		if d.zone == zone:
			return d
	return null

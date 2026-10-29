class_name DistrictStyle
extends Resource
## One district's architecture (BuildingDetail / FacadeBuilder): which building types stand there
## and how far gone they are. Lives in data/architecture.tres; each campaign level names its
## district, so every level has its own architectural identity within its zone.

@export var id: StringName = &""
@export var title: String = ""
## Zone 1 Maple Hollow, 2 Lowtide, 3 Greywood, 4 Sunnyseed Labs. The first district listed for a
## zone also dresses that zone's maps outside the campaign (prototype map, test levels).
@export_range(1, 4) var zone: int = 1
## Campaign level ids (LevelConfig.id) dressed as this district.
@export var levels: PackedStringArray = []
## BuildingArchetypes ids; list one several times to make it more common. A building only gets a
## type that fits its footprint.
@export var archetypes: Array[StringName] = []
## Given to the area's biggest building when it fits ("" = none).
@export var landmark: StringName = &""
## Broken / boarded windows, cracks, stains, faded signs.
@export_range(0.0, 1.0) var decay: float = 0.3
## The Bloom's fleshy growth on walls, roofs and windows.
@export_range(0.0, 1.0) var infection: float = 0.1
## Ivy, moss and weeds.
@export_range(0.0, 1.0) var overgrowth: float = 0.2
## Flood tide line and water stains (Lowtide).
@export_range(0.0, 1.0) var flood: float = 0.0
## Share of buildings that burned (soot, embers in a window, a flickering fire light).
@export_range(0.0, 1.0) var burn_share: float = 0.1
## Share of buildings with a collapsed corner (most stay standing).
@export_range(0.0, 1.0) var collapse_share: float = 0.05

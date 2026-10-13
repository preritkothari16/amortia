extends SceneTree
## Writes the campaign data (GDD 8.1): 16 LevelConfigs (data/levels/z<zone>_l<n>.tres) and
## data/campaign/campaign.tres (4 zones x 3 objective levels + 1 Apex).
## Run:  godot --headless --path . -s res://tools/build_campaign.gd
##
## Placeholders (no content invented): titles are generic ("<zone> 2: Hold the point"), only
## Maple Hollow has hand-made areas and a chunk library, so zones 2-4 are generated from the
## Maple Hollow chunks with their zone's terrain EVENTS until their own chunks exist. Apex
## bosses use ObjectiveConfig's placeholder multipliers. The objective mix per zone follows
## GDD 8.2's list (every type appears; Apex last in each zone).

const ZONES: Array = [
	[1, "Maple Hollow", [ObjectiveConfig.Type.SURVIVE, ObjectiveConfig.Type.HOLD, ObjectiveConfig.Type.ESCORT]],
	[2, "Lowtide", [ObjectiveConfig.Type.EXTRACT, ObjectiveConfig.Type.PURGE, ObjectiveConfig.Type.SURVIVE]],
	[3, "Greywood", [ObjectiveConfig.Type.STEALTH, ObjectiveConfig.Type.HOLD, ObjectiveConfig.Type.PURGE]],
	[4, "Sunnyseed Labs", [ObjectiveConfig.Type.EXTRACT, ObjectiveConfig.Type.ESCORT, ObjectiveConfig.Type.SURVIVE]],
]
const TYPE_NAMES: Dictionary = {
	ObjectiveConfig.Type.SURVIVE: "Survive", ObjectiveConfig.Type.HOLD: "Hold the point",
	ObjectiveConfig.Type.ESCORT: "Escort", ObjectiveConfig.Type.PURGE: "Purge nests",
	ObjectiveConfig.Type.EXTRACT: "Extract", ObjectiveConfig.Type.STEALTH: "Stealth",
}
const HAND_MADE: Array[String] = [
	"res://world/zones/maple_hollow/areas/area_1.tscn",
	"res://world/zones/maple_hollow/areas/area_2.tscn",
	"res://world/zones/maple_hollow/areas/area_3.tscn",
]


func _initialize() -> void:
	var campaign: CampaignConfig = CampaignConfig.new()
	var zones: Array[ZoneConfig] = []
	var generator: LevelGenSettings = load("res://data/levelgen/maple_hollow.tres")
	for z: Array in ZONES:
		var zone: ZoneConfig = ZoneConfig.new()
		zone.zone = z[0]
		zone.title = z[1]
		var levels: Array[LevelConfig] = []
		for n: int in 4:
			var c: LevelConfig = LevelConfig.new()
			var apex: bool = n == 3
			c.id = "z%d_l%d" % [z[0], n + 1]
			c.zone = z[0]
			c.objective = ObjectiveConfig.new()
			c.objective.type = ObjectiveConfig.Type.APEX if apex else z[2][n]
			c.objective.boss_uses_run_best = apex and z[0] == 4  # the Seed: best of the whole run
			c.title = "%s Apex" % z[1] if apex else "%s %d: %s" % [z[1], n + 1, TYPE_NAMES[c.objective.type]]
			c.waves = 1 if apex else (2 if c.objective.type == ObjectiveConfig.Type.ESCORT or c.objective.type == ObjectiveConfig.Type.STEALTH else 3)
			if z[0] == 1 and n == 0:
				var areas: Array[PackedScene] = []
				for path: String in HAND_MADE:
					areas.append(load(path))
				c.areas = areas
			else:
				c.generator = generator
				c.generator_seed = z[0] * 100 + n + 1
			c.events = _events(z[0])
			var side: SideObjective = SideObjective.new()
			side.challenge = [SideObjective.Challenge.NO_BARRICADES, SideObjective.Challenge.UNDER_TIME,
				SideObjective.Challenge.NO_DAMAGE, SideObjective.Challenge.UNDER_TIME][n]
			side.id = "%s_%s" % [c.id, SideObjective.Challenge.keys()[side.challenge].to_lower()]
			side.title = {SideObjective.Challenge.NO_DAMAGE: "No damage", SideObjective.Challenge.UNDER_TIME: "Under 10 minutes",
				SideObjective.Challenge.NO_BARRICADES: "No barricades"}[side.challenge]
			side.time_limit_seconds = 600.0
			var sides: Array[SideObjective] = [side]
			c.side_objectives = sides
			var path: String = "res://data/levels/%s.tres" % c.id
			print("%s: %s" % [path, error_string(ResourceSaver.save(c, path))])
			levels.append(load(path))
		zone.levels = levels
		zones.append(zone)
	campaign.zones = zones
	DirAccess.make_dir_recursive_absolute("res://data/campaign")
	print("campaign: %s" % error_string(ResourceSaver.save(campaign, "res://data/campaign/campaign.tres")))
	quit()


## The zone's terrain events (GDD 4.4): fire everywhere (only lit by the player);
## zone 1 day/night; zone 2 tide + bridges; zone 3 fog + day/night; zone 4 living walls.
func _events(zone: int) -> Array[TerrainEvent]:
	var list: Array[TerrainEvent] = [FireSpread.new()]
	match zone:
		1:
			list.append(DayNight.new())
		2:
			list.append(RisingTide.new())
			list.append(BridgeCollapse.new())
		3:
			list.append(FogBanks.new())
			list.append(DayNight.new())
		4:
			list.append(LivingWalls.new())
	return list

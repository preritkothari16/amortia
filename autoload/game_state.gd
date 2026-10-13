extends Node
## Campaign-wide state that outlives a level scene (GDD 10.1): what the player carries
## (samples, scrap) and, for the campaign, where they are. Saved by SaveSystem with the rest.

## Collected this run (GDD 7.5 samples for research, 7.6 scrap for the Safehouse).
var samples: int = 0
var scrap: int = 0
## Level the next main.tscn load should play (null = prototype loop). Set by menus / campaign.
var pending_level: LevelConfig


## Best genome per zone so far (Apex bosses are built from it): zone -> {fitness, genome dict}.
var zone_best: Dictionary = {}
## Zone being played (1..4). The prototype loop counts as zone 1.
var current_zone: int = 1


## Remembers the fittest genome of a finished wave if it beats the zone's best so far.
## `results` = WaveManager.last_wave_results (best first).
func record_wave_best(results: Array[Dictionary]) -> void:
	if results.is_empty() or results[0].get("genome") == null:
		return
	var best: Dictionary = zone_best.get(current_zone, {})
	if best.is_empty() or results[0]["fitness"] > best["fitness"]:
		zone_best[current_zone] = {"fitness": results[0]["fitness"], "genome": (results[0]["genome"] as Genome).to_dict()}


## The zone's strongest genome so far, or null.
func zone_best_genome(zone: int = -1) -> Genome:
	var best: Dictionary = zone_best.get(current_zone if zone < 0 else zone, {})
	return Genome.from_dict(best["genome"]) if not best.is_empty() else null


func add_pickup(kind: StringName, amount: int) -> void:
	match kind:
		&"sample": samples += amount
		&"scrap": scrap += amount


func reset_inventory() -> void:
	samples = 0
	scrap = 0

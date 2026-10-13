extends Node
## Campaign-wide state that outlives a level scene (GDD 10.1): what the player carries
## (samples, scrap) and, for the campaign, where they are. Saved by SaveSystem with the rest.

## Collected this run (GDD 7.5 samples for research, 7.6 scrap for the Safehouse).
var samples: int = 0
var scrap: int = 0
## Level the next main.tscn load should play (null = prototype loop). Set by menus / campaign.
var pending_level: LevelConfig


func add_pickup(kind: StringName, amount: int) -> void:
	match kind:
		&"sample": samples += amount
		&"scrap": scrap += amount


func reset_inventory() -> void:
	samples = 0
	scrap = 0

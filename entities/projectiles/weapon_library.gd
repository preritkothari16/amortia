class_name WeaponLibrary
extends RefCounted
## Where weapons live: one WeaponStats resource per id. The pistol is the player's starting
## weapon (always owned); the others come from blueprints and are built at the Safehouse Workbench.

const PISTOL: StringName = &"pistol"
const PATHS: Dictionary = {
	&"pistol": "res://data/pistol.tres",
	&"shotgun": "res://data/weapons/shotgun.tres",
}


static func ids() -> Array[StringName]:
	var list: Array[StringName] = []
	for id: Variant in PATHS:
		list.append(id)
	return list


static func has_weapon(id: StringName) -> bool:
	return PATHS.has(id)


## The weapon's data, or null for an unknown id.
static func get_weapon(id: StringName) -> WeaponStats:
	return load(PATHS[id]) as WeaponStats if PATHS.has(id) else null

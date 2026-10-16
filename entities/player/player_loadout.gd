class_name PlayerLoadout
extends RefCounted
## The weapons the player owns and carries (permanent, saved in the campaign save):
##   blueprints  weapons found but not built yet (exploration or a zone reward)
##   owned       weapons built at the Workbench (the pistol is always owned)
##   equipped    two slots, [primary, secondary]; the second may be empty. Q swaps between them in a level.
## Pure data + rules, no nodes. Unknown ids (an edited save) are dropped on load.

const SLOTS: int = 2

var blueprints: Array[StringName] = []
var owned: Array[StringName] = [WeaponLibrary.PISTOL]
var equipped: Array[StringName] = [WeaponLibrary.PISTOL, &""]


func is_owned(id: StringName) -> bool:
	return owned.has(id)


## Records a found blueprint. False if the weapon is already known (built or blueprinted) or unknown.
func add_blueprint(id: StringName) -> bool:
	if not WeaponLibrary.has_weapon(id) or owned.has(id) or blueprints.has(id):
		return false
	blueprints.append(id)
	return true


## Why a blueprint can't be built now ("" = it can): not found, already built, or too little scrap.
func build_problem(id: StringName, scrap: int) -> String:
	if owned.has(id):
		return "already built"
	if not blueprints.has(id):
		return "no blueprint"
	var weapon: WeaponStats = WeaponLibrary.get_weapon(id)
	if scrap < weapon.unlock_cost_scrap:
		return "needs %d scrap" % weapon.unlock_cost_scrap
	return ""


## Builds the weapon: the caller pays the scrap (see build_problem). Returns false if not allowed.
func build(id: StringName, scrap: int) -> bool:
	if build_problem(id, scrap) != "":
		return false
	blueprints.erase(id)
	owned.append(id)
	return true


## Puts an owned weapon in a slot. A weapon sits in one slot at a time: equipping the one that is in
## the other slot swaps them. Slot 0 is never left empty.
func equip(id: StringName, slot: int) -> bool:
	if slot < 0 or slot >= SLOTS or not owned.has(id):
		return false
	var other: int = 1 - slot
	if equipped[other] == id:
		equipped[other] = equipped[slot]
	equipped[slot] = id
	if equipped[0] == &"":
		equipped[0] = equipped[1]
		equipped[1] = &""
	return true


## Empties the secondary slot.
func clear_secondary() -> void:
	equipped[1] = &""


## The ids in the slots that hold something, in order.
func carried() -> Array[StringName]:
	var list: Array[StringName] = []
	for id: StringName in equipped:
		if id != &"":
			list.append(id)
	return list


func to_dict() -> Dictionary:
	return {"blueprints": Array(blueprints).map(func(i: StringName) -> String: return String(i)),
		"owned": Array(owned).map(func(i: StringName) -> String: return String(i)),
		"equipped": Array(equipped).map(func(i: StringName) -> String: return String(i))}


## Rebuilds from a saved dictionary, dropping anything unknown or inconsistent.
static func from_dict(d: Variant) -> PlayerLoadout:
	var l: PlayerLoadout = PlayerLoadout.new()
	if not d is Dictionary:
		return l
	for raw: Variant in _list(d.get("owned")):
		var id: StringName = StringName(str(raw))
		if raw is String and WeaponLibrary.has_weapon(id) and not l.owned.has(id):
			l.owned.append(id)
	for raw: Variant in _list(d.get("blueprints")):
		var id: StringName = StringName(str(raw))
		if raw is String and WeaponLibrary.has_weapon(id) and not l.owned.has(id) and not l.blueprints.has(id):
			l.blueprints.append(id)
	var slots: Array = _list(d.get("equipped"))
	l.equipped = [WeaponLibrary.PISTOL, &""]
	for i: int in mini(slots.size(), SLOTS):
		var id: StringName = StringName(str(slots[i]))
		if slots[i] is String and l.owned.has(id) and (i == 0 or id != l.equipped[0]):
			l.equipped[i] = id
	return l


static func _list(v: Variant) -> Array:
	return v if v is Array else []

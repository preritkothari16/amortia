class_name ExtractObjective
extends Objective
## Extract (GDD 8.2): extract_items supplies are scattered over the area; picking one up makes
## noise (loot_noise_radius - looting draws enemies). All collected = wave goal: the exit
## (evac) opens. Objective fitness O: each second an enemy spends within evac_guard_radius of
## an uncollected supply while the player is within it too (guarding the loot) earns 1 point.

var supplies: Array[Pickup] = []
var collected: int = 0


func clears_on_kill_all() -> bool:
	return false


func _ready() -> void:
	EventBus.pickup_collected.connect(_on_pickup)


func wave_started(wave: int) -> void:
	super(wave)
	_clear_props()
	supplies.clear()
	collected = 0
	# Seeded scatter (same wave of the same level = same places, also on Retry).
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = wave * 977 + grid.width
	for i: int in config.extract_items:
		var cell: Vector2i = Vector2i(rng.randi_range(8, grid.width - 6), rng.randi_range(3, grid.height - 4))
		var p: Pickup = Pickup.create(&"supply", 1, grid.coords.cell_to_world(walkable_near(cell)))
		add_child(p)
		supplies.append(p)


func tick(delta: float) -> void:
	if state != State.ACTIVE:
		return
	var r2: float = config.evac_guard_radius * config.evac_guard_radius
	for s: Pickup in supplies:
		if not is_instance_valid(s) or player.global_position.distance_squared_to(s.global_position) > r2:
			continue
		for e: Enemy in wave_manager.alive:
			if e.global_position.distance_squared_to(s.global_position) <= r2:
				credit(e, delta)


func _on_pickup(kind: StringName, _amount: int, pos: Vector2) -> void:
	if kind != &"supply" or state != State.ACTIVE:
		return
	collected += 1
	EventBus.noise_emitted.emit(pos, config.loot_noise_radius)
	# Untyped lambda argument: freed pickups can't be converted to Pickup.
	supplies.assign(supplies.filter(func(s: Variant) -> bool: return is_instance_valid(s) and not (s as Node).is_queued_for_deletion()))
	if collected >= config.extract_items:
		_complete()


func hud_text() -> String:
	return "Collect supplies  %d / %d" % [collected, config.extract_items] if state == State.ACTIVE else ""

class_name ApexObjective
extends Objective
## Apex boss (GDD 8.2): once the wave's enemies arrive, the boss appears at the spawn farthest
## from the player: the zone's strongest genome so far (GameState.zone_best_genome - highest
## fitness of any wave in this zone; the current population's first genome if none yet), on
## the Runner body, with the config's multipliers. Boss dead = wave goal. Placeholder: no boss
## attacks are invented (not designed yet) - it fights like a big Runner.
## The boss is not part of the GA (no fitness record). O: none.

var boss: Enemy
var _spawned: bool = false


func clears_on_kill_all() -> bool:
	return false


func wave_started(wave: int) -> void:
	super(wave)
	boss = null
	_spawned = false


func tick(_delta: float) -> void:
	if state != State.ACTIVE or _spawned:
		return
	if wave_manager.is_arriving():
		return
	_spawn_boss()


func _spawn_boss() -> void:
	_spawned = true
	var genome: Genome = GameState.zone_best_genome()
	if genome == null and not wave_manager.population.is_empty():
		genome = wave_manager.population[0]
	var spawns: Array[Vector2] = map.get_enemy_spawns()
	var far: Vector2 = spawns[0]
	for s: Vector2 in spawns:
		if s.distance_to(player.global_position) > far.distance_to(player.global_position):
			far = s
	boss = wave_manager.spawn_enemy(far, genome, null)
	boss.make_boss(config.boss_health_multiplier, config.boss_damage_multiplier, config.boss_scale)
	boss.died.connect(func(_e: Enemy) -> void: _complete())


func hud_text() -> String:
	if state != State.ACTIVE:
		return ""
	if boss == null or not is_instance_valid(boss):
		return "The Apex is coming..."
	return "Defeat the Apex   HP %d / %d" % [ceili(boss.health), roundi(boss.stats.max_health)]

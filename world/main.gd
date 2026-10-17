extends Node2D
## Prototype level root: puts the player on the map's spawn, keeps the camera inside the map,
## builds the terrain-cost grid, and keeps the shared flow field pointing at the player.

@export var terrain_costs: TerrainCosts
@export var attack_ring_settings: AttackRingSettings
@export var genome_rules: GenomeRules
@export var fitness_settings: FitnessSettings
## Sense rules for enemies (night, stealth). The player has its own reference to the same file.
@export var perception_settings: PerceptionSettings
## Campaign level to play (areas, waves, objective, events). null = the prototype loop on
## Maple Hollow; GameState.pending_level fills it when a menu starts a level.
@export var level_config: LevelConfig
## Save to user://save.json between waves (prototype loop: after each wave is bred or lost). Tests,
## scripts and headless runs save into the SaveSystem sandbox instead, never the real file.
@export var autosave: bool = true
## Experiments / tests: make runs repeatable. The PathQueue normally stops after 2 ms of A*
## per frame, so how many paths finish each frame depends on CPU speed -> same seed, different
## run. On = only the per-frame search count limits it (frame time may spike, results repeat).
@export var deterministic_ai: bool = false

## Plain-data copy of the map for the AI. Rebuild or set_terrain() when terrain changes.
var terrain_grid: TerrainGrid
## Shared flow field towards the player, rebuilt whenever the player enters a new cell.
## This is the base-profile field of flow_fields.
var flow_field: FlowField
## Flow fields per terrain-profile bucket (climbers, swimmers... get their own arrows).
var flow_fields: FlowFieldSet
## Slots around the player that decide who surrounds and who attacks (GDD 6.4).
var attack_ring: AttackRing
## Budgeted, cached A* shared by all enemies for investigation paths.
var path_queue: PathQueue
## Level-wide sense conditions (night...), shared with every enemy.
var conditions: WorldConditions = WorldConditions.new()
## HP / state of destructible tiles (fences, barricades, doors).
var terrain_health: TerrainHealth
## True when terrain costs changed this frame: flow fields and cached paths are rebuilt once.
var _nav_dirty: bool = false
## Campaign: the area sequencer and the level's objective (null in the prototype).
var level_flow: LevelFlow
var objective: Objective
## Temporary power-ups (null when the level has none).
var power_up_manager: PowerUpManager
## True when this level is the campaign's current level (GameState): the zone's
## population comes from GameState and goes back to it when the level is done.
var in_campaign: bool = false
## Waves of the level counted as done at the start (test scenarios: GameState.pending_start_wave).
var start_wave: int = 0
## How long the last flow field rebuild took, in milliseconds.
var last_flow_build_msec: float = 0.0

@onready var _map: ZoneMap = _find_map()
@onready var _player: Player = $Player
@onready var _cost_overlay: TerrainCostOverlay = $TerrainCostOverlay
@onready var _flow_overlay: FlowFieldOverlay = $FlowFieldOverlay
@onready var _wave_manager: WaveManager = $WaveManager
@onready var _ring_overlay: AttackRingOverlay = $AttackRingOverlay
@onready var _awareness_overlay: AwarenessOverlay = $AwarenessOverlay
@onready var _genome_overlay: GenomeOverlay = $GenomeOverlay
@onready var _wave_hud: WaveHud = $HUD/WaveHud
@onready var _wave_report: WaveReport = $HUD/WaveReport
@onready var _player_status: PlayerStatus = $HUD/PlayerStatus
@onready var _pause_menu: PauseMenu = $HUD/PauseMenu
@onready var _game_over: GameOverScreen = $HUD/GameOverScreen
@onready var _terrain_view: TerrainView = $TerrainView
@onready var _terrain_events: TerrainEvents = $TerrainEvents


func _ready() -> void:
	if level_config == null and GameState.pending_level != null:
		level_config = GameState.pending_level
		GameState.pending_level = null
	in_campaign = level_config != null and GameState.campaign_active and level_config == GameState.current_level()
	if level_config != null:
		start_wave = clampi(GameState.pending_start_wave, 0, level_config.waves - 1)
		_wave_manager.zone = GameState.current_zone if in_campaign else level_config.zone
	GameState.pending_start_wave = 0
	if level_config != null and level_config.has_areas():
		_swap_map_node(level_config.area_scene(start_wave))
	var coords: GridCoords = GridCoords.new(_map.terrain_layer.tile_set.tile_size.x, _map.get_world_rect().position)
	terrain_grid = TerrainGrid.from_rows(_map.get_terrain_rows(), terrain_costs, coords)
	_cost_overlay.grid = terrain_grid
	_player.terrain_grid = terrain_grid
	terrain_health = TerrainHealth.new(terrain_grid)
	_player.terrain_health = terrain_health
	terrain_grid.terrain_changed.connect(_on_terrain_changed)
	EventBus.terrain_hit.connect(func(pos: Vector2, damage: float) -> void:
		terrain_health.damage(terrain_grid.coords.world_to_cell(pos), damage))
	flow_fields = FlowFieldSet.new(terrain_grid)
	flow_field = flow_fields.base_field
	_cost_overlay.flow_fields = flow_fields
	_flow_overlay.field = flow_field
	attack_ring = AttackRing.new(flow_field, attack_ring_settings)
	_ring_overlay.ring = attack_ring
	path_queue = PathQueue.new(AStar.new(terrain_grid))
	if deterministic_ai:
		path_queue.budget_usec = 1 << 40  # effectively no time limit; max_per_frame still applies
	_awareness_overlay.wave_manager = _wave_manager
	_awareness_overlay.grid = terrain_grid
	_genome_overlay.wave_manager = _wave_manager
	_wave_hud.wave_manager = _wave_manager
	_wave_hud.terrain_events = _terrain_events
	_wave_report.wave_manager = _wave_manager
	_pause_menu.wave_manager = _wave_manager
	_game_over.wave_manager = _wave_manager
	_game_over.retry_requested.connect(_wave_manager.continue_to_next_wave)
	_game_over.main_menu_requested.connect(_on_main_menu)
	_game_over.restart_level_requested.connect(_on_restart_level)
	_player_status.player = _player

	GameState.apply_to_player(_player)
	_set_camera_limits()
	_put_player_on_spawn()
	attack_ring.update(_player.global_position, 0.0)
	var context: EnemyContext = EnemyContext.new()
	context.flow_field = flow_field
	context.flow_fields = flow_fields
	context.attack_ring = attack_ring
	context.path_queue = path_queue
	context.target = _player
	context.genome_rules = genome_rules
	context.fitness = Fitness.new(fitness_settings)
	context.perception = perception_settings
	context.conditions = conditions
	context.terrain_health = terrain_health
	_load_pending_save()
	if in_campaign:
		_load_campaign_state()
	elif GameState.endless_mode:
		_wave_manager.wave_started.connect(GameState.note_endless_wave)
	_wave_manager.generation_bred.connect(func(_summary: Dictionary) -> void: save_game())
	# Apex bosses are built from the zone's fittest genome (failed waves count: the attempt was real).
	_wave_manager.wave_ended.connect(GameState.record_wave_best)
	# A lost wave is saved too (the save replays that wave).
	_wave_manager.wave_failed.connect(func(_summary: Dictionary) -> void: save_game())
	# Player down -> the wave is lost (Game Over screen, not bred) and Retry replays it.
	# Deferred so the attack that killed the player finishes first. Every wave starts with
	# full HP; a replayed wave also starts from the player spawn.
	_player.died.connect(_on_player_died, CONNECT_DEFERRED)
	_wave_manager.wave_restarting.connect(func(_wave: int) -> void: _put_player_on_spawn())
	_wave_manager.wave_started.connect(func(_wave: int) -> void: _player.revive())
	# Resources and blueprints picked up in a lost attempt are not kept: Retry starts from the wave's start.
	_wave_manager.wave_started.connect(func(_wave: int) -> void: GameState.take_resource_snapshot())
	_wave_manager.wave_restarting.connect(func(_wave: int) -> void: GameState.restore_resource_snapshot())
	_terrain_view.grid = terrain_grid
	_terrain_view.layer = _map.terrain_layer
	_terrain_view.rules = terrain_costs
	_terrain_view.events = _terrain_events
	_terrain_view.health = terrain_health
	_terrain_events.setup(terrain_grid, terrain_costs, _player, _wave_manager, conditions,
			_wave_manager.spawn_seed if _wave_manager.spawn_seed != 0 else randi())
	terrain_health.is_occupied = _terrain_events.is_occupied
	if level_config != null:
		_setup_level()
		_game_over.allow_level_restart = in_campaign
	_wave_manager.setup(_map.get_enemy_spawns(), context)
	if level_config != null:
		_wave_manager.set_spawn_points(_map.get_enemy_spawns(), _map.get_behind_spawns())


## True if the player already owns or has a blueprint for weapon `id`.
func loadout_knows(id: StringName) -> bool:
	return GameState.loadout.is_owned(id) or GameState.loadout.blueprints.has(id)


## The level's first map: the first ZoneMap child (Maple Hollow in the prototype scene).
func _find_map() -> ZoneMap:
	for child: Node in get_children():
		if child is ZoneMap:
			return child
	return null


## The ZoneMap currently played.
func current_map() -> ZoneMap:
	return _map


## Replaces the map node (before or after _ready) with a new instance of `scene`.
func _swap_map_node(scene: PackedScene) -> void:
	var old: ZoneMap = _find_map()
	var new_map: ZoneMap = scene.instantiate() as ZoneMap
	new_map.name = "Map"
	add_child(new_map)
	move_child(new_map, 0)
	if old != null:
		remove_child(old)
		old.queue_free()
	_map = new_map


## Campaign level: pacing on the WaveManager, terrain events, objective and the area sequencer.
func _setup_level() -> void:
	var c: LevelConfig = level_config
	_wave_manager.spawn_delay_seconds = c.spawn_delay_seconds
	_wave_manager.behind_fraction = c.behind_fraction
	_wave_manager.auto_next_wave = false
	_terrain_events.events = c.events.duplicate()
	_terrain_events.setup(terrain_grid, terrain_costs, _player, _wave_manager, conditions, _event_seed())
	if c.objective != null:
		objective = ObjectiveFactory.create(c.objective)
		objective.name = "Objective"
		add_child(objective)
		objective.setup(c.objective, terrain_grid, _player, _wave_manager, terrain_health)
	if c.powerups_enabled:
		var power_ups: PowerUpManager = PowerUpManager.new()
		power_ups.name = "PowerUps"
		add_child(power_ups)
		power_ups.setup(load("res://data/power_up_set.tres"), terrain_grid, _player, _wave_manager, _event_seed())
		power_up_manager = power_ups
	level_flow = LevelFlow.new()
	level_flow.name = "LevelFlow"
	add_child(level_flow)
	level_flow.setup(c, self, _wave_manager, _player, _wave_report, objective, _event_seed())
	if start_wave > 0:
		level_flow.skip_waves(start_wave)
	_wave_hud.level_flow = level_flow
	level_flow.level_completed.connect(_on_level_completed)


func _event_seed() -> int:
	return _wave_manager.spawn_seed if _wave_manager.spawn_seed != 0 else 1


## Loads another area (next wave, or the same one again on Retry): new map, same grid object
## (load_rows), navigation, camera limits, spawns, fresh terrain events, player at the entry.
## Enemies and pickups of the old area are removed; barricades don't carry over.
func load_area(scene: PackedScene) -> void:
	_wave_manager.clear_enemies()
	for child: Node in get_children():
		if child is Pickup:
			child.queue_free()
	_swap_map_node(scene)
	terrain_grid.load_rows(_map.get_terrain_rows())
	_terrain_view.layer = _map.terrain_layer
	_cost_overlay.queue_redraw()
	_set_camera_limits()
	_wave_manager.set_spawn_points(_map.get_enemy_spawns(), _map.get_behind_spawns())
	_terrain_events.restart(_event_seed() + _wave_manager.wave_number * 101)
	_put_player_on_spawn()
	flow_fields.invalidate_all()
	flow_fields.flush()


## Opens the exit gate (gate tiles -> road).
func open_exit() -> void:
	for cell: Vector2i in _map.get_gate_cells():
		if terrain_grid.get_terrain(cell) == "gate":
			terrain_grid.set_terrain(cell, "road")


## The Wave Report's "Next" chip at the end of the level: the next campaign level, the
## Safehouse, or the end of the campaign.
func next_destination_text() -> String:
	if not in_campaign:
		return "Level complete"
	if not GameState.is_apex_level():
		var next: LevelConfig = GameState.campaign().get_level(GameState.current_zone, GameState.level_index + 1)
		return "Next: " + next.title if next != null else "Level complete"
	return "Next: Safehouse" if GameState.current_zone < GameState.campaign().zones.size() else "Next: The end"


func _on_level_completed() -> void:
	print("[Level] %s complete" % level_config.id)
	EventBus.level_completed.emit(level_config)
	if not in_campaign:
		return
	var destination: String = GameState.finish_level(_wave_manager.get_save_state())
	if destination == "level":
		GameState.call_deferred("start_current_level", get_tree())
	else:
		get_tree().call_deferred("change_scene_to_file", GameState.SAFEHOUSE_SCENE)


## Campaign: the zone's population so far (validated the same way as a save), New Game+ mutation rate.
func _load_campaign_state() -> void:
	var warnings: PackedStringArray = PackedStringArray()
	var evolution: Variant = GameState.zone_evolution.get(GameState.current_zone)
	if evolution is Dictionary:
		var checked: Dictionary = SaveGame._validate_evolution(evolution, genome_rules, warnings, GameState.current_zone)
		if checked.has("error"):
			push_warning("Campaign population unusable (%s); new population" % checked["error"])
		else:
			_wave_manager.load_state(checked)
	if GameState.ng_plus and _wave_manager.ga_settings != null:
		_wave_manager.ga_settings = _wave_manager.ga_settings.duplicate() as GASettings
		_wave_manager.ga_settings.mutation_rate *= GameState.campaign().ng_plus_mutation_multiplier
	for w: String in warnings:
		push_warning("Campaign: " + w)


## Game Over -> "Restart level": the same level from its first wave, keeping the zone's
## evolution. Resources found in the lost attempt are given back.
func _on_restart_level() -> void:
	GameState.restore_resource_snapshot()
	GameState.restart_level(_wave_manager.get_save_state())
	GameState.start_current_level(get_tree())


func _on_player_died() -> void:
	print("[Player] down in wave %d" % _wave_manager.wave_number)
	_wave_manager.fail_wave()


func _set_camera_limits() -> void:
	var bounds: Rect2 = _map.get_world_rect()
	var camera: Camera2D = _player.get_node("Camera2D")
	camera.limit_left = int(bounds.position.x)
	camera.limit_top = int(bounds.position.y)
	camera.limit_right = int(bounds.end.x)
	camera.limit_bottom = int(bounds.end.y)


## Moves the player to the map's spawn and points the flow field and camera there, before
## enemies spawn (they are alerted to the player's position).
func _put_player_on_spawn() -> void:
	_player.global_position = _map.get_player_spawn()
	_player.velocity = Vector2.ZERO
	(_player.get_node("Camera2D") as Camera2D).reset_smoothing()
	_update_flow_field()


func _on_main_menu() -> void:
	GameState.leave_campaign()  # campaign progress is in its save (level start)
	get_tree().paused = false
	get_tree().change_scene_to_file(PauseMenu.MAIN_MENU_SCENE)


# --- Save / load ---------------------------------------------------------------------

## Writes the checkpoint (prototype loop): the population for the next wave.
func save_game() -> void:
	if not autosave or level_config != null or GameState.test_mode:
		return  # campaign levels save at level boundaries (GameState), not per wave; tests never save
	var data: Dictionary = SaveGame.capture(_wave_manager.get_save_state())
	if SaveSystem.write_save(data) == OK:
		print("[Save] saved: next wave %d, generation %d" % [data["evolution"]["next_wave"], data["evolution"]["generation"]])



## Continue from the main menu: check the save, then hand its parts to the player and the
## WaveManager (before the first wave spawns). A bad save is ignored -> new game.
func _load_pending_save() -> void:
	var pending: Dictionary = SaveSystem.pending_state
	SaveSystem.pending_state = {}
	if pending.is_empty():
		return
	var result: Dictionary = SaveGame.validate(pending, genome_rules)
	for w: String in result["warnings"]:
		push_warning("Save: " + w)
	if not result["ok"]:
		push_error("Save could not be loaded (%s); starting a new game." % result["error"])
		return
	_wave_manager.load_state(result["data"]["evolution"])


## Terrain changed at runtime (fire, broken fence, collapse...): rebuild navigation once.
func _on_terrain_changed(cells: Array[Vector2i], affects_cost: bool) -> void:
	if cells.is_empty():
		flow_fields.refresh_terrain()
	if affects_cost:
		_nav_dirty = true


func _physics_process(delta: float) -> void:
	if _nav_dirty:
		_nav_dirty = false
		path_queue.clear_cache()
		flow_fields.invalidate_all()  # base field now, the other buckets over the next frames
		_flow_overlay.refresh()
	_update_flow_field()
	# Runs before the enemies (parents process first), so they read this frame's roles.
	attack_ring.update(_player.global_position, delta)
	path_queue.process()
	flow_fields.process()


## Rebuilds the field only when the player's cell changes (GDD 6.2).
func _update_flow_field() -> void:
	var cell: Vector2i = terrain_grid.coords.world_to_cell(_player.global_position)
	if flow_field.is_built() and cell == flow_field.target:
		return
	if not terrain_grid.is_walkable(cell):
		return  # keep the old field rather than pointing everything at a wall
	var start_usec: int = Time.get_ticks_usec()
	flow_fields.set_target(cell)
	last_flow_build_msec = (Time.get_ticks_usec() - start_usec) / 1000.0
	_flow_overlay.refresh()

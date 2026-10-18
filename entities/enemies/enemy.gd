class_name Enemy
extends CharacterBody2D
## Thin enemy shell: physics, collision, health and greybox visuals.
## What it knows comes from Awareness (res://ai/decision/): it sees the player (grid line of
## sight) or hears noises (EventBus.noise_emitted) - never tracks the player through walls.
## What it does comes from a UtilityAI (res://ai/decision/): Chase / Flank / Investigate / Idle,
## decided at 5 Hz. This Node only gathers the inputs and executes the chosen action.
## Where to go comes from the FlowField (while it can see the player) or A* via the PathQueue
## (investigating a last known position). How to move comes from ContextSteering.
## Archetype numbers come from an EnemyStats resource (e.g. data/runner.tres); a Genome then
## scales them per enemy (speed, health, vision) and supplies the utility AI weights.

signal died(enemy: Enemy)

@export var stats: EnemyStats

var health: float = 0.0
## True while crossing a climbable tile (fence) with world collision switched off.
var is_climbing: bool = false
## True for an Apex boss (make_boss).
var is_boss: bool = false
## This enemy's genes (null = plain archetype values from `stats`).
var genome: Genome
## Raw fitness facts for the GA (null = not being scored). Shared with the WaveManager.
var fitness_record: FitnessRecord
## What this enemy knows about the player.
var awareness: Awareness = Awareness.new()
## Chooses the action (scores live in the AI layer; this Node executes them).
var brain: UtilityAI
## Flank point used by the Flank action (Vector2.INF = none). For execution and debug display.
var flank_point: Vector2 = Vector2.INF
## Point the enemy is heading for this frame (Vector2.INF = none). For debug display.
var current_target: Vector2 = Vector2.INF
## How the enemy chose its heading this frame: &"sight" (straight at the player), &"flow"
## (arrows, while it can see the player), &"ring" (attack-ring slot / attack / waiting point),
## &"close" (no ring), &"investigate" (straight to last known), &"astar" (A* path to it),
## &"wait_path" (A* result not ready yet), &"flank" (heading for a flank point), &"climb", &"idle".
var nav_mode: StringName = &"idle"
## Sight range after fog and night this frame (for the F6 overlay).
var effective_sight_range: float = 0.0
## Where the enemy is looking (unit vector): the view cone points this way (Reactive Survival V1).
## Moving = the way it walks; chasing = at the player; standing = sweeping around `rest_facing`.
var facing: Vector2 = Vector2.ZERO
## The direction an idle / searching enemy sweeps around: its last walking direction, or the
## last noise it heard. Starts from the spawn position (deterministic, no RNG draw).
var rest_facing: Vector2 = Vector2.ZERO
## Seconds of looking around (drives the sweep).
var _scan_time: float = 0.0

var _ctx: EnemyContext
## Base-profile field: attack-ring engagement and the "close to the player" checks use it so
## every enemy measures distance to the player the same way.
var _flow_field: FlowField
## Field and cost profile for this enemy's own terrain genes (its bucket in FlowFieldSet):
## used for navigation, A* and climbing speed. Same as the base ones without terrain genes.
var _nav_field: FlowField
var nav_profile: TerrainCostProfile
var _grid: TerrainGrid
var _target: Node2D
var _ring: AttackRing
## Shared list of living enemies (owned by WaveManager), used for separation.
var _allies: Array[Enemy] = []
## Collision mask while walking (world + other enemies), and the world-only part of it.
var _normal_mask: int = 0
var _world_mask: int = 0
## Physics layers 1 "world" (solid tiles) and 7 "water" (deep water: blocks walking only).
const WORLD_LAYER_BIT: int = 1
const WATER_LAYER_BIT: int = 1 << 6
var _dead: bool = false
var _weights: ContextSteering.Weights = ContextSteering.Weights.new()
## Allies within the separation radius this frame (reused arrays, no per-frame allocation).
var _near_positions: PackedVector2Array = PackedVector2Array()
var _near_velocities: PackedVector2Array = PackedVector2Array()
## Collision radius, used to make straight-line checks as wide as the body.
var _body_radius: float = 5.0

## A* path to the investigation target, the next waypoint index, and which
## awareness.target_version it was planned for (-1 = no plan).
var _path: Array[Vector2i] = []
var _path_index: int = 0
var _path_version: int = -1
## TerrainGrid.cost_version the path was planned with: terrain changed -> plan again.
var _path_cost_version: int = -1
## Cooldown between blows at a barricade / tries at a door.
var _obstacle_cooldown: float = 0.0
var _waiting_for_path: bool = false
## Remaining tile centres of the current fence climb (last entry = first tile past the fence).
var _climb_cells: Array[Vector2i] = []
## Inputs object reused for every decision, and what perception looked like at the last frame
## (a change triggers an immediate decision instead of waiting for the next 5 Hz tick).
var _inputs: DecisionInputs = DecisionInputs.new()
var _last_awareness_state: int = -1
var _last_target_version: int = -1
## Close-range attack rules and cooldown (only used while holding an attack token).
var _attack: MeleeAttack = MeleeAttack.new()
## Damage multiplier from the ferocity gene (1 = archetype value); the Escort objective uses it too.
var attack_scale: float = 1.0
## Pack tactics (cohesion): regroup time spent in this chase, where the pack is, when this
## enemy last called its pack, and whether it saw the player last frame (to spot the first sighting).
var _regroup_budget: PackCoordination.RegroupBudget = PackCoordination.RegroupBudget.new()
var _regroup_anchor: Vector2 = Vector2.INF
var _share_cooldown: float = 0.0
var _was_chasing: bool = false
## Escort levels: the survivor is perceived now, and where.
var survivor_visible: bool = false
var _survivor_pos: Vector2 = Vector2.INF
## Set by _route_to when the A* search found no way (the caller decides what that means).
var _route_failed: bool = false

@onready var _body: Polygon2D = $Body


func _ready() -> void:
	if genome != null and _ctx != null and _ctx.genome_rules != null:
		_apply_genome(_ctx.genome_rules)
	health = stats.max_health
	_body.color = stats.color
	_normal_mask = collision_mask
	# Feelers and clear-path rays care about everything that blocks walking: world + water.
	_world_mask = collision_mask & (WORLD_LAYER_BIT | WATER_LAYER_BIT)
	_weights.seek = stats.seek_weight
	_weights.separation = stats.separation_weight
	_weights.wall_avoidance = stats.wall_avoidance_weight
	var shape: CircleShape2D = ($CollisionShape2D as CollisionShape2D).shape as CircleShape2D
	if shape != null:
		_body_radius = shape.radius
	EventBus.noise_emitted.connect(_on_noise_emitted)
	if rest_facing == Vector2.ZERO:
		var c: Vector2 = (global_position / 16.0).floor()
		rest_facing = Vector2.from_angle(TAU * fposmod(c.x * 0.618034 + c.y * 0.381966, 1.0))
	facing = rest_facing
	# Golden-ratio phase from the id spreads decisions of many enemies across the 0.2 s window.
	brain = UtilityAI.new(stats.utility_settings, stats.behaviour, fposmod(get_instance_id() * 0.618034, 1.0))


## Called by the spawner before the enemy enters the tree (so _ready can apply the genome).
func setup(context: EnemyContext, allies: Array[Enemy], enemy_genome: Genome = null,
		record: FitnessRecord = null) -> void:
	genome = enemy_genome
	fitness_record = record
	_ctx = context
	_flow_field = context.flow_field
	_grid = _flow_field.grid
	nav_profile = _grid.base_profile
	_nav_field = _flow_field
	if context.flow_fields != null and enemy_genome != null:
		nav_profile = context.flow_fields.canonical_profile(_grid.make_profile(enemy_genome.terrain_genes()))
		_nav_field = context.flow_fields.field_for(nav_profile)
	_target = context.target
	_ring = context.attack_ring
	_allies = allies


## Turns the genome into this enemy's own numbers. `stats` is copied first so the shared
## archetype resource (data/runner.tres) is never changed.
func _apply_genome(rules: GenomeRules) -> void:
	var base: EnemyStats = stats
	stats = base.duplicate() as EnemyStats
	stats.move_speed = genome.move_speed(base.move_speed, rules)
	stats.max_health = genome.max_health(base.max_health, rules)
	stats.sight_range = genome.sight_range(base.sight_range, rules)
	stats.attack_damage = genome.attack_damage(base.attack_damage, rules)
	attack_scale = stats.attack_damage / base.attack_damage if base.attack_damage > 0.0 else 1.0
	stats.attack_cooldown = genome.attack_cooldown(base.attack_cooldown, rules)
	stats.behaviour = genome.to_behaviour_weights()
	# Greybox "visible evolution" (GDD 5.4): more Health gene = bulkier body. Visual only.
	var bulk: float = inverse_lerp(rules.stat_min, rules.stat_max, genome.health)
	_body.scale = Vector2.ONE * lerpf(0.85, 1.25, bulk)


## Survival and pressure time for the fitness record. The distance is the evaluator's
## measurement (god's-eye view), not something the enemy perceives.
func _record_fitness(delta: float) -> void:
	if fitness_record != null and _ctx.fitness != null:
		fitness_record.tick(delta, global_position.distance_to(_target.global_position),
				_ctx.fitness.settings.pressure_radius)


## Call when this enemy damages the player / an escort (fitness term D) by some other route
## than _try_attack (which records its own hits).
func record_damage_dealt(amount: float) -> void:
	if fitness_record != null:
		fitness_record.add_damage(amount)


# --- Attack -------------------------------------------------------------------------

## Hits the player when this enemy holds an attack token, is in range with nothing solid in
## between, and its cooldown is over. Only the HP the player really lost counts for fitness D.
func _try_attack(delta: float, role: AttackRing.Role) -> void:
	_attack.tick(delta)
	if _dead or role != AttackRing.Role.ATTACKING:
		return
	var distance: float = global_position.distance_to(_target.global_position)
	if distance > stats.attack_range:
		return  # cheap checks first; the line test only runs for attackers in range
	var clear: bool = _grid.has_line_of_sight(global_position, _target.global_position)
	if _attack.can_attack(true, distance, stats.attack_range, clear):
		_attack.strike(_target, stats.attack_damage, stats.attack_cooldown, fitness_record)


## Tell the enemy where the player was (e.g. the spawn Pulse). A distant order, not a
## provocation: strength 0, so only patient (hungry) enemies act on it.
func alert(position: Vector2) -> void:
	awareness.hear(position, 0.0)
	_look_towards(position)


## Every enemy within earshot learns where the noise was. How loud it was here (1 right next to
## it, 0 at the edge of the radius) decides whether a lazy enemy bothers to react.
func _on_noise_emitted(noise_position: Vector2, radius: float) -> void:
	if _dead or radius <= 0.0:
		return
	if _ctx != null and _ctx.perception != null and _ctx.conditions != null:
		radius = Perception.hearing_radius(radius, _ctx.conditions.is_night, _night_sense(), _ctx.perception)
	var distance: float = global_position.distance_to(noise_position)
	if distance <= radius:
		awareness.hear(noise_position, 1.0 - distance / radius)
		_look_towards(noise_position)  # even a lazy enemy that stays put turns to look


func _physics_process(delta: float) -> void:
	if _ctx == null or not _flow_field.is_built():
		return
	_record_fitness(delta)
	_obstacle_cooldown = maxf(_obstacle_cooldown - delta, 0.0)
	var cell: Vector2i = _grid.coords.world_to_cell(global_position)
	_update_awareness(delta)
	_update_decision(delta)
	var cost: float = _flow_field.get_cost(cell)
	var role: AttackRing.Role = _update_ring_membership(cost)
	_try_attack(delta, role)
	if is_climbing:
		_climb_step(cell, delta)
		return

	# Execute the chosen action. Chase / Flank need the player in view; the brain re-decides
	# the moment sight is lost, so the fallbacks below only cover that same frame.
	var visible: bool = awareness.state == Awareness.State.CHASE
	var seek_velocity: Vector2 = Vector2.ZERO
	match brain.current:
		UtilityAction.Type.CHASE when visible:
			seek_velocity = _chase_seek(cell, cost, role)
		UtilityAction.Type.FLANK when visible:
			seek_velocity = _flank_seek(cell, cost, role)
		UtilityAction.Type.INVESTIGATE when awareness.has_lead():
			seek_velocity = _investigate_seek(cell)
		UtilityAction.Type.REGROUP when visible:
			seek_velocity = _regroup_seek(cell, cost, role)
		UtilityAction.Type.HUNT_SURVIVOR when survivor_visible:
			seek_velocity = _hunt_survivor_seek(cell)
		_:
			nav_mode = &"idle"
			current_target = Vector2.INF
	if is_climbing:  # a climb started this frame
		_climb_step(cell, delta)
		return

	# Steering: queuing, separation, wall feelers, smoothing.
	_gather_neighbours()
	var queues: bool = (role == AttackRing.Role.NONE or role == AttackRing.Role.WAITING) 			and brain.current != UtilityAction.Type.FLANK
	if cost <= stats.crowd_cost and queues:
		# Near the player a crowd forms: wait behind slower allies instead of shoving them.
		# Slot holders, attackers and flankers skip this so waiting enemies can't block them
		# for good (flankers go round the crowd, they must not queue behind it).
		seek_velocity *= ContextSteering.queue_factor(global_position, seek_velocity, _near_positions, _near_velocities,
				stats.separation_radius, stats.queue_lane_width)
	var separation_push: Vector2 = ContextSteering.separation(global_position, _near_positions, stats.separation_radius)
	var heading: Vector2 = velocity if velocity.length() > 5.0 else seek_velocity
	var wall_push: Vector2 = _wall_push(heading)
	var desired: Vector2 = ContextSteering.combine(seek_velocity, separation_push, wall_push, _weights, stats.move_speed)
	velocity = ContextSteering.smooth_velocity(velocity, desired, stats.acceleration, delta,
			stats.dead_zone_speed, deg_to_rad(stats.max_turn_rate_degrees), stats.turn_limit_min_speed)
	move_and_slide()


# --- Perception ----------------------------------------------------------------------

## Sight check: the only place the enemy reads the player's real position.
## In view within sense_radius = sure at once (CHASE). In view further out = suspicion rises
## (Awareness.notice; full = CHASE). Out of view = suspicion drains, a chase becomes a lead.
## No perception settings (bare test scenes) = the old rule: in view means CHASE.
func _update_awareness(delta: float) -> void:
	_update_facing(delta)
	var in_view: bool = _can_perceive_player()
	var player_pos: Vector2 = _target.global_position
	var p: PerceptionSettings = _ctx.perception if _ctx != null else null
	if in_view:
		var distance: float = global_position.distance_to(player_pos)
		if p == null or distance <= stats.sense_radius:
			awareness.see(player_pos)
		else:
			var rate: float = Perception.suspicion_rate(distance, stats.sense_radius, effective_sight_range,
					awareness.is_alert(), p)
			awareness.notice(player_pos, rate, delta, p.suspicion_investigate_threshold)
	else:
		awareness.unnoticed(delta, stats.utility_settings.lost_sight_strength,
				p.suspicion_decay_per_second if p != null else 1.0)
	var sees_player: bool = awareness.state == Awareness.State.CHASE
	if sees_player and not _was_chasing:
		_call_pack()  # first sighting: tell the packmates where the player is
	_was_chasing = sees_player
	awareness.tick(delta)
	_share_cooldown = maxf(_share_cooldown - delta, 0.0)
	_regroup_budget.tick(delta, brain.current == UtilityAction.Type.REGROUP, sees_player, stats.utility_settings)
	_update_survivor_sight()
	if facing != Vector2.ZERO:
		queue_redraw()  # view cone and suspicion marker


## Turns the gaze (at most turn_speed_degrees per second): at the player while chasing (it sees
## them), the walking direction while moving, at the glimpse spot while suspicion lasts, else a
## sweep around rest_facing (wider and faster while searching).
func _update_facing(delta: float) -> void:
	var p: PerceptionSettings = _ctx.perception if _ctx != null else null
	if p == null:
		return
	_scan_time += delta
	if awareness.state == Awareness.State.CHASE:
		facing = global_position.direction_to(_target.global_position)
		rest_facing = facing
		return
	var desired: Vector2
	if velocity.length() > 5.0:
		desired = velocity.normalized()
		rest_facing = desired
	elif awareness.suspicion > 0.0 and awareness.glimpse != Vector2.INF and awareness.glimpse != global_position:
		desired = global_position.direction_to(awareness.glimpse)  # something caught its eye: stare at it
	elif awareness.state == Awareness.State.SEARCH:
		desired = Perception.scan_facing(rest_facing, _scan_time, p.search_scan_degrees, p.search_scan_period)
	else:
		desired = Perception.scan_facing(rest_facing, _scan_time, p.idle_scan_degrees, p.idle_scan_period)
	if facing == Vector2.ZERO:
		facing = desired
		return
	var max_turn: float = deg_to_rad(p.turn_speed_degrees) * delta
	facing = facing.rotated(clampf(facing.angle_to(desired), -max_turn, max_turn)).normalized()


## A sound or an order: look that way from now on (the sweep centres on it).
func _look_towards(position: Vector2) -> void:
	if position != global_position:
		rest_facing = global_position.direction_to(position)


# --- Pack tactics (cohesion) ----------------------------------------------------------

## Cohesive enemies pass on what they see: every ally within pack_radius gets a lead (where the
## player was seen), as strong as the weaker cohesion of the two allows. Once per cooldown.
func _call_pack() -> void:
	if _share_cooldown > 0.0 or _allies.size() <= 1:
		return
	var s: UtilitySettings = stats.utility_settings
	_share_cooldown = s.pack_share_cooldown
	var r2: float = s.pack_radius * s.pack_radius
	for other: Enemy in _allies:
		if other != self and global_position.distance_squared_to(other.global_position) <= r2:
			other.receive_pack_lead(_target.global_position, stats.behaviour.cohesion)


## A packmate saw the player at `position`. Same lead as a noise (Awareness.hear), as strong as
## both cohesions allow: a loner hardly reacts. Ignored while this enemy is chasing already.
func receive_pack_lead(position: Vector2, sender_cohesion: float) -> void:
	if _dead:
		return
	var strength: float = PackCoordination.share_strength(sender_cohesion, stats.behaviour.cohesion, stats.utility_settings)
	if strength > 0.0:
		awareness.hear(position, strength)


## Packmates that are engaged (they know about the player: chasing or investigating).
func _engaged_pack_positions() -> PackedVector2Array:
	var list: PackedVector2Array = PackedVector2Array()
	for other: Enemy in _allies:
		if other != self and not other._dead and (other.awareness.state == Awareness.State.CHASE
				or other.awareness.state == Awareness.State.INVESTIGATE):
			list.append(other.global_position)
	return list


# --- Escort survivor ------------------------------------------------------------------

## The survivor is seen by the same rules as the player: always within sense_radius, further out
## only inside the (fog / night adjusted) sight range with a clear grid line.
func _update_survivor_sight() -> void:
	survivor_visible = false
	var escort: Object = _ctx.escort if _ctx != null else null
	if escort == null or not escort.has_method("is_survivor_alive") or not escort.is_survivor_alive():
		return
	_survivor_pos = escort.survivor
	var distance: float = global_position.distance_to(_survivor_pos)
	if distance <= stats.sense_radius:
		survivor_visible = true
	elif distance <= effective_sight_range and _in_cone(_survivor_pos):
		survivor_visible = _grid.has_line_of_sight(global_position, _survivor_pos)


## Within sense_radius the enemy always notices the player (GDD 4.3: even stealth only hides
## you beyond 2 tiles). Further out the player must not be concealed (tall grass) and needs a
## clear line of sight over the grid within the sight range after fog and night (Perception).
func _can_perceive_player() -> bool:
	var player_pos: Vector2 = _target.global_position
	var distance: float = global_position.distance_to(player_pos)
	effective_sight_range = stats.sight_range
	var concealed: bool = false
	if _ctx != null and _ctx.perception != null:
		var fog: float = minf(_grid.vision_multiplier(_grid.coords.world_to_cell(global_position)),
				_grid.vision_multiplier(_grid.coords.world_to_cell(player_pos)))
		var night: bool = _ctx.conditions != null and _ctx.conditions.is_night
		effective_sight_range = Perception.effective_sight_range(stats.sight_range, fog, night, _night_sense(), _ctx.perception)
		concealed = _target.has_method("is_concealed") and _target.is_concealed()
	if distance <= stats.sense_radius:
		return true
	if concealed or distance > effective_sight_range or not _in_cone(player_pos):
		return false  # cheap checks first; the line only runs when it can matter
	return Perception.can_see(distance, stats.sense_radius, effective_sight_range,
			_grid.has_line_of_sight(global_position, player_pos), concealed)


## Inside this enemy's view cone (always true without perception settings).
func _in_cone(point: Vector2) -> bool:
	if _ctx == null or _ctx.perception == null:
		return true
	return Perception.in_view_cone(point - global_position, facing, _ctx.perception.view_cone_degrees)


func _night_sense() -> float:
	return genome.night_sense if genome != null else 0.0


# --- Decisions ----------------------------------------------------------------------

## Runs the utility AI at its fixed rate, or straight away when perception changed
## (player came into / went out of view, new noise, search finished).
func _update_decision(delta: float) -> void:
	if awareness.state != _last_awareness_state or awareness.target_version != _last_target_version:
		brain.request_decision()
	_last_awareness_state = awareness.state
	_last_target_version = awareness.target_version
	if brain.tick(delta):
		brain.decide(_gather_inputs())


## Fills the DecisionInputs from our senses. Player details are only read while visible.
func _gather_inputs() -> DecisionInputs:
	var visible: bool = awareness.state == Awareness.State.CHASE
	_inputs.player_visible = visible
	_inputs.has_lead = awareness.has_lead()
	_inputs.lead_age = awareness.lead_age
	_inputs.lead_strength = awareness.lead_strength
	_inputs.wave_pressure = stats.utility_settings.wave_pressure(_ctx.wave_seconds)
	_inputs.allies_chasing = 0
	_inputs.flank_point_available = false
	if visible:
		var player_pos: Vector2 = _target.global_position
		_inputs.distance_to_player = global_position.distance_to(player_pos)
		var facing: Vector2 = _player_facing()
		_inputs.player_facing_dot = facing.dot((global_position - player_pos).normalized()) \
				if facing != Vector2.ZERO else 1.0
		flank_point = FlankPlanner.choose(player_pos, facing, global_position, _nav_field, stats.utility_settings)
		_inputs.flank_point_available = flank_point != Vector2.INF
		var radius_sq: float = stats.utility_settings.ally_radius * stats.utility_settings.ally_radius
		for other: Enemy in _allies:
			if other != self and other.brain.current == UtilityAction.Type.CHASE \
					and global_position.distance_squared_to(other.global_position) <= radius_sq:
				_inputs.allies_chasing += 1
	else:
		_inputs.distance_to_player = INF
		_inputs.player_facing_dot = 1.0
	_gather_pack_inputs(visible)
	_inputs.survivor_visible = survivor_visible
	_inputs.survivor_distance = global_position.distance_to(_survivor_pos) if survivor_visible else INF
	return _inputs


## Pack facts for RegroupAction: how many engaged packmates are close, where they are, whether a
## clear line to them exists, and whether this enemy's regroup time is used up.
func _gather_pack_inputs(visible: bool) -> void:
	var s: UtilitySettings = stats.utility_settings
	_inputs.pack_size = 0
	_inputs.regroup_available = false
	_regroup_anchor = Vector2.INF
	_inputs.regroup_expired = _regroup_budget.expired(s)
	if not visible or stats.behaviour.cohesion <= 0.0:
		return  # only cohesive enemies that see the player ever regroup
	var mates: PackedVector2Array = _engaged_pack_positions()
	_inputs.pack_size = PackCoordination.count_within(global_position, mates, s.pack_radius)
	_regroup_anchor = PackCoordination.anchor(global_position, mates, s.regroup_search_radius)
	_inputs.regroup_available = _regroup_anchor != Vector2.INF and _clear_path_to(_regroup_anchor)


## Direction the player is looking (aim), or ZERO if the target has no aim.
func _player_facing() -> Vector2:
	var aim: Variant = _target.get("aim_direction")
	return aim if aim is Vector2 else Vector2.ZERO


# --- FLANK: circle to the player's blind side ----------------------------------------

func _flank_seek(cell: Vector2i, cost: float, role: AttackRing.Role) -> Vector2:
	flank_point = FlankPlanner.choose(_target.global_position, _player_facing(), global_position,
			_nav_field, stats.utility_settings)
	if flank_point == Vector2.INF:
		return _chase_seek(cell, cost, role)  # no usable side this frame: just chase
	current_target = flank_point
	if _clear_path_to(flank_point):
		nav_mode = &"flank"
		return ContextSteering.arrive(flank_point - global_position, stats.move_speed, stats.arrive_radius)
	# Way to the flank point blocked: the flow field gets us round the obstacle towards the
	# player (fair, the player is in view), and the straight line opens up on the way.
	var next: Vector2i = _nav_field.get_next_cell(cell)
	if _handle_obstacle(next):
		return Vector2.ZERO
	if _is_climbable(next):
		_start_climb(_flow_climb_cells(next))
		return Vector2.ZERO
	nav_mode = &"flank"
	return ContextSteering.seek(ContextSteering.sample_flow(_nav_field, global_position), stats.move_speed)


# --- CHASE: player perceived right now -----------------------------------------------

func _chase_seek(cell: Vector2i, cost: float, role: AttackRing.Role) -> Vector2:
	current_target = _target.global_position
	if role != AttackRing.Role.NONE:
		return _ring_seek(role)
	if _ring == null and cost <= stats.close_in_cost:
		nav_mode = &"close"
		return ContextSteering.arrive(current_target - global_position, stats.move_speed, stats.arrive_radius)
	var straight: Vector2 = _straight_chase_point()
	if straight != Vector2.INF:
		nav_mode = &"sight"
		current_target = straight
		return ContextSteering.seek(straight - global_position, stats.move_speed)
	# Can see the player but can't run straight at them (a fence or corner in the way):
	# the flow field knows the way, and using it is fair because the player is in view.
	var next: Vector2i = _nav_field.get_next_cell(cell)
	if _handle_obstacle(next):
		return Vector2.ZERO
	if _is_climbable(next):
		_start_climb(_flow_climb_cells(next))
		return Vector2.ZERO
	nav_mode = &"flow"
	return ContextSteering.seek(ContextSteering.sample_flow(_nav_field, global_position), stats.move_speed)


## Pursuit: the predicted player position if the body can run straight there, else the
## current position, else Vector2.INF.
func _straight_chase_point() -> Vector2:
	var target_pos: Vector2 = _target.global_position
	var target_velocity: Vector2 = Vector2.ZERO
	if _target is CharacterBody2D:
		target_velocity = (_target as CharacterBody2D).velocity
	var predicted: Vector2 = ContextSteering.predict_position(target_pos, target_velocity, stats.prediction_time)
	if _clear_path_to(predicted):
		return predicted
	if predicted != target_pos and _clear_path_to(target_pos):
		return target_pos
	return Vector2.INF


## Only enemies that can perceive the player take part in the ring. Join when the flow cost
## is low enough, leave when it is clearly too high (in between: keep what we had).
func _update_ring_membership(cost: float) -> AttackRing.Role:
	if _ring == null:
		return AttackRing.Role.NONE
	var id: int = get_instance_id()
	var chasing: bool = awareness.state == Awareness.State.CHASE and brain.current == UtilityAction.Type.CHASE
	if chasing and (cost <= _ring.settings.engage_cost or (_ring.is_member(id) and cost <= _ring.settings.release_cost)):
		_ring.engage(id, global_position)
	else:
		_ring.disengage(id)
	return _ring.get_role(id)


## Straight to the ring target when the way is clear, otherwise the flow field.
func _ring_seek(role: AttackRing.Role) -> Vector2:
	var target: Vector2 = _ring.get_target(get_instance_id())
	current_target = target
	var clear: bool = _clear_path_to(target)
	if role == AttackRing.Role.WAITING and not clear \
			and global_position.distance_to(_ring.center) <= _ring.settings.wait_radius:
		nav_mode = &"ring"
		return Vector2.ZERO  # too close and boxed in: hold still rather than push inwards
	if clear:
		nav_mode = &"ring"
		return ContextSteering.arrive(target - global_position, stats.move_speed, stats.arrive_radius)
	nav_mode = &"flow"
	return ContextSteering.seek(ContextSteering.sample_flow(_nav_field, global_position), stats.move_speed)


# --- REGROUP: wait for the pack, then go together ---------------------------------------

## Walks to the packmates (their centroid). The pack's size is checked at each decision, so the
## moment enough of them are close every member switches to Chase. No anchor or no clear line:
## behave like Chase this frame (the next decision drops Regroup).
func _regroup_seek(cell: Vector2i, cost: float, role: AttackRing.Role) -> Vector2:
	if _regroup_anchor == Vector2.INF or not _clear_path_to(_regroup_anchor):
		return _chase_seek(cell, cost, role)
	current_target = _regroup_anchor
	nav_mode = &"regroup"
	return ContextSteering.arrive(_regroup_anchor - global_position, stats.move_speed, stats.arrive_radius)


# --- HUNT_SURVIVOR: go for the Escort survivor ----------------------------------------------

## Straight at the survivor when the fat ray is clear, else an A* route (shared PathQueue, re-planned
## when the survivor has moved two cells). It stands next to the survivor; the Escort objective
## applies the hits (nearest attackers only, this enemy's cooldown and ferocity).
func _hunt_survivor_seek(cell: Vector2i) -> Vector2:
	var goal: Vector2 = _survivor_pos
	current_target = goal
	if global_position.distance_to(goal) <= stats.investigate_arrive_distance:
		nav_mode = &"hunt"
		_drop_path()
		return Vector2.ZERO
	var key: int = hash(_grid.coords.world_to_cell(goal) / 2)
	var velocity_out: Vector2 = _route_to(cell, goal, key)
	if _route_failed:
		return Vector2.ZERO  # unreachable: hold rather than push at a wall
	if nav_mode == &"investigate":
		nav_mode = &"hunt"
	return velocity_out


# --- INVESTIGATE: go to the last known position --------------------------------------

func _investigate_seek(cell: Vector2i) -> Vector2:
	var goal: Vector2 = awareness.last_known
	current_target = goal
	var dist: float = global_position.distance_to(goal)
	# Checked once we stand on the spot - or can see it close up (a crowd may block the spot
	# itself; seeing that it is empty is enough to know the player isn't there).
	if dist <= stats.investigate_arrive_distance 			or (dist <= stats.investigate_view_distance and _grid.has_line_of_sight(global_position, goal)):
		awareness.arrive(stats.search_time)  # nothing here: look around, then give up
		_drop_path()
		return Vector2.ZERO
	var velocity_out: Vector2 = _route_to(cell, goal, awareness.target_version)
	if _route_failed:
		awareness.arrive(stats.search_time)  # unreachable: search where we are
	return velocity_out


## Shared by Investigate and Hunt: straight to `goal` when the way is clear, else follow an A* path
## from the shared queue. `plan_key` identifies the target: a new key means "plan again". Sets
## _route_failed when the search found no way.
func _route_to(cell: Vector2i, goal: Vector2, plan_key: int) -> Vector2:
	_route_failed = false
	if _clear_path_to(goal):
		# Straight there, no search needed.
		nav_mode = &"investigate"
		_drop_path()
		return ContextSteering.arrive(goal - global_position, stats.move_speed, stats.arrive_radius)

	var id: int = get_instance_id()
	if _path_cost_version != _grid.cost_version and not _waiting_for_path:
		_path_version = -1  # terrain changed since planning (fire, collapse, wall...): plan again
	if _path_version != plan_key:
		# New target (or no plan yet): ask the shared queue for an A* path.
		_path_version = plan_key
		_path_cost_version = _grid.cost_version
		_path.clear()
		_ctx.path_queue.request(id, cell, _grid.coords.world_to_cell(goal), nav_profile)
		_waiting_for_path = true
	if _waiting_for_path:
		if not _ctx.path_queue.has_result(id):
			nav_mode = &"wait_path"
			return Vector2.ZERO
		_waiting_for_path = false
		_path = _ctx.path_queue.take_result(id)
		_path_index = 1  # _path[0] is the cell we started in
		if _path.is_empty():
			_route_failed = true  # unreachable
			return Vector2.ZERO

	# Follow the waypoints (tile centres).
	while _path_index < _path.size() \
			and global_position.distance_to(_grid.coords.cell_to_world(_path[_path_index])) < stats.waypoint_radius:
		_path_index += 1
	if _path_index >= _path.size():
		nav_mode = &"investigate"
		return ContextSteering.arrive(goal - global_position, stats.move_speed, stats.arrive_radius)
	var waypoint: Vector2 = _grid.coords.cell_to_world(_path[_path_index])
	if global_position.distance_to(waypoint) > stats.off_path_distance:
		_path_version = -1  # pushed off the path by the crowd: re-plan from here next frame
	if _handle_obstacle(_path[_path_index]):
		return Vector2.ZERO
	if _is_climbable(_path[_path_index]):
		_start_climb(_path_climb_cells())
		return Vector2.ZERO
	nav_mode = &"astar"
	return ContextSteering.seek(waypoint - global_position, stats.move_speed)


func _drop_path() -> void:
	_path.clear()
	_path_version = -1
	if _waiting_for_path:
		_ctx.path_queue.cancel(get_instance_id())
		_waiting_for_path = false


## Remaining A* waypoints (for debug drawing). Empty when not following a path.
func get_debug_path() -> Array[Vector2i]:
	var rest: Array[Vector2i] = []
	if awareness.state == Awareness.State.INVESTIGATE and _path_index < _path.size():
		rest.assign(_path.slice(_path_index))
	return rest


# --- Fence climbing ------------------------------------------------------------------

## Climb tiles taken from the flow field: the fence tiles, then the first tile past them.
func _flow_climb_cells(first: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = [first]
	while _is_climbable(cells[-1]) and cells.size() < 32:
		cells.append(_nav_field.get_next_cell(cells[-1]))
	return cells


## Climb tiles taken from the A* path, advancing the path past them.
func _path_climb_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	while _path_index < _path.size():
		cells.append(_path[_path_index])
		_path_index += 1
		if not _is_climbable(cells[-1]):
			break
	return cells


## Crosses a fence tile centre to tile centre with world collision off. Safe because routes
## only lead into walkable tiles and never cut wall corners.
func _start_climb(cells: Array[Vector2i]) -> void:
	is_climbing = true
	collision_mask = 0
	_climb_cells = cells


func _climb_step(cell: Vector2i, delta: float) -> void:
	nav_mode = &"climb"
	if _climb_cells.is_empty():
		is_climbing = false
		collision_mask = _normal_mask
		return
	var goal: Vector2 = _grid.coords.cell_to_world(_climb_cells[0])
	current_target = goal
	var speed: float = stats.move_speed
	if _is_climbable(cell):
		speed /= _grid.get_cost(cell, nav_profile)  # fence cost 6 -> 6x slower (climber: less)
	velocity = global_position.direction_to(goal) * speed
	global_position = global_position.move_toward(goal, speed * delta)
	if global_position.distance_to(goal) < 0.5:
		_climb_cells.pop_front()


## Barricades (BREAK) and closed doors (OPEN) on the route: walk up to the tile, then hit it
## (attack_damage every attack_cooldown) or open it. Returns true while busy with it, so the
## caller stands still. The route goes through such tiles because their cost includes this.
func _handle_obstacle(next: Vector2i) -> bool:
	var traversal: TerrainDefinition.Traversal = _grid.enemy_traversal(next)
	if traversal != TerrainDefinition.Traversal.BREAK and traversal != TerrainDefinition.Traversal.OPEN:
		return false
	if _ctx == null or _ctx.terrain_health == null:
		return false
	var at: Vector2 = _grid.coords.cell_to_world(next)
	if global_position.distance_to(at) > _grid.coords.tile_size + _body_radius + 2.0:
		return false  # not there yet: keep following the route into it
	nav_mode = &"break"
	current_target = at
	if _obstacle_cooldown <= 0.0:
		_obstacle_cooldown = stats.attack_cooldown
		if traversal == TerrainDefinition.Traversal.OPEN:
			_ctx.terrain_health.open_door(next)
		else:
			_ctx.terrain_health.damage(next, stats.attack_damage)
	return true


## True for tiles that are solid for physics but crossed with collision off (fence climbing;
## later swimming / crawling). Comes from the shared terrain rulebook (TerrainDefinition).
func _is_climbable(cell: Vector2i) -> bool:
	return TerrainDefinition.crosses_solid(_grid.enemy_traversal(cell))


# --- World queries (physics) ---------------------------------------------------------

## True if a body of our radius could move in a straight line to `point` without hitting
## the world (three parallel rays: centre and both sides).
func _clear_path_to(point: Vector2) -> bool:
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	for offset: Vector2 in ContextSteering.lane_offsets(global_position, point, _body_radius):
		var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(
				global_position + offset, point + offset, _world_mask)
		if not space.intersect_ray(query).is_empty():
			return false
	return true


## Casts the feeler rays against the world layer and asks ContextSteering for a push.
func _wall_push(heading: Vector2) -> Vector2:
	if heading == Vector2.ZERO:
		return Vector2.ZERO
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var feelers: PackedVector2Array = ContextSteering.feeler_directions(heading, deg_to_rad(stats.feeler_angle_degrees))
	var fractions: PackedFloat32Array = PackedFloat32Array()
	var normals: PackedVector2Array = PackedVector2Array()
	for dir: Vector2 in feelers:
		var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(
			global_position, global_position + dir * stats.feeler_length, _world_mask)
		var hit: Dictionary = space.intersect_ray(query)
		if hit.is_empty():
			fractions.append(1.0)
			normals.append(Vector2.ZERO)
		else:
			var hit_pos: Vector2 = hit["position"]
			fractions.append(global_position.distance_to(hit_pos) / stats.feeler_length)
			normals.append(hit["normal"])
	return ContextSteering.wall_avoidance(fractions, normals)


## Fills _near_positions / _near_velocities with allies inside the separation radius.
func _gather_neighbours() -> void:
	_near_positions.clear()
	_near_velocities.clear()
	var radius_sq: float = stats.separation_radius * stats.separation_radius
	for other: Enemy in _allies:
		if other != self and global_position.distance_squared_to(other.global_position) < radius_sq:
			_near_positions.append(other.global_position)
			_near_velocities.append(other.velocity)


# --- Health --------------------------------------------------------------------------

## Called by player bullets (Bullet._on_body_entered).
func take_damage(amount: float) -> void:
	if _dead:
		return
	health -= amount
	queue_redraw()
	_body.color = Color.WHITE
	create_tween().tween_property(_body, "color", stats.color, 0.12)
	if health <= 0.0:
		_die()


## Removes the enemy without it counting as killed (e.g. leftovers when the next wave starts).
## Its fitness record should already be frozen by the wave end.
func despawn() -> void:
	if _dead:
		return
	_dead = true
	if fitness_record != null:
		fitness_record.freeze()
	var id: int = get_instance_id()
	if _ring != null:
		_ring.disengage(id)
	if _ctx != null:
		_ctx.path_queue.cancel(id)
	collision_layer = 0
	collision_mask = 0
	set_physics_process(false)
	queue_free()


func _die() -> void:
	_dead = true
	if fitness_record != null:
		fitness_record.mark_dead()
	var id: int = get_instance_id()
	if _ring != null:
		_ring.disengage(id)
	if _ctx != null:
		_ctx.path_queue.cancel(id)
	collision_layer = 0
	collision_mask = 0
	set_physics_process(false)
	died.emit(self)
	EventBus.enemy_killed.emit(self)
	queue_free()


## Turns this enemy into a zone boss (Apex objective): more HP and damage, bigger, purple.
## Placeholder until boss designs exist - no new attacks. Call after it entered the tree.
func make_boss(health_multiplier: float, damage_multiplier: float, size: float) -> void:
	stats = stats.duplicate() as EnemyStats
	stats.max_health *= health_multiplier
	stats.attack_damage *= damage_multiplier
	stats.color = Color(0.6, 0.2, 0.85)
	health = stats.max_health
	_body.color = stats.color
	_body.scale *= size
	is_boss = true


## Greybox view cone (tinted white -> yellow -> red by suspicion), the suspicion marker
## ("?" with a fill bar, "!" once it sees you) and the health bar once damaged.
func _draw() -> void:
	_draw_senses()
	if health >= stats.max_health or health <= 0.0:
		return
	var width: float = 12.0
	var top_left: Vector2 = Vector2(-width / 2.0, -10.0)
	draw_rect(Rect2(top_left, Vector2(width, 2)), Color(0.1, 0.1, 0.1))
	draw_rect(Rect2(top_left, Vector2(width * health / stats.max_health, 2)), Color(0.4, 1, 0.4))


func _draw_senses() -> void:
	if _dead or facing == Vector2.ZERO or _ctx == null or _ctx.perception == null:
		return
	var s: float = awareness.suspicion
	var tint: Color = Color.WHITE.lerp(Color(1, 0.9, 0.2), clampf(s * 2.0, 0.0, 1.0)) \
			.lerp(Color(1, 0.2, 0.2), clampf(s * 2.0 - 1.0, 0.0, 1.0))
	var reach: float = effective_sight_range if effective_sight_range > 0.0 else stats.sight_range
	var half: float = deg_to_rad(_ctx.perception.view_cone_degrees) * 0.5
	if half < PI:
		var points: PackedVector2Array = PackedVector2Array([Vector2.ZERO])
		for i: int in 13:
			points.append(facing.rotated(lerpf(-half, half, i / 12.0)) * reach)
		draw_colored_polygon(points, Color(tint, 0.06 + 0.12 * s))
	if s <= 0.05:
		return
	var font: Font = ThemeDB.fallback_font
	var chasing: bool = awareness.state == Awareness.State.CHASE
	var mark: String = "!" if chasing else "?"
	draw_string_outline(font, Vector2(-2, -13), mark, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, 2, Color.BLACK)
	draw_string(font, Vector2(-2, -13), mark, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, tint)
	if not chasing:
		draw_rect(Rect2(-6, -21, 12, 2), Color(0, 0, 0, 0.7))
		draw_rect(Rect2(-6, -21, 12 * s, 2), tint)

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

var _ctx: EnemyContext
var _flow_field: FlowField
var _grid: TerrainGrid
var _target: Node2D
var _ring: AttackRing
## Shared list of living enemies (owned by WaveManager), used for separation.
var _allies: Array[Enemy] = []
## Collision mask while walking (world + other enemies), and the world-only part of it.
var _normal_mask: int = 0
var _world_mask: int = 0
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

@onready var _body: Polygon2D = $Body


func _ready() -> void:
	if genome != null and _ctx != null and _ctx.genome_rules != null:
		_apply_genome(_ctx.genome_rules)
	health = stats.max_health
	_body.color = stats.color
	_normal_mask = collision_mask
	_world_mask = collision_mask & 1  # feelers and climbing only care about the world layer
	_weights.seek = stats.seek_weight
	_weights.separation = stats.separation_weight
	_weights.wall_avoidance = stats.wall_avoidance_weight
	var shape: CircleShape2D = ($CollisionShape2D as CollisionShape2D).shape as CircleShape2D
	if shape != null:
		_body_radius = shape.radius
	EventBus.noise_emitted.connect(_on_noise_emitted)
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


## Every enemy within earshot learns where the noise was. How loud it was here (1 right next to
## it, 0 at the edge of the radius) decides whether a lazy enemy bothers to react.
func _on_noise_emitted(noise_position: Vector2, radius: float) -> void:
	if _dead or radius <= 0.0:
		return
	var distance: float = global_position.distance_to(noise_position)
	if distance <= radius:
		awareness.hear(noise_position, 1.0 - distance / radius)


func _physics_process(delta: float) -> void:
	if _ctx == null or not _flow_field.is_built():
		return
	_record_fitness(delta)
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
func _update_awareness(delta: float) -> void:
	if _can_perceive_player():
		awareness.see(_target.global_position)
	else:
		awareness.lose_sight(stats.utility_settings.lost_sight_strength)
	awareness.tick(delta)


## Within sense_radius the enemy always notices the player (GDD 4.3: even stealth only hides
## you beyond 2 tiles). Further out it needs a clear line of sight over the grid, within range.
func _can_perceive_player() -> bool:
	var player_pos: Vector2 = _target.global_position
	var dist_sq: float = global_position.distance_squared_to(player_pos)
	if dist_sq <= stats.sense_radius * stats.sense_radius:
		return true
	if dist_sq > stats.sight_range * stats.sight_range:
		return false
	return _grid.has_line_of_sight(global_position, player_pos)


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
	_inputs.allies_chasing = 0
	_inputs.flank_point_available = false
	if visible:
		var player_pos: Vector2 = _target.global_position
		_inputs.distance_to_player = global_position.distance_to(player_pos)
		var facing: Vector2 = _player_facing()
		_inputs.player_facing_dot = facing.dot((global_position - player_pos).normalized()) \
				if facing != Vector2.ZERO else 1.0
		flank_point = FlankPlanner.choose(player_pos, facing, global_position, _flow_field, stats.utility_settings)
		_inputs.flank_point_available = flank_point != Vector2.INF
		var radius_sq: float = stats.utility_settings.ally_radius * stats.utility_settings.ally_radius
		for other: Enemy in _allies:
			if other != self and other.brain.current == UtilityAction.Type.CHASE \
					and global_position.distance_squared_to(other.global_position) <= radius_sq:
				_inputs.allies_chasing += 1
	else:
		_inputs.distance_to_player = INF
		_inputs.player_facing_dot = 1.0
	return _inputs


## Direction the player is looking (aim), or ZERO if the target has no aim.
func _player_facing() -> Vector2:
	var aim: Variant = _target.get("aim_direction")
	return aim if aim is Vector2 else Vector2.ZERO


# --- FLANK: circle to the player's blind side ----------------------------------------

func _flank_seek(cell: Vector2i, cost: float, role: AttackRing.Role) -> Vector2:
	flank_point = FlankPlanner.choose(_target.global_position, _player_facing(), global_position,
			_flow_field, stats.utility_settings)
	if flank_point == Vector2.INF:
		return _chase_seek(cell, cost, role)  # no usable side this frame: just chase
	current_target = flank_point
	if _clear_path_to(flank_point):
		nav_mode = &"flank"
		return ContextSteering.arrive(flank_point - global_position, stats.move_speed, stats.arrive_radius)
	# Way to the flank point blocked: the flow field gets us round the obstacle towards the
	# player (fair, the player is in view), and the straight line opens up on the way.
	var next: Vector2i = _flow_field.get_next_cell(cell)
	if _is_climbable(next):
		_start_climb(_flow_climb_cells(next))
		return Vector2.ZERO
	nav_mode = &"flank"
	return ContextSteering.seek(ContextSteering.sample_flow(_flow_field, global_position), stats.move_speed)


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
	var next: Vector2i = _flow_field.get_next_cell(cell)
	if _is_climbable(next):
		_start_climb(_flow_climb_cells(next))
		return Vector2.ZERO
	nav_mode = &"flow"
	return ContextSteering.seek(ContextSteering.sample_flow(_flow_field, global_position), stats.move_speed)


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
	return ContextSteering.seek(ContextSteering.sample_flow(_flow_field, global_position), stats.move_speed)


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
	if _clear_path_to(goal):
		# Straight there, no search needed.
		nav_mode = &"investigate"
		_drop_path()
		return ContextSteering.arrive(goal - global_position, stats.move_speed, stats.arrive_radius)

	var id: int = get_instance_id()
	if _path_version != awareness.target_version:
		# New target (or no plan yet): ask the shared queue for an A* path.
		_path_version = awareness.target_version
		_path.clear()
		_ctx.path_queue.request(id, cell, _grid.coords.world_to_cell(goal))
		_waiting_for_path = true
	if _waiting_for_path:
		if not _ctx.path_queue.has_result(id):
			nav_mode = &"wait_path"
			return Vector2.ZERO
		_waiting_for_path = false
		_path = _ctx.path_queue.take_result(id)
		_path_index = 1  # _path[0] is the cell we started in
		if _path.is_empty():
			awareness.arrive(stats.search_time)  # unreachable: search where we are
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
	while _is_climbable(cells[-1]) and cells.size() < 8:
		cells.append(_flow_field.get_next_cell(cells[-1]))
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
		speed /= _grid.get_cost(cell, _flow_field.profile)  # fence cost 6 -> 6x slower
	velocity = global_position.direction_to(goal) * speed
	global_position = global_position.move_toward(goal, speed * delta)
	if global_position.distance_to(goal) < 0.5:
		_climb_cells.pop_front()


func _is_climbable(cell: Vector2i) -> bool:
	return stats.climbable_terrains.has(_grid.get_terrain(cell))


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


## Greybox health bar, shown once damaged.
func _draw() -> void:
	if health >= stats.max_health or health <= 0.0:
		return
	var width: float = 12.0
	var top_left: Vector2 = Vector2(-width / 2.0, -10.0)
	draw_rect(Rect2(top_left, Vector2(width, 2)), Color(0.1, 0.1, 0.1))
	draw_rect(Rect2(top_left, Vector2(width * health / stats.max_health, 2)), Color(0.4, 1, 0.4))

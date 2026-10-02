# Amortia — session handoff

Read this first in a new session, together with `CLAUDE.md` and `Game Design Document.md`.
It is updated at the end of every prompt. Last update: 2026-10-02.

## Where we are
Phase 1 greybox prototype (GDD §11.1 calls it "Phase 0" — same thing). Work goes one step per
prompt; the user says when to move on. Never start the next step automatically.

### Done
| # | Step | Key files |
|---|---|---|
| 1 | Project setup: 480×270 viewport, integer scale to 1080p, Nearest filter, physics layer names 1–6, `EventBus` autoload, folder tree | `project.godot`, `autoload/event_bus.gd` |
| 2 | Player movement: WASD with accel/friction, normalized diagonals, body faces mouse, smoothed Camera2D | `entities/player/player.gd`, `player.tscn`, `player_stats.gd`, `data/player_stats.tres` |
| 3 | Shooting: LMB, semi-auto pistol, cooldown, Area2D bullet (layer 4, mask world+enemies), calls `take_damage(amount)` on hit if present | `entities/projectiles/bullet.gd/.tscn`, `weapon_stats.gd`, `data/pistol.tres` |
| 4 | Dodge roll: Space, 0.3 s invuln, 1.2 s cooldown, movement dir or aim dir if still. `is_invulnerable` property. Temporary `debug_dodge` export (prints + see-through body) — turn off once damage exists | `player.gd`, `player_stats.gd` |
| 5 | Maple Hollow greybox map: 60×34 TileMapLayer, terrains road/grass/tall_grass/fence/wall/house via `terrain` custom data, PlayerSpawn + 8 EnemySpawns, fences with gates for alternate routes | `tools/build_maple_hollow.gd`, `world/tilesets/greybox_tileset.tres`, `world/zones/maple_hollow/maple_hollow.tscn`, `world/zones/zone_map.gd`, `world/main.gd/.tscn` |
| 6 | Terrain-cost grid + GUT 9.7.1: `TerrainGrid` (RefCounted, flat cost array, INF = impassable, 8-way neighbours with no corner cutting, √2 diagonal step cost, set_terrain for runtime changes, world↔cell). Costs in `TerrainCosts` resource (road/grass 1, tall_grass 2, fence 6, wall/house INF; unknown terrain = INF). `main.gd` builds `terrain_grid` from the map at startup. F1 toggles a cost overlay. 13 GUT tests pass | `ai/grid/terrain_grid.gd`, `ai/grid/terrain_costs.gd`, `data/terrain_costs.tres`, `tests/test_terrain_grid.gd`, `ui/debug/terrain_cost_overlay.gd`, `addons/gut/`, `.gutconfig.json` |
| 7 | TerrainGrid v2 (AI foundation): cells store terrain **ids**; costs come from a `TerrainCostProfile` (base, or built from terrain genes: passable → `lerp(base, adapted, gene)`, impassable → `adapted` once gene ≥ `unlock_threshold` 0.5; cheapest trait wins). Coordinates moved to `GridCoords` (tile size + origin). `terrain_costs.tres` now holds the full GDD §4.2 table + adaptations (climber fence 2, swimmer shallow 1 / deep 2, crawler vent 1, toxin_resistance toxic_pool 2). 37 GUT tests pass | `ai/grid/grid_coords.gd`, `ai/grid/terrain_cost_profile.gd`, `ai/grid/terrain_grid.gd`, `ai/grid/terrain_costs.gd`, `tests/test_grid_coords.gd`, `tests/test_terrain_cost_profile.gd`, `tests/test_terrain_costs.gd`, `tests/test_terrain_grid.gd` |
| 8 | Hand-written A* (learning-mode file, written on request): f = g + h, octile heuristic × `profile.get_min_cost()`, binary `MinHeap` open list with lazy deletion (stale entries skipped), dictionaries for g / came_from / closed, returns `Array[Vector2i]` start→goal or `[]`; `last_cost` / `last_expanded` stats for experiment N2. Optional profile (climber etc.). Not wired to enemies. 59 GUT tests pass incl. A* = brute-force Dijkstra on 40 random grids | `ai/nav/astar.gd`, `ai/util/min_heap.gd`, `tests/test_astar.gd`, `tests/test_min_heap.gd`, `TerrainCostProfile.get_min_cost()` |
| 9 | Shared flow field (learning-mode file, written on request): Dijkstra/UCS outward from the player's cell; per cell integration cost (INF = unreachable) + next-cell index; step a→b pays cost of ENTERING b; same no-corner-cutting rule as TerrainGrid. Optimised: flat int indices + `TerrainGrid.build_cost_array(profile)` instead of `get_neighbors`, and MinHeap rewritten with "hole" sifting → rebuild ~7.5 ms (max ~9.5) on Maple Hollow in debug headless (was 46–73 ms). `main.gd` rebuilds it when the player enters a new walkable cell. F2 = arrow overlay (yellow near → blue far, magenta dot = walkable but unreachable). 75 GUT tests pass incl. field cost = A* cost from every cell on 15 random grids | `ai/nav/flow_field.gd`, `tests/test_flow_field.gd`, `ui/debug/flow_field_overlay.gd`, `world/main.gd/.tscn`, `ai/util/min_heap.gd` |
| 10 | Runner enemy + prototype WaveManager: `Enemy` (CharacterBody2D, layer 3, mask 1) is a thin shell — reads `FlowField.get_direction(cell)`, gets velocity from `Steering` (pure: seek, arrive, separation, blend), smooths with `acceleration`. In the player's tile it `arrive`s at the player. HP + `take_damage` (white flash, HP bar once hurt), `died` signal, clean `queue_free`. **Fence climbing**: flow field allows fences (cost 6) but tiles are solid, so when the next arrow is a fence the enemy turns world collision off and walks arrow-to-arrow at `move_speed / tile cost`, then restores collision. Runner = `base_enemy.tscn` + `data/runner.tres` (30 HP, 70 px/s, red). `WaveManager` spawns `wave_size` (20) round-robin over the 8 spawns with scatter, auto-starts, F3 = spawn another wave, emits `wave_cleared`. Old pink EnemyStandIn removed. 82 GUT tests | `ai/steering/steering.gd`, `tests/test_steering.gd`, `entities/enemies/enemy.gd`, `enemy_stats.gd`, `base_enemy.tscn`, `runner.tscn`, `data/runner.tres`, `world/wave_manager.gd`, `world/main.gd/.tscn` |
| 11 | Hand-written steering: `ContextSteering` (replaces `Steering`) = weighted Reynolds behaviours. Enemy Node gathers context (bilinear-sampled flow direction, neighbours' positions/velocities, 3 feeler raycasts on world layer) → `combine(seek·w, separation·w, wall_avoidance·w)` → `smooth_velocity` (dead zone, turn-rate limit at all speeds with **brake-to-turn** cos(angle), acceleration limit). Close to the player (flow cost ≤ `close_in_cost` 1.5) seek = `arrive`. In the crowd zone (flow cost ≤ `crowd_cost` 5) **queuing**: match the pace of a slower ally ahead. Enemies now also collide with each other (mask 5 = world + enemies; climbing still masks 0, restores 5). WaveManager `spawn_seed` for reproducible runs. 97 GUT tests | `ai/steering/context_steering.gd`, `tests/test_context_steering.gd`, `entities/enemies/enemy.gd`, `enemy_stats.gd`, `base_enemy.tscn`, `data/runner.tres`, `world/wave_manager.gd` |
| 12 | Line-of-sight shortcut + pursuit: within `sight_range` (160 px) the Enemy checks a **fat** line of sight (3 parallel rays one body-radius apart, world layer) to the predicted player position `pos + vel × prediction_time` (0.3 s), then to the actual position; if clear, seek goes straight there (`nav_mode` &"sight"), else flow arrows (&"flow"). A clear line also overrides a fence climb. Close-in (&"close") and climbing (&"climb") unchanged; all other steering (separation, queuing, feelers, smoothing) still applies. Pure parts in `ContextSteering` (`predict_position`, `lane_offsets`, `choose_heading`); rays in `enemy.gd` (`_sight_target`, `_clear_path_to`). 100 GUT tests | `ai/steering/context_steering.gd`, `entities/enemies/enemy.gd`, `enemy_stats.gd`, `data/runner.tres`, `tests/test_context_steering.gd` |
| 13 | Attack ring (GDD 6.4): `AttackRing` (pure, ids + positions) owned by `main.gd`, updated each physics frame before enemies. 8 slots at 45° (slot 0 east) at `slot_radius` 28; roles NONE / WAITING / HOLDING / ATTACKING; max 3 attack tokens, rotated every `token_duration` 2.5 s to the holder who waited longest. Enemies engage at flow cost ≤ 7, release at > 9 (hysteresis) or on death. Slots unusable if tile cost > 2 or path cost > 3.5 (walls, fences, behind fences). Holders arrive at their slot, attackers step in to `attack_distance` 12 on their own side, waiters hold on `wait_radius` 60 (stand still if boxed in). Ring roles use the clear-path check, else flow. Queuing only for NONE/WAITING. F4 overlay. Settings in `data/attack_ring.tres`. 113 GUT tests | `ai/steering/attack_ring.gd`, `attack_ring_settings.gd`, `data/attack_ring.tres`, `tests/test_attack_ring.gd`, `ui/debug/attack_ring_overlay.gd`, `entities/enemies/enemy.gd`, `world/main.gd/.tscn`, `world/wave_manager.gd` |
| 14 | Noise + awareness + A* investigation. **No live tracking any more**: each enemy has an `Awareness` (ai/decision, pure): IDLE / INVESTIGATE / SEARCH / CHASE. CHASE only while it perceives the player (within `sense_radius` 32 px always, else grid line of sight within `sight_range` 160); losing sight → INVESTIGATE the last *seen* spot; shots emit `EventBus.noise_emitted(pos, weapon.noise_radius)` (pistol 192 px) → enemies in range INVESTIGATE the shot spot; arrive → SEARCH `search_time` 2 s → IDLE. Flow field + ring only used in CHASE. Investigation goes straight if the fat ray is clear, else A* via `PathQueue` (ai/nav: per-frame budget 2 ms / max 4, exact (start,goal) cache, tail reuse when start lies on a cached path to the same goal). Paths can include fence climbs (climb code now takes a cell list). Vision = `TerrainGrid.has_line_of_sight` (Amanatides–Woo DDA) with `TerrainCosts.blocks_vision` = wall, house (fences don't block; tall grass later with stealth). WaveManager `alert_on_spawn` (default on): new enemies get the player's spawn-time position. `EnemyContext` bundles flow field / ring / path queue / target; `Enemy.setup(context, allies)`, `WaveManager.setup(spawns, context)`. F6 debug overlay. 136 GUT tests | `ai/decision/awareness.gd`, `ai/nav/path_queue.gd`, `ai/grid/terrain_grid.gd`, `terrain_costs.gd`, `entities/enemies/enemy.gd`, `enemy_context.gd`, `enemy_stats.gd`, `entities/player/player.gd`, `entities/projectiles/weapon_stats.gd`, `ui/debug/awareness_overlay.gd`, `world/main.gd/.tscn`, `world/wave_manager.gd`, `tests/test_awareness.gd`, `tests/test_path_queue.gd` |
| 15 | Utility AI (learning mode, explained + pseudocode first): `UtilityAI` scores `ChaseAction` (aggression × (0.5 + 0.5 closeness), needs sight), `FlankAction` (flanking × allies × facing-away × far-enough, needs sight + allies chasing + a FlankPlanner point), `InvestigateAction` (patience × (0.4 + 0.6 freshness), needs an unchecked lead, no sight); idle baseline 0.1; +0.1 momentum for the current action (idle included); an action only competes if its RAW score > idle. Decides at 5 Hz (staggered by golden-ratio phase from instance id) + immediately when awareness state / target_version changes. Inputs in `DecisionInputs` (gathered by `Enemy._gather_inputs`). Genes in `BehaviourWeights` (`data/runner_behaviour.tres`: 0.6/0.6/0.6), shared tuning in `UtilitySettings` (`data/utility_ai.tres`). Enemy executes: CHASE = old chase + ring; FLANK = arrive at flank point (flow field if blocked), no ring, no queuing; INVESTIGATE = A*/straight to lead; IDLE = stand. Investigation also counts as checked when the spot is in view within `investigate_view_distance` 48 px (fixes crowds stuck around a shared last-seen spot). `Awareness.lead_age`, `has_lead()`. F6 overlay shows action letters + flank points. 168 GUT tests | `ai/decision/utility_ai.gd`, `utility_action.gd`, `actions/chase_action.gd`, `actions/flank_action.gd`, `actions/investigate_action.gd`, `decision_inputs.gd`, `behaviour_weights.gd`, `utility_settings.gd`, `flank_planner.gd`, `awareness.gd`, `data/utility_ai.tres`, `data/runner_behaviour.tres`, `entities/enemies/enemy.gd`, `enemy_stats.gd`, `data/runner.tres`, `ui/debug/awareness_overlay.gd`, tests `test_utility_ai.gd`, `test_utility_actions.gd`, `test_flank_planner.gd` |
| 16 | Genome (learning mode, explained + pseudocode first): `Genome` Resource (ai/evolution) with stats speed/health/vision (1–10, budgeted), behaviour aggression/caution/flanking/cohesion/patience (0–1), `path_mode` FLOW/ASTAR/GREEDY. `random()` spends the wave budget exactly (random weights, water-filling over the 10 cap), `copy()`, `mutate(rng, rules, budget, rate)` (Gaussian nudge σ 1.0 stats / 0.1 behaviour, category re-picked to a different value, then repair), `repair()` (clamp, then shrink points above stat_min proportionally to fit the budget), `is_valid`, `to_dict/from_dict` (JSON-safe), `describe()`. Gene → value: base × (1 + (gene − 5) × per_point) with speed 0.10, health 0.15, vision 0.10 per point (`GenomeRules`, `data/genome_rules.tres`; budget 15 +1/wave, cap 24). `Enemy._apply_genome` duplicates `stats` per enemy and sets move_speed / max_health / sight_range / behaviour; body scale follows the health gene (visual only). WaveManager gives each spawned enemy `Genome.random` for the wave budget (`random_genomes`, `wave_number`, logs a per-wave gene summary). Caution, cohesion and path_mode are carried but NOT used by behaviour yet. F7 genome overlay. 191 GUT tests | `ai/evolution/genome.gd`, `genome_rules.gd`, `data/genome_rules.tres`, `ai/decision/behaviour_weights.gd`, `entities/enemies/enemy.gd`, `enemy_context.gd`, `world/wave_manager.gd`, `world/main.gd/.tscn`, `ui/debug/genome_overlay.gd`, `tests/test_genome.gd` |
| 17 | Fitness tracking (learning mode, explained + pseudocode first): `FitnessRecord` = raw facts per enemy (damage_dealt, pressure_seconds within `pressure_radius` 64 px, alive_seconds, objective_score, died, frozen, wave); `Fitness` normalises explicitly (term = clamp(raw / cap, 0, 1); cap 0 for P/S = wave duration) and weights F = 0.4 D + 0.25 P + 0.15 S + 0.2 O (`FitnessSettings`, `data/fitness.tres`). **D is always 0 until Runners can attack** (hook `Enemy.record_damage_dealt`), **O is always 0 until objectives exist** (`FitnessRecord.add_objective`). Enemy ticks its record each physics frame (evaluator distance, not perception) and marks it dead in `_die`. WaveManager owns one {genome, record} per spawn_wave enemy; a wave ends when all its enemies are dead, when the next wave spawns, or F8 → records frozen, scored, sorted, `last_wave_results`, `wave_ended(results)` signal, printed report (genome + D/P/S/O + raw + F). F7 overlay shows live F. 208 GUT tests | `ai/evolution/fitness.gd`, `fitness_record.gd`, `fitness_settings.gd`, `data/fitness.tres`, `entities/enemies/enemy.gd`, `enemy_context.gd`, `world/wave_manager.gd`, `world/main.gd/.tscn`, `ui/debug/genome_overlay.gd`, `tests/test_fitness.gd` |

### Next recommended step
**Genetic Algorithm** (`ai/evolution/genetic_algorithm.gd`, learning mode — user requested it
during step 17): takes `WaveManager.last_wave_results` (genome + fitness), tournament 3, elitism 2,
uniform crossover 0.9, mutation via `Genome.mutate` (10 %), repair, diversity guard on path_mode,
seeded RNG. Then WaveManager spawns the next wave from the evolved population. Runner attack +
player HP still missing (D = 0 for everyone until then).

Fitness measurements (step 17, scratch `fitness_game.gd`, seed 21, 20 Runners, 24 s wave,
11 killed / 9 survived): records equal an independent per-frame shadow count (alive exact,
pressure within 1 frame); F equals the weighted sum exactly; all survivors S = 1; killed
enemies' alive time = their kill time; records don't change after the wave ends; end_wave twice
→ one signal; wave 2 auto-ends when all 6 die, records are wave 2 only. F spread 0.07–0.33
(max possible without D and O is 0.40).

Genome measurements (step 16, scratch `genome_game.gd`, seed 5):
- 20 genome Runners: 0 mismatches between genome-derived and live move_speed / max_health /
  sight_range / brain weights; all genomes valid for budget 15; shared runner.tres unchanged.
- Spread: move_speed 46.9–100.5 px/s, max_health 15.8–49.9 (2–5 pistol hits).
- Open-street race: measured top speed = genome value exactly (100.5 and 46.9 px/s).
- Wave 2 budget 16 respected. Low-patience genomes (< ~0.2) ignore the spawn alert and stay
  idle; low-aggression ones may watch instead of chase — intended gene effects.
- 40 Runners: 0 sharp turns, 0 overlaps, stuck ≤ 15 frames for enemies that are trying to move.
  50 Runners: frame max 7.5 ms.

Utility AI measurements (step 15, scratch `utility_game.gd`, 20 Runners, seed 7):
- Player aiming east: 18 CHASE + 2 FLANK; flankers spent 73 % of their frames on the player's
  back side. Player turns west: all 20 CHASE. Player vanishes: INVESTIGATE last-seen spot →
  SEARCH → IDLE within ~2 s; a shot from hiding 28 tiles away is out of earshot → stay IDLE.
- One Runner's timeline: IDLE → INVESTIGATE (spawn alert) → FLANK 5.6 s → CHASE 6.8 s →
  INVESTIGATE 14.0 s (lost sight) → IDLE 14.25 s. 4–6 action switches per enemy in 25 s
  (125 decisions each) — no flicker.
- 40-Runner steering metric: 0 sharp turns, 0 overlaps, longest stuck (moving roles) ≤ 39
  frames. 50 Runners: frame max ~10 ms, 0 frames > 16.7 ms.
- Bugs found and fixed: flankers queued behind ring waiters (227-frame stall) → flankers skip
  queuing; 8 investigators circled a shared last-seen spot forever → "seen it empty" arrival.

Noise / A* measurements (step 14, scratch `noise_test.gd`, `no_tracking.gd`, `frame_perf.gd`):
- Idle Runner 10.3 tiles away behind a house (no LOS) hears a shot → INVESTIGATE, 12-cell A*
  path planned within 1 frame, followed (astar 79 frames, then straight 24) → sees player → CHASE.
- Shot, then player vanishes far away: Runner goes to the *shot* spot (target drift 0 px), arrives
  2.8 s later, SEARCH 2 s, IDLE; never approaches the hidden player (29.7 tiles away).
- Chasing Runner loses sight: goes to the last *seen* spot, SEARCH, IDLE (drift 0 px).
- Runner out of earshot (28.7 tiles) stays IDLE.
- 50 Runners alerted at once: frame max 8.8–9.1 ms, 0 frames > 16.7 ms, path queue ≤ 6.7 ms in
  one frame (a single long A*), 34 searches + 9–10 tail reuses.
- 40-Runner steering metric: 0–4 sharp turns, 0 overlaps; longest stuck among moving roles
  ≤ 19 frames (waiting for an A* result). Ring *waiters* standing ~5 tiles out are by design.

Attack-ring measurements (step 13, scratch `ring_test.gd`, 24 Runners, seed 4242):
- Open crossroads: 8/8 slots held (3 attack + 5 hold), 16 waiting at 48–76 px, nobody < 10 px
  from the player, holders 2–4 px from their slot, attackers 14–17 px out, every 45° sector occupied.
- Killing the 3 attackers: next frame 3 new attackers, 8 slots refilled from the waiters.
- Player next to a house: 5/8 slots usable, none assigned inside the house.
- Player teleported away: ring empties within 1 s. 0 invariant violations (> 3 attackers, shared
  slot, slot in a wall) over 30 s; 23–27 token hand-overs; 0 sharp turns. 50 Runners p95 4.2 ms.

LOS / pursuit measurements (step 12, scratch `los_scenarios.gd`, `pursuit.gd`):
- Behind a house: flow around it → sight at the corner (cell 33,8) → close; 2 mode switches,
  0 sharp turns, 0 wall-contact frames in sight mode.
- Behind a fence: no LOS → flow → climb → close (climbing still preferred when hidden).
- Player running past in the open (2.5 s): prediction 0 → closest 11.4 px, aims 0.3° ahead
  (trails); 0.3 → closest 2.7 px, aims 9.7° ahead (cuts off); 0.6 overshoots (aim 105° off).
- 40 Runners: still 0 sharp turns / 0 overlaps / stuck ≤ 17 frames; ~50 % of enemy-frames in
  sight mode (player still), ~70 % (player walking). 50 Runners p95 4.57 ms physics.

Steering measurements (step 11, 40 Runners, seeds 12345 & 777, phase A player still 12 s,
phase B player walks a loop 12 s, scratch script `steer_metrics.gd`):
| | baseline (step 10) | final |
|---|---|---|
| turns > 20°/frame | 139 / 202 | 0 / 0 |
| overlapping pairs (< 8 px) | 75 / 91 | 0 / 0 |
| wall-scrape frames / moving frames | 5.7 % / 17.6 % | 3–8 % / 7–8 % |
| longest stuck > 5 tiles from player | 92 frames | ≤ 26 frames |
| avg speed of Runners near a still player (crowd churn) | 6 px/s | 0.0–0.7 px/s |
Things tried and rejected: queuing everywhere (stop-and-go chains, 4 s stalls); turn limit
only above half speed (sharp turns came back); turn limit without brake (units orbit the player).

Perf notes (headless debug build, Maple Hollow): flow field rebuild ~7.5 ms median / 9.5 ms max.
A* spawn→player 2–8 ms per search (measured before the MinHeap speed-up; likely faster now).
GDD allows max 4 A* searches per frame — add a path queue / per-frame budget + caching before
many enemies use A*. Flow rebuilds could move to `WorkerThreadPool` later if they spike (GDD §10.2).
`TerrainGrid.get_neighbors` allocates per call; hot loops should use `build_cost_array` + indices.

## Current controls
WASD move · mouse aim · LMB shoot · Space dodge · F1 terrain-cost overlay · F2 flow-field arrows · F3 spawn a wave · F4 attack-ring overlay · F6 noise / awareness / utility-action overlay · F7 genome + live fitness overlay · F8 end wave and print the fitness report (debug).

## Scene / code map
- `world/main.tscn` (main scene, script `main.gd`): `MapleHollow`, `WaveManager` (enemies are its
  children, `enemy_scene` = runner.tscn), `Player`, `TerrainCostOverlay`, `FlowFieldOverlay`.
  `main.gd` calls `_wave_manager.setup(spawns, flow_field, player)` at the end of `_ready`.
- `Enemy` API: `setup(flow_field, target, allies)`, `take_damage(amount)`, `health`, `is_climbing`,
  signal `died(enemy)`. Stats from `EnemyStats` (archetype, max_health, move_speed, acceleration,
  separation_radius/weight, arrive_radius, climbable_terrains, color).
- `WaveManager` API: `alive: Array[Enemy]`, `spawn_wave(count)`, `spawn_enemy(near)`, signal `wave_cleared`.
- `ContextSteering` (static, + inner class `Weights {seek, separation, wall_avoidance}`):
  `sample_flow(field, world_pos)`, `seek`, `arrive`, `separation(pos, neighbours, radius)`,
  `queue_factor(pos, heading, n_pos, n_vel, look_ahead, lane_width)`, `wall_avoidance(fractions, normals)`,
  `feeler_directions(heading, side_angle)`, `combine(seek_v, sep_push, wall_push, weights, max_speed)`,
  `smooth_velocity(current, desired, accel, delta, dead_zone, max_turn_rate, turn_limit_speed)`.
  Enemy Node does only the raycasts and neighbour gathering.
- `EnemyStats` steering fields: `max_turn_rate_degrees` 360, `turn_limit_min_speed` 0, weights
  `seek_weight` 1.0 / `separation_weight` 1.6 / `wall_avoidance_weight` 1.2, `separation_radius` 14,
  `crowd_cost` 5, `queue_lane_width` 8, `feeler_length` 14, `feeler_angle_degrees` 35,
  `close_in_cost` 1.5, `arrive_radius` 24, `dead_zone_speed` 6, `sight_range` 160, `prediction_time` 0.3,
  `sense_radius` 32, `investigate_arrive_distance` 12, `search_time` 2, `waypoint_radius` 8, `off_path_distance` 40.
- `Enemy` exposes `awareness: Awareness`, `current_target`, `nav_mode` (&"sight" / &"flow" / &"ring" /
  &"close" / &"investigate" / &"astar" / &"wait_path" / &"climb" / &"idle"), `alert(pos)`, `get_debug_path()`.
- `Awareness` API: `state` (IDLE/INVESTIGATE/SEARCH/CHASE), `last_known` (INF = none), `target_version`,
  `see(pos)`, `lose_sight()`, `hear(pos)`, `arrive(search_time)`, `tick(delta)`.
- `PathQueue` API: `PathQueue.new(astar)`, `request(id, start, goal)`, `cancel`, `is_pending`, `has_result`,
  `take_result`, `process()` (main.gd calls it each physics frame), `clear_cache()`, stats
  `searches_run / cache_hits / reuse_hits / last_process_usec`; `budget_usec` 2000, `max_per_frame` 4.
- `TerrainGrid.has_line_of_sight(from_world, to_world)`, `blocks_vision(cell)`.
- `UtilityAI` API: `UtilityAI.new(settings, genes, phase)`, `tick(delta) -> bool`, `request_decision()`,
  `decide(inputs) -> UtilityAction.Type`, `current`, `last_scores`, `switches`.
  `UtilityAction.Type {IDLE, CHASE, FLANK, INVESTIGATE}`; each action: `score(inputs, genes, settings)`.
  `FlankPlanner.choose(player_pos, player_facing, enemy_pos, flow_field, settings)` → point or INF.
  `Enemy.brain: UtilityAI`, `Enemy.flank_point`. `EnemyStats.behaviour` + `.utility_settings`.
  Player facing = `Player.aim_direction` (read via `get("aim_direction")`).
- `Genome` API: `Genome.random(rng, rules, budget)`, `copy()`, `mutate(rng, rules, budget, rate = -1)` →
  genes changed, `repair(rules, budget)`, `is_valid`, `stat_total`, `move_speed/max_health/sight_range(base, rules)`,
  `to_behaviour_weights()`, `to_dict()` / `Genome.from_dict(d)`, `describe()`. Gene name lists
  `Genome.STAT_GENES`, `Genome.BEHAVIOUR_GENES`; `Genome.PathMode`.
- `GenomeRules.budget_for_wave(wave)`. `Enemy.genome`; `Enemy.setup(context, allies, genome)`;
  `EnemyContext.genome_rules`; `WaveManager.wave_number`, `make_genome()`, `spawn_enemy(near, genome, record)`.
- Fitness API: `FitnessRecord.tick(delta, dist, radius)`, `add_damage`, `add_objective`, `mark_dead`, `freeze`,
  `to_dict`; `Fitness.new(settings)`, `components(record, wave_seconds)` → {&"D", &"P", &"S", &"O"},
  `score`, `score_components`, static `normalise(raw, cap)`, `describe`. `EnemyContext.fitness`.
  `Enemy.fitness_record`, `Enemy.record_damage_dealt(amount)`. `WaveManager.end_wave()`,
  `last_wave_results` (each {genome, record, components, fitness, index}, best first), `wave_seconds`,
  `preview_fitness(record)`, `fitness_report(results)`, signal `wave_ended(results)`.
- `AttackRing` API: `AttackRing.new(flow_field, settings)`, `engage(id, pos)`, `disengage(id)`,
  `is_member`, `get_role(id) -> Role {NONE, WAITING, HOLDING, ATTACKING}`, `get_target(id)`,
  `update(player_pos, delta)`, `slot_position/slot_direction/is_slot_valid/get_slot_owner(i)`,
  `get_attacker_count`, `get_member_ids`, `get_member_position`, `center`, `FREE` = 0.
  Enemy ids = `get_instance_id()`. `main.gd` owns `attack_ring`; `WaveManager.setup(..., ring)` passes it on.
- `ContextSteering` also has `predict_position(pos, vel, t)`, `lane_offsets(from, to, half_width)`,
  `choose_heading(flow_dir, in_sight, to_target)`.
  `main.gd` puts the player on the map spawn and sets camera limits to the map rect.
  `main.gd` also exposes `terrain_grid: TerrainGrid` (costs from `data/terrain_costs.tres`)
  and feeds it to the `TerrainCostOverlay` node. It also owns `flow_field: FlowField` (target = player cell,
  rebuilt in `_physics_process` when the player's cell changes; `last_flow_build_msec`) and the `FlowFieldOverlay`.
- `FlowField` API: `build(target, profile)`, `target`, `profile`, `is_built`, `get_cost(cell)` (INF = unreachable),
  `is_reachable`, `get_next_cell` (returns cell itself at target/unreachable), `get_direction(cell)`,
  `get_direction_at(world_pos)`, `get_path_from(cell)`, `last_expanded`.
- `AStar` API: `AStar.new(grid)`, `find_path(start, goal, profile) -> Array[Vector2i]` ([] = none), `last_cost`, `last_expanded`, static `octile(a, b)`.
- `TerrainGrid` API: `from_rows(rows, rules: TerrainCosts, coords: GridCoords = null)`,
  `width/height`, `coords`, `base_profile`, `make_profile(genes, label)`, `in_bounds`,
  `get_terrain`, `set_terrain`, and with optional `profile` arg (null = base):
  `get_cost` (INF = blocked), `is_walkable`, `get_neighbors(cell, allow_diagonal, profile)`,
  `get_step_cost(from, to, profile)`. Diagonals never cut a blocked corner; diagonal ×√2.
- `GridCoords`: `tile_size`, `origin`, `world_to_cell` (floor), `cell_to_world` (cell centre), `cell_rect`.
- `TerrainCostProfile.create(rules, genes: Dictionary[String, float], label)`, `cost_of_id`, `cost_of`.
  Terrain id = index in `TerrainCosts.get_terrain_names()` (sorted); grid asserts profile.source matches.
- Enemies treat fences as walkable cost 6 (climbing); the player is blocked by fence collision.
- `TerrainCostOverlay` has a `profile` property to show another mover's costs.
- `ZoneMap` API: `get_grid_size()`, `get_terrain_at(cell)`, `get_terrain_rows()` (plain data for AI),
  `world_to_cell()`, `cell_to_world()`, `get_world_rect()`, `get_player_spawn()`, `get_enemy_spawns()`.
- Tuning lives in Resources: `PlayerStats` (`data/player_stats.tres`), `WeaponStats` (`data/pistol.tres`).
- Input actions in `project.godot`: `move_left/right/up/down`, `shoot`, `dodge`, `debug_overlay` (F1), `debug_flow_field` (F2), `debug_spawn_wave` (F3), `debug_attack_ring` (F4), `debug_awareness` (F6), `debug_genome` (F7), `debug_end_wave` (F8).
- Physics layers: 1 world, 2 player, 3 enemies, 4 player_bullets, 5 enemy_attacks, 6 barricades.
  Player: layer 2, mask 1. Bullet: layer 4, mask 1+3. Solid tiles: layer 1.

## Map editing
Map was generated once by `tools/build_maple_hollow.gd` (hand-designed rectangles, not procedural).
Either paint in the TileMap editor **or** edit the script and re-run
`godot --headless --path . -s res://tools/build_maple_hollow.gd` — re-running overwrites editor edits.
Spawns are 15–32 tiles from the player; all 1383 walkable cells reachable (checked by the script).

## Environment
- Godot **4.7.2** at `C:\Users\prerit kothari\Downloads\Godot_v4.7.2-stable_win64.exe\` (folder), not on PATH.
  Use `Godot_v4.7.2-stable_win64_console.exe` for headless runs:
  - import: `--headless --path . --import`
  - smoke run: `--headless --path . --quit-after 120`
  - scripted check: `--headless --path . -s <script extending SceneTree>`
  - **run all tests:** `--headless --path . -s res://addons/gut/gut_cmdln.gd` (reads `.gutconfig.json`:
    `res://tests/`, prefix `test_`). In the editor: GUT tab in the bottom panel.
- Commit `*.gd.uid` files. `.godot/` is gitignored.
- GUT 9.7.1 vendored in `addons/gut/` (plugin enabled in `project.godot`).
- Repo: https://github.com/preritkothari16/amortia (branch `main`).
- Commit after each step; push only when the user asks.
- Scratch headless check scripts (movement, map collisions, shooting) live in the session
  scratchpad, not in the repo; rewrite as needed.

## Gotchas learned
- Godot 4.7.2: an `Area2D` with `monitorable = false` did **not** detect bodies in tests. Leave bullets monitorable.
- Headless test scripts: wait 1–2 physics frames after adding a scene before querying physics.
- Use `--fixed-fps 60` for headless simulation tests (runs faster than real time).
- In SceneTree test scripts, read `main.terrain_grid` etc. after the first frame, not in `_initialize()`.
- Bash heredocs with nested quotes broke once; for big multi-file edits write a .py into the scratchpad and run it.
- `-s` SceneTree test scripts: autoloads (EventBus) are registered only after `_initialize()`. Load
  main.tscn on the first frame, and DON'T give variables static types like `Player`/`Enemy`/`WaveManager`
  (that compiles game scripts early → "Identifier not found: EventBus"). Use untyped vars.
- `Performance.TIME_PHYSICS_PROCESS` is coarse/stale headless; measure frame time with
  `Time.get_ticks_usec()` between consecutive frames instead.
- Learning-mode files written on request so far: astar.gd, flow_field.gd, path_queue.gd (ai/nav),
  awareness.gd, utility_ai.gd, utility_action.gd, actions/*.gd, flank_planner.gd, decision_inputs.gd,
  behaviour_weights.gd, utility_settings.gd (ai/decision) — each with explanation + pseudocode first.
- Headless tests can't move the mouse: set `player.aim_direction` directly each frame.
- `queue_free()` is deferred: `is_instance_valid()` stays true until the frame ends — loop on
  `health > 0` instead when counting hits.
- Saving a Genome as .tres rounds the last float digits; compare genes with a tolerance.
- Since genomes, enemy HP is 12–52: old scratch tests that assumed 30 HP (3 hits) needed updating.
- Don't `await` inside a SceneTree script's `_physics_process(delta) -> bool`: it turns into a coroutine and the tree quits.
- Keep enemy colours distinct from terrain (pink enemies vanished against pink houses → Runners are red).
- Hand-written `.tscn` files get `uid=` added by the editor on first open — commit that churn.
- Opening the editor rewrites `project.godot` (sorts sections, adds header comments). When
  editing it by hand, put input actions inside the `[input]` section, not at the end of the file.
- When unzipping GUT, extract the whole archive; a glob pattern skipped subfolders and broke the plugin.

## Open items / deferred
- Turn off / remove `debug_dodge` once the player can take damage.
- Tall grass has no gameplay effect yet (vision hiding, 80% player speed per GDD §4.2).
- Fences block bullets; fence HP (40) comes later.
- Not added yet on purpose: GameState / SaveSystem / AudioDirector autoloads, HUD.
- Terrain cost profiles exist; wiring genes → profiles happens with the genome (GDD §5.3). Adaptation budget (sum ≤ 1.5) is the genome's job, not the grid's.

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

### Next recommended step
**Runner attack + player HP + attack ring** (GDD §6.4, §7.1): player health (100), Runner melee
contact attack with cooldown, respect `is_invulnerable` (then remove `debug_dodge`), attack ring
(8 slots around the player, max 3 attackers, the rest hold/circle a free slot) — this also
replaces today's "everyone crowds the player" end state. Optional before that: line-of-sight
shortcut + pursuit prediction (GDD §6.1 items 3–4). Then utility AI (`ai/decision/`, learning
mode), genome + GA (`ai/evolution/`, learning mode).

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
WASD move · mouse aim · LMB shoot · Space dodge · F1 terrain-cost overlay · F2 flow-field arrows · F3 spawn a wave (debug).

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
  `close_in_cost` 1.5, `arrive_radius` 24, `dead_zone_speed` 6.
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
- Input actions in `project.godot`: `move_left/right/up/down`, `shoot`, `dodge`, `debug_overlay` (F1), `debug_flow_field` (F2), `debug_spawn_wave` (F3).
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

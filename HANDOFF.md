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

### Next recommended step
**Flow field** — `ai/nav/flow_field.gd`: Dijkstra / Uniform Cost Search outward from the
player's cell over `TerrainGrid` (reuse `MinHeap`, `get_neighbors`, `get_step_cost`); each cell
stores the direction to its cheapest neighbour (GDD §6.2). Rebuild when the player changes cell.
Take an optional `TerrainCostProfile`. `ai/nav/` is **learning mode** → explain + pseudocode
first; code only when the user asks. Needs `tests/test_flow_field.gd`. Extend the F1 overlay
to draw arrows. Then: a Runner enemy that follows the field (GDD §11.1 days 5–6), using A*
only for non-player targets (noise, flank points).

Perf notes (headless debug build, Maple Hollow): `get_neighbors` over all 2040 cells ~36 ms;
A* spawn→player 2–8 ms per search (15–173 cells expanded). GDD allows max 4 A* searches per
frame — that could exceed a 16 ms frame, so a path queue / per-frame budget + caching is needed
before many enemies use A*. Inlining the neighbour loop is the first optimisation to try.

## Current controls
WASD move · mouse aim · LMB shoot · Space dodge · F1 terrain-cost overlay (debug).

## Scene / code map
- `world/main.tscn` (main scene, script `main.gd`): instances `MapleHollow`, `EnemyStandIn`
  (pink StaticBody2D on layer 3, no script — temporary target, replace with real enemies), `Player`.
  `main.gd` puts the player on the map spawn and sets camera limits to the map rect.
  `main.gd` also exposes `terrain_grid: TerrainGrid` (costs from `data/terrain_costs.tres`)
  and feeds it to the `TerrainCostOverlay` node.
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
- Input actions in `project.godot`: `move_left/right/up/down`, `shoot`, `dodge`.
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

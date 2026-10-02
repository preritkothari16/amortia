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

### Next recommended step
**Terrain-cost grid** — `ai/grid/terrain_grid.gd` (RefCounted, no Node deps) built from
`ZoneMap.get_terrain_rows()` + a cost table in `data/` (costs from GDD §4.2: road/grass 1,
tall_grass 2, fence 6 for enemies, wall/house impassable), plus `tests/test_terrain_grid.gd`.
`ai/grid/` is not in learning mode → full implementation OK.
After that: flow field (`ai/nav/` = learning mode → explain + pseudocode first, code only on request).

## Current controls
WASD move · mouse aim · LMB shoot · Space dodge.

## Scene / code map
- `world/main.tscn` (main scene, script `main.gd`): instances `MapleHollow`, `EnemyStandIn`
  (pink StaticBody2D on layer 3, no script — temporary target, replace with real enemies), `Player`.
  `main.gd` puts the player on the map spawn and sets camera limits to the map rect.
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
- Commit `*.gd.uid` files. `.godot/` is gitignored.
- GUT is **not installed yet** — add it when the first `ai/` file + test is written.
- Repo: https://github.com/preritkothari16/amortia (branch `main`).

## Gotchas learned
- Godot 4.7.2: an `Area2D` with `monitorable = false` did **not** detect bodies in tests. Leave bullets monitorable.
- Headless test scripts: wait 1–2 physics frames after adding a scene before querying physics.
- Hand-written `.tscn` files get `uid=` added by the editor on first open — commit that churn.

## Open items / deferred
- Turn off / remove `debug_dodge` once the player can take damage.
- Tall grass has no gameplay effect yet (vision hiding, 80% player speed per GDD §4.2).
- Fences block bullets; fence HP (40) comes later.
- Not added yet on purpose: GameState / SaveSystem / AudioDirector autoloads, HUD, GUT.

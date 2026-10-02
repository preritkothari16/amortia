# Amortia — project guide for Claude Code

## What this is
Amortia is a top-down 2D pixel-art shooter in **Godot 4 (GDScript)**, built solo.
Enemies ("the Bloomed") evolve between waves with a **Genetic Algorithm**, move using a
**shared flow field + steering**, and decide with a small **utility AI**.
It is also an AI course project (702CO0C076), so the AI algorithms must be hand-written and explainable.

The full design doc and step-by-step Build Plan live in the claude.ai doc "Amortia — Game Design Document (v2)".
Current phase: **Phase 1 — Prototype (greybox)**. Work one Build Plan step at a time.

**Session handoff:** read `HANDOFF.md` at the start of every session. Update it at the end of
every prompt that changes the project (what was done, next step, gotchas), and commit it with the work.

## Hard rules
- **Godot 4 only.** Use Godot 4 APIs (CharacterBody2D, TileMapLayer, `@export`, typed signals). Never Godot 3 syntax.
- **Typed GDScript everywhere** (`var speed: float = 4.0`, typed function args and returns).
- **No built-in navigation for gameplay AI.** Do not use NavigationServer2D, NavigationAgent2D or AStarGrid2D
  for enemy pathing. A*, flow field, BFS, Greedy, GA, hill climbing, K-means and the CSP solver are hand-written.
  (Built-in navigation may only be used later as a comparison baseline in experiments.)
- **AI code has no Node dependencies.** Everything in `res://ai/` extends `RefCounted` or `Resource`
  and takes plain data (Vector2, Vector2i, arrays), so it can be unit-tested and run headless.
- **Tuning numbers live in data** (`res://data/*.tres`), not hard-coded.
- **Player damage is ranged only.** No melee attacks for the player, ever.
- **Greybox until Phase 3.** Use Polygon2D / ColorRect placeholders, no art work.
- Keep changes small and scoped to the current step. Don't refactor unrelated files.
- Commit-friendly: after a step passes its "Done when" test, summarise what changed so I can commit.

## Learning mode (graded AI code)
For files in `res://ai/nav/`, `res://ai/evolution/`, `res://ai/decision/`, `res://ai/learning/`, `res://ai/levelgen/`:
explain the approach and give pseudocode first; write the full implementation only when I ask for it,
and comment it well enough that I can explain every line in a viva.
(Delete this section if I want full implementations by default.)

## Folder structure
```
res://
├── autoload/      # GameState, EventBus, SaveSystem, AudioDirector
├── ai/            # pure logic: grid/, nav/, steering/, decision/, evolution/, learning/, levelgen/, bot/, util/
├── entities/      # player/, enemies/, projectiles/, barricade/, pickups/
├── world/         # tilesets/, zones/<zone>/, wave_manager.gd
├── ui/            # hud/, menus/, debug/
├── data/          # .tres resources: config, skills, genomes, archetypes
├── tools/         # headless experiment runner, CSV logger
└── tests/         # GUT unit tests (test_*.gd)
```

## Conventions
- Files and folders: `snake_case`. Classes: `class_name PascalCase`. Constants: `UPPER_SNAKE`.
- Signals go through `EventBus` when more than one system cares (e.g. `noise_emitted(pos: Vector2, radius: float)`).
- Viewport 480 × 270, scaled to 1080p; tiles are 16 px; texture filter Nearest.
- Physics layers: 1 world, 2 player, 3 enemies, 4 player_bullets, 5 enemy_attacks, 6 barricades.
- Every new file in `ai/` gets a matching GUT test in `tests/`.

## Useful commands
- Run the game: use the Godot MCP run tool, or `godot --path .`
- Headless experiment (from Build Plan step 14): `godot --headless --path . -- --experiment ga_vs_random --generations 30`
- Run tests: run GUT from the editor panel, or its command-line runner (check the GUT docs for the exact command for your installed version).

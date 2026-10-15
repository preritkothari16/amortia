# Amortia — full project audit (2026-10-15)

Scope: the original prototype plus expansion Phases 1–8 (HANDOFF steps 1–42). No features added; confirmed
bugs fixed with minimal changes (see `BUG_FIXES.md`); what is left is in `REMAINING_ISSUES.md`.

**Method.** Read `CLAUDE.md`, `HANDOFF.md`, `EXPANSION_PLAN.md`, the GDD and the core source (main, WaveManager,
LevelFlow, GameState, objectives, events, save code, GA, enemy shell). `EVENING_SUMMARY.md` no longer exists
(removed in commit `a8f13b1`; its open decisions live in HANDOFF "Open items"). Then ran the suite, wrote
scratch harnesses (not committed — they live in the session scratchpad) and compared behaviour with the GDD.

**Baseline.** `main`, 3 uncommitted editor-churn files left untouched (`data/terrain_costs.tres`,
`world/main.tscn`, `world/tilesets/greybox_tileset.tres`: Godot added `uid=` headers, and two `= null` lines in
`terrain_costs.tres`). GUT: **461 / 461 pass** (31 scripts, 69.6 s headless).
**Final.** GUT: **473 / 473 pass** (32 scripts, +12 regression tests).

## Verification legend
- **A** = automated and repeatable (GUT test or a deterministic headless script).
- **S** = scripted run, results read by me, not a committed test.
- **M** = needs a human at the keyboard (see `REMAINING_ISSUES.md`).

## System by system

| System | State | Evidence |
|---|---|---|
| Player: movement, dodge, shooting, HP, death / revive, XP, 6-node skill tree | Works | A (`test_player_*`, `test_melee_attack`), S (bots in 12 levels: no errors, player stays in bounds). Feel = M |
| Combat: attack ring (3 tokens), melee, attribution of damage to fitness D | Works | A (`test_attack_ring`, `test_melee_attack`) |
| Collisions: world, water layer 7, fences climbed by enemies | Works | A (`test_terrain_definition`); S: fence-climb trace = 69 climb frames, identical to step 32 |
| Flow field, hand-written A*, steering, path queue | Works | A (flow = A* = brute-force Dijkstra on random grids, incl. all 17 terrains) |
| Utility AI, awareness, perception (fog, night, concealment, hearing) | Works | A (`test_utility_*`, `test_awareness`, `test_perception`) |
| Terrain table vs GDD 4.2 | Matches (all 15 GDD rows + tree, ash, door_open, living_wall, gate) | S: printed every definition and compared with the GDD table |
| Terrain events: fire, tide, bridge, fog, day/night, living walls | Work, warn first, never trap | A (`test_terrain_events`). S: tide + walls run for 600 s on every area: entry → exit stays connected (295 seeded wall runs, 0 cuts) |
| GA: tournament, uniform crossover, elitism, diversity guard, exact stat budget, adaptation budget | Works, deterministic | A (33 GA tests, 50 harsh generations valid). S: two parallel seeded 20-s runs hash-identical (`3299913234` both) |
| Fitness F = 0.4 D + 0.25 P + 0.15 S + 0.2 O | Works, weights unchanged | A (`test_fitness`) |
| Waves: arrival delay, behind spawns, stragglers (unscored), exits, reports, retry | Works | A (`test_area_flow`). S: stragglers appear 15 s after a clear (4 spawned by 30 s), unscored |
| Objectives: Survive, Hold, Escort, Purge, Extract, Stealth, Apex | All 7 complete a level when played right | A (`test_objectives`). S: full campaign driven through each objective's real goal |
| Objective placement | Reachable | S: all 26 placed objects (supplies, hold points, nests, escort routes) across every level wave are reachable or shootable (0 bad) |
| CSP generator | Works to spec (MRV, forward checking, ≤ 2 chokepoints, ≥ 1 hazard, BFS reachability, spawns ≥ 15 tiles, seeded) | A (`test_csp_level_generator`). S: 36 areas (every level, every wave plus one extra index) build; entry → exit walkable, spawns on walkable connected ground, 0 problems; build avg 10.6 ms, max 12.7 ms |
| Campaign: 16 levels, Apex per zone, zone carry-over, XP between levels | Works | S: z1_l1 → z4_l4 → victory in one run (13 145 frames); `to_dict` → JSON → `from_dict` round trip at every Safehouse |
| Safehouse, Endless, New Game+ | Work after fixes (3 bugs) | A (`test_audit_regressions`), S |
| Saves (prototype + campaign) | Work after fixes (2 crashes on damaged files) | A, plus a 9 000-case mutation fuzz of `SaveGame.validate`, `GameState.from_dict`, `Genome.from_dict` |
| UI: menus, HUD, Wave Report, Downed, Safehouse, Test Scenarios | Fine after 1 layout fix | S: windowed screenshots at 960×540 and 1280×720 |
| Performance | No problem found | S: see below |
| Resources | All 165 `.gd/.tres/.tscn` load, 0 errors | S |
| Memory / leaks | Flat | S: object count 2330 → 2437 over 16 level loads, nodes 184–196, 0 orphans |

### Performance (headless, `--fixed-fps 60`, bot player, bot cost subtracted)
Before and after the fixes are the same: none of the fixes touch a per-frame path.

| Run | p50 | p95 | p99 | worst |
|---|---|---|---|---|
| z2_l1 Extract, 20 Runners, tide | 1.6 ms | 10.9 ms | 12.7 ms | 136 ms |
| z4_l1 Extract, living walls | 5.3 ms | 10.5 ms | 11.9 ms | 108 ms |
Spikes are single frames: area load on Retry / next wave (~90–110 ms: generate + instantiate + TileMap + flow
rebuild) and the 20-enemy spawn (~48 ms). Headless timing on this laptop is unreliable (E-cores, see HANDOFF);
windowed 50-enemy numbers from step 26 (p99 6.9 ms) were not re-measured.

## Broken (all fixed — details in BUG_FIXES.md)
1. New Game+ / a second run hid **Continue Campaign** forever.
2. Quitting at the Safehouse and pressing Continue **replayed the Apex boss**.
3. Endless **best wave was never saved**.
4. A save with an unreadable terrain gene **crashed** `SaveGame.validate`.
5. A hand-damaged `campaign.json` **crashed** `GameState.from_dict`.
6. The Safehouse "strongest strain" line was **556 px wide in a 480 px viewport** (clipped both sides).

## Incomplete (by design or not yet built — see REMAINING_ISSUES.md)
Genes `caution`, `cohesion`, `path_mode` have no behaviour; Runner is the only archetype; one weapon; no research /
Lab, bestiary, audio; Safehouse rooms disabled; zones 2–4 reuse Maple Hollow chunks (no bridges, so BridgeCollapse never
fires); no K-means profiling, hill-climbing baseline or in-repo experiment runner (GDD 5.5, 5.6, 6.6, 10.3).

## Not verified
Anything that needs a human: game feel, difficulty, whether the enemies are fun to fight, readability of the HUD
during a real fight, windowed frame time with 50 enemies in zones 2–4, gamepad (none exists), audio (none exists).
My bot is crude (shoots the nearest visible Runner, BFS path); it can't judge balance.

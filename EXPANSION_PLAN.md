# Amortia — terrain / evolution / objectives / campaign expansion plan

Audit and roadmap for the "Terrain, Evolution, Objectives & Campaign Expansion" spec (2026-10-13).
Phase 1 is implemented (HANDOFF step 32). **Phases 2–8 need an explicit prompt each.**
Learning mode still applies: files in `ai/nav`, `ai/evolution`, `ai/decision`, `ai/learning`,
`ai/levelgen` get an explanation + pseudocode first, code only on request.

## 1. Requirement matrix

Status before Phase 1 → after. I = implemented and tested, P = partial, M = missing,
C = conflicts with existing code, D = needs a design decision.

| # | Requirement | Before | After P1 | Files | Phase |
|---|---|---|---|---|---|
| A1 | Central data-driven terrain definition | P (`TerrainCosts`: cost, impassable, adaptations, vision block only) | I | `ai/grid/terrain_definition.gd`, `terrain_costs.gd`, `data/terrain_costs.tres` | 1 |
| A2 | Enemy cost column (15 rows) | I (no `tree`) | I (+ tree) | same | 1 |
| A3 | Player speed / traversability | M (collision only) | I (speed multiplier used by `Player.walk_speed`) | `player.gd`, `terrain_grid.gd` | 1 |
| A4 | Vision column | P (wall/house block) | I as data (BLOCKS compiled; CONCEALS/REDUCES/PARTIAL stored) | definitions | 1 data / 3 behaviour |
| A5 | Noise category | M | I as data | definitions | 1 data / 3 |
| A6 | Destructibility + HP, burnable, collapse | M | I as data | definitions | 1 data / 4 |
| A7 | Hazards (toxic, fire DoT) | M | data only; damage value not designed (D) | definitions | 4 |
| A8 | Allowed zones, visual identity | M | I (zones, colour, pattern; tileset generated from data) | definitions, `tools/build_maple_hollow.gd`, tileset | 1 |
| A9 | Collision ⇔ navigation agreement | C (fence climb list in `EnemyStats.climbable_terrains`, a 2nd rulebook) | I (traversal mechanic per terrain, consistency tests; water layer 7) | `enemy.gd`, `wave_manager.gd`, scenes | 1 |
| A10 | Door open / closed / destroyed states | M | M (door = closed door) | — | 4 |
| A11 | Fog / fire as overlays over the base tile | M | data flag `is_overlay`; second grid layer pending | — | 4 |
| B1 | 5 terrain genes in Genome | M | M | `ai/evolution/genome.gd` (graded) | 2 |
| B2 | Separate adaptation budget, repair, mutation, crossover | M (D: defaults) | M | genome, `genome_rules.gd`, GA | 2 |
| B3 | Cost profiles from genes, unlock threshold | I (`TerrainCostProfile`, tested) | I | `terrain_cost_profile.gd` | — |
| B4 | Enemy navigation uses its own profile | M (shared base flow field) | M | `main.gd`, flow field cache, `enemy.gd`, `path_queue.gd` | 2 |
| B5 | A* ≡ flow field for equal profiles | I (random-grid tests) | I (+ test on all data terrains and adapted profiles) | tests | — |
| B6 | Old saves / genomes without new genes | n/a | n/a | `save_game.gd`, `Genome.from_dict` | 2 |
| B7 | Debug inspection of adaptive costs | P (F1 overlay has a `profile` property) | P | overlays | 2 |
| C1 | LOS raycast, walls block | I (grid DDA) | I (+ trees, doors, vents, barricades block) | `terrain_grid.gd` | — |
| C2 | Tall-grass concealment, fog −50 %, night −40 % | M | M | `awareness.gd` (graded), `enemy.gd` | 3 |
| C3 | Noise events as last-known position only | I for shots (`EventBus.noise_emitted`, strength) | I | `awareness.gd` | — |
| C4 | Running / splash / climb / break noises | M | M (noise levels are data now) | player, enemy | 3 |
| C5 | Stealth beyond 2 tiles | P (`sense_radius` 32 px = 2 tiles always notices) | P | `enemy_stats.gd` | 3 |
| D1–D6 | Fire, bridge collapse, tide, fog banks, day/night, living walls | M (`TerrainGrid.set_terrain` exists) | M | new `world/events/`, grid versioning | 4 |
| E1 | Wave loop, report, Game Over → retry same wave | I | I | `wave_manager.gd`, UI | — |
| E2 | Left entry / right exit, 3 s start, stragglers, variants, enemies from behind | M | M | WaveManager, ZoneMap | 5 |
| E3 | Barricade building | M | M | entities/barricade | 5 |
| F1 | Objective framework + 7 types | M (`FitnessRecord.add_objective` hook only) | M | `world/objectives/` | 6 |
| G1 | CSP chunk generator (MRV, FC, BFS) | M (`ai/levelgen/` empty) | M | `ai/levelgen/` (graded) | 7 |
| H1 | 4 zones × 3 levels + Apex, Safehouse, NG+, Endless | M (single save slot v1) | M | autoload GameState, SaveSystem v2 | 8 |

## 2. Conflicts and resolutions

1. **One rulebook vs different player/enemy rules.** One `TerrainDefinition` per terrain holds
   both the enemy columns (path cost, traversal mechanic, adaptations) and the player columns
   (passable, speed). "Same rules" = same data source, not identical numbers. *Open (D):* enemies
   are not slowed by mud/tall grass today (cost only steers routes); decide in Phase 2/3 whether
   enemy speed should scale too.
2. **Genes lower costs vs genes unlock tiles.** Keep the tested contract: passable terrain →
   `lerp(base, adapted, gene)`; impassable → `adapted` once gene ≥ `unlock_threshold` (0.5). A gene
   can only affect terrain whose definition lists it — that list *is* the rule.
3. **Shared flow field vs per-enemy profiles.** Phase 2: profile key = quantised genes (e.g.
   unlocked yes/no + cost rounded to 0.5); one flow field per key in use, built lazily, same rebuild
   trigger (player cell change). A* (`path_mode` ASTAR/investigations) passes the enemy's own profile;
   the PathQueue cache key must include the profile. Attack ring keeps the base field (slot validity
   is about the player's surroundings).
4. **Dynamic terrain vs cached paths.** Phase 4: `TerrainGrid.version` + changed-cells signal;
   PathQueue drops cache entries that touch changed cells; flow fields rebuild when a changed cell is
   reachable in them. Correctness first, local repair later.
5. **Vision blocking vs concealment.** Separate enum values: BLOCKS stops every line through the
   cell; CONCEALS only hides a unit standing *in* it (beyond the 2-tile sense radius) and never blocks
   lines; REDUCES scales range; PARTIAL (smoke) amount undecided.
6. **Wave clear/report timing vs manual right exit.** Phase 5: keep scoring + breeding at the clear
   (as now); show the report at the exit. *D:* a death in the post-clear risk period — recommend
   "the cleared wave stays cleared, you retry from the next wave's start".
7. **GA evaluation vs rearranged variants.** Selection is rank-based within one wave, so a layout
   change between waves doesn't bias selection. Experiments keep a fixed map + seed; mean F is only
   compared within one map.
8. **45 s survival cap vs 6–12 min levels.** S is per wave, not per level: keep the fixed 45 s cap
   per wave (data). Level length comes from wave count.
9. **Save v1 vs campaign schema.** Save v2 adds a `campaign` section (zone, level, per-zone
   population); `SaveGame.validate` migrates v1 → v2 as "prototype mode, zone 1".
10. **Death/retry vs objective failure.** Escort death / point lost use the same `fail_wave()`
    path (retry same wave, no breeding). *D:* GDD 7.2 says death restarts the *level*; the user's
    newer decision (retry the wave, step 31) wins until the user says otherwise.
11. **"3 levels + boss" vs "Apex after the last wave".** GDD 3/8: Apex is its own 4th level per
    zone (16 levels). After level 3's last wave → Apex level → Safehouse.
12. **Adaptation budget and thresholds (D, Phase 2).** Proposal: `GenomeRules.adaptation_budget`
    1.5 (GDD 5.3); random init spends a random amount 0…budget with random weights; repair = clamp
    0..1, then scale down proportionally if over budget (no top-up — adaptations are optional, unlike
    stat points); mutation σ 0.1 like behaviour genes. All configurable. With threshold 0.5 a genome can
    unlock at most 3 impassable terrains.
13. **Night sense.** Proposal: night vision = range × (1 − 0.4 × (1 − night_sense)); night hearing
    radius × (1 + k × night_sense) at night only. Only ranges scale; LOS and noise events are still
    required, so no omniscience.
14. **Barricade / door cost.** Before: planning cost includes the interaction (barricade 5 =
    break through, door 2 = open). After: barricade → the tile under it, door → open-door terrain
    (or floor when destroyed). Phase 4 with HP state.
15. **Populations across levels/zones.** One persistent population per zone (current WaveManager
    population + GA RNG state), saved in the campaign save; new zone = 20 % best of the old zone +
    80 % random (GDD 3).

## 3. Roadmap

| Phase | Content | Depends on |
|---|---|---|
| 1 ✅ | Terrain foundation (this step) | — |
| 2 | Terrain genes, adaptation budget, per-profile flow fields/A*, save migration for genomes, debug | 1 |
| 3 | Vision (concealment, fog, night factors), noise sources (running, splash, climb), stealth | 1 (data), 2 for night sense |
| 4 | Dynamic terrain: grid versioning + invalidation first, then fire, bridge, tide, fog banks, day/night, living walls; door/barricade states | 1, 3 (fog/night vision) |
| 5 | Wave-to-wave areas: entry/exit, stragglers, 3 hand-made variants, barricade building | 1, (4 for barricade HP) |
| 6 | Objective framework + 7 objectives, O term attribution | 5 |
| 7 | CSP chunk generator | 1 (reachability per profile), 5 (entry/exit), 6 (objective placement) |
| 8 | Campaign, Apex, Safehouse, save v2, post-game | 5–7 |

Order change vs the spec: none. Note: the night-sense gene (Phase 2) has no effect until night
exists (Phase 3/4) — it is carried like `caution`/`cohesion` today.

## 4. Pending design numbers (not invented)
Hazard damage per second (toxic pool, fire), fire smoke vision amount, sound radii per noise
level, bridge crossings before collapse, adaptation budget defaults (proposal above), whether
enemies are slowed by terrain, door open/closed rules for the player.

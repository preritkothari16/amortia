# Amortia — Game Design Document (v2)

Sep 25, 2026 · @Prerit Kothari

## 1. Overview

Amortia is a solo-built, top-down 2D action game in Godot where every enemy population evolves against the player through a Genetic Algorithm, wrapped in a campaign of 4 zones, a skill tree, a safehouse and a hidden storyline. The greybox prototype is due in 2 weeks; the full game is a long-term project.

**Pitch:** They learn from every bullet. Evolve faster.

### Design pillars

Every feature must support at least one pillar, or it waits.

1. **Visible evolution** — the player can see, read and feel the enemies adapting (art, bestiary, wave reports).
2. **Arms race** — the player evolves too (skill tree, weapons, research); every choice shapes what the enemies become.
3. **Cute surface, dark core** — friendly edutainment look on top, unsettling science horror underneath (Endacopia-inspired).
4. **Smart, smooth enemies** — enemies move fluidly and make quick, readable decisions.

### Syllabus coverage (AI course 702CO0C076)

| Unit | Topic | Where in the game | Status |
| --- | --- | --- | --- |
| 1 | Agents, PEAS, environments | Every enemy is a utility-based agent | Core |
| 2 | BFS, UCS, A\*, Greedy | Flow fields (UCS/Dijkstra), hand-written A\*, Greedy comparison | Core |
| 2 | Genetic Algorithm | Enemy genome evolution, incl. behaviour weights | Core |
| 2 | Hill climbing | Baseline vs. GA experiment | Core |
| 4 | CSP, backtracking | Level-layout generator with placement constraints | Planned |
| 5 | K-means | Player playstyle profiling | Planned |
| 6 | Expert system | Optional: rule-based in-game field guide / advisor | Optional |

The graded algorithms (A\*, flow fields, GA, hill climbing, K-means, CSP solver) are written by hand. Godot's built-in navigation may be used only as a comparison baseline.

## 2. Story (design reference only)

The story guides art, zones, bosses and enemy design, but it is **not a player-facing feature in the prototype** — it gets finalised after the AI project is submitted.

- **Setting:** Sunnyseed Valley, a cheerful company town built around Sunnyseed Labs (slogan "Grow Better, Together!", mascot Sprouty, a smiling seed that is also the lab's PA voice).
- **The Bloom:** an organism engineered to evolve under pressure. It turns people and animals into "the Bloomed", all linked to one core colony — **the Seed** — under the lab.
- **The Pulse:** the Seed updates its creatures in pulses → the in-world reason enemies come in waves and change between them (the GA).
- **Player:** Pip, a delivery courier fighting with ranged weapons only.
- **Goal:** cross 4 zones, reach the lab, destroy the Seed.
- **Twist:** Sunnyseed released the Bloom on purpose as an evolution experiment — and Pip unknowingly delivered the Seed. The Seed has been evolving against Pip specifically.
- **People:** Dr. Marigold Hale (founder, absorbed into the Seed), Gus (Safehouse owner), Nell (researcher, runs research), bosses who were townspeople (the mailman, the lifeguard, the park ranger).
- **World rules:** science horror only (no magic); fire kills the Bloom, cold slows it; it evolves only at Pulses; the story never leaves the valley.
- **Tone:** bright, toy-like surface; creeping body horror underneath; dry humour.

## 3. Zones (final)

Four zones, played in order, each with its own terrain, dominant pressures and Apex boss; each zone rewards different genes, so the same GA produces different creatures in each.

| # | Zone | Look and feel | Terrain focus | Genes the terrain rewards | Apex boss |
| --- | --- | --- | --- | --- | --- |
| 1 | **Maple Hollow** (suburbs) | Pastel houses, picket fences, lawn ornaments, mascot billboards | Open streets, fences, gardens, cars | Speed, swarming, climbing (fences) | **The Mailman** — fast, leaps fences, calls the swarm |
| 2 | **Lowtide** (flooded district) | Half-sunk shops, neon signs flickering in water, rain | Shallow/deep water, bridges, rooftops | Swimmer, bulk (health) | **Big Bather** — submerges, resurfaces anywhere |
| 3 | **Greywood** (forest) | Theme-park forest trail gone wild, fog, fireflies | Dense trees, tall grass, fog, darkness | Vision, flanking, stealth | **The Ranger** — hunts by sound, ambushes from cover |
| 4 | **Sunnyseed Labs / The Root** (lab → hive) | Clean white lab that turns organic and pulsing deeper in | Corridors, vents, doors, toxic pools, living walls | Crawling (vents), toxin resistance, ambush | **The Seed** — final boss, uses the best genes of the whole run |

### Zone rules

- Each zone = 3 levels + 1 Apex boss level.
- **The enemy population carries over between levels in a zone** — they keep evolving.
- **New zone = new population**, seeded with 20% of the previous zone's best genomes + 80% random. Evolution partly resets, but the run's history leaks forward.
- Zone order is fixed for story; level layouts inside each zone are generated (Section 4.6).
- Between zones the player returns to the **Safehouse** hub (Section 7).

## 4. Terrain rules and characteristics

Terrain is data, not decoration: every tile type has movement, vision, sound and destructibility values, and the same rules apply to player and enemies — only genes change how much a rule hurts an enemy.

### 4.1 Global rules

1. **One rulebook for everyone.** The player and enemies read the same tile properties.
2. **Genes modify costs, never rules.** A swimmer still enters water; it just pays less.
3. **Terrain feeds pathfinding directly.** Every movement cost is also the edge cost in A\* and the flow field — so enemies "understand" terrain automatically.
4. **Readable at a glance.** Every terrain type has a distinct colour and texture; hazards always have a warning tell.
5. **Change is telegraphed.** Collapses, fire spread and floods show 1–2 s of warning.

### 4.2 Tile types

| Tile | Move cost (enemy path) | Player speed | Blocks vision | Noise | Destructible | Zones |
| --- | --- | --- | --- | --- | --- | --- |
| Road / floor | 1 | 100% | No | Normal | No | All |
| Grass | 1 | 100% | No | Quiet | No | 1, 3 |
| Mud | 3 | 60% | No | Loud | No | 2, 3 |
| Shallow water | 3 (swimmer: 1) | 60% | No | Loud (splash) | No | 2 |
| Deep water | Impassable (swimmer: 2) | Impassable | No | — | No | 2 |
| Tall grass / bushes | 2 | 80% | **Yes (hides units inside)** | Quiet | Burnable | 1, 3 |
| Fence | 6 (climber: 2) | Impassable | No | Loud (climb) | Yes, 40 HP | 1 |
| Tree / wall | Impassable | Impassable | Yes | — | No | All |
| Barricade (player-built) | 5 (break through) | Impassable | Yes | — | Yes, 50 HP | All |
| Door | 2 | 100% | When closed | Loud | Yes, 60 HP | 4 |
| Vent | Crawlers only: 1 | Impassable | Yes | Quiet | No | 4 |
| Bridge | 1 | 100% | No | Normal | **Collapses** after X crossings / explosion | 2 |
| Fog | 1 | 100% | Vision −50% | Normal | No | 3 |
| Toxic pool | 8 (resistant: 2) | Damage over time | No | Normal | No | 4 |
| Fire | 20 (avoid) | Damage over time | Partial (smoke) | Loud | Spreads to grass | All (from player weapons) |

### 4.3 Vision and sound

- **Line of sight** by raycast; blocked by vision-blocking tiles. Vision radius comes from the Vision gene, reduced by fog and night.
- **Noise events** (shots, running, splashes, broken fences) emit a radius; enemies inside it get the player's position as a *last known location*, not live tracking.
- Player can stealth: walking + tall grass + no shooting = invisible beyond 2 tiles.

### 4.4 Dynamic terrain events

| Event | Zone | Effect | Why it matters for AI |
| --- | --- | --- | --- |
| Fire spread | All (from player) | Grass and bushes burn, then become ash (cost 1) | Paths must update live; flow field rebuilds locally |
| Bridge collapse | 2 | Bridge → deep water | Cuts routes; swimmers gain advantage |
| Rising tide | 2 | Shallow → deep on a timer | Map shrinks mid-level |
| Fog banks | 3 | Moving fog zones | Vision-heavy genomes weaken |
| Day / night | 1, 3 | Night: −40% vision for all, enemies get +sense of sound | Rewards hearing-based behaviour |
| Living walls | 4 | Walls slowly grow, closing corridors | Forces repathing and new routes |

### 4.5 Terrain genes

Added to the genome (Section 5) with their own **adaptation budget** (separate from stat budget): **Swimmer**, **Climber**, **Crawler** (vents), **Toxin resistance**, **Night sense**. Each is 0–1 and lowers the cost of one terrain type. Which ones get selected depends on the zone — that is the visible evolution.

### 4.6 Level generation (CSP, Unit 4)

- Each level is assembled from hand-made **room chunks** (e.g. 16 × 16 tiles) per zone.
- A backtracking CSP solver places chunks with constraints: exits connect, objective is reachable from player spawn (BFS), enemy spawns ≥ 15 tiles from player spawn, max 2 chokepoints in a row, at least one hazard per level.
- Uses MRV and forward checking; fixed seed per level so playthroughs are reproducible for experiments.

## 5. Enemies and evolution

Five archetypes share one genome format with three gene groups — stats, terrain adaptations and behaviour weights — so the GA evolves how enemies think, not just how strong they are.

### 5.1 Archetypes ("the Bloomed")

| Archetype | Role | Base trait | First appears | Prototype? |
| --- | --- | --- | --- | --- |
| **Runner** | Fast melee swarmer | High base speed | Zone 1 | Yes |
| **Brute** | Tank, breaks barricades | 2× barricade damage | Zone 1, level 2 | No |
| **Spitter** | Ranged, keeps distance | Lobbed toxic projectile | Zone 2 | No |
| **Screamer** | Support, alerts and buffs nearby | Scream = noise event + 15% speed buff | Zone 3 | No |
| **Crawler** | Ambusher, uses vents | Only archetype that path through vents | Zone 4 | No |

Evolution happens **within** each archetype: Runners breed with Runners. The archetype mix per wave is fixed by level design.

### 5.2 Every enemy as an agent (Unit 1)

| PEAS | Bloomed creature |
| --- | --- |
| Performance | Damage dealt, pressure on player (closeness), survival time, objective disruption |
| Environment | Terrain grid, player, other enemies, noise events, barricades |
| Actuators | Move (steering), attack, break obstacle, scream / spit (archetype) |
| Sensors | Line of sight within vision radius, noise events, nearby allies |

Environment: partially observable, multi-agent, dynamic, stochastic, sequential. Agent type: **utility-based** (Section 6.5).

### 5.3 Genome

| Group | Gene | Range | Effect |
| --- | --- | --- | --- |
| Stats (budgeted) | Speed, Health, Vision | 1–10 each | Base values × archetype multiplier |
| Terrain (adaptation budget) | Swimmer, Climber, Crawler, Toxin res., Night sense | 0–1 each | Lower the cost of one terrain type (Section 4.5) |
| Behaviour weights | Aggression, Caution, Flanking, Cohesion, Patience | 0–1 each | Weights in the utility AI (Section 6.5) |
| Strategy | Path mode | Flow / A\* / Greedy | Which navigation the creature uses |

- **Stat budget:** 15 at the zone's first wave, +1 per wave, max 24.
- **Adaptation budget:** sum of terrain genes ≤ 1.5 — forces specialisation.

### 5.4 Genetic Algorithm (Unit 2)

**Fitness** (each term normalised to 0–1, weights tunable per archetype):

```latex
F = 0.4 \cdot D + 0.25 \cdot P + 0.15 \cdot S + 0.2 \cdot O
```

D = damage dealt, P = pressure (time spent within 4 tiles of the player), S = survival time, O = objective disruption (e.g. damage to escort target or held point).

| Step | Choice |
| --- | --- |
| Population | 20 per archetype per wave (configurable) |
| Selection | Tournament, size 3 |
| Elitism | Top 2 per archetype |
| Crossover | Uniform, rate 0.9 |
| Mutation | 10% per gene; Gaussian nudge for numbers, re-pick for categories |
| Repair | Clamp to ranges, then enforce both budgets |
| Diversity guard | If >80% of the population share a path mode, mutation rate doubles for one generation |

**Visible evolution:** genes drive sprite variants — Speed → leaner body, Health → bulk, Vision → bigger eyes, Swimmer → fins, Climber → long arms, Crawler → flattened body. Higher total gene score → more grotesque overlays (extra eyes, growths).

### 5.5 Hill climbing baseline

Run headless against the bot player with the same number of fitness evaluations as the GA. Neighbours = each gene ± one step. Used only for the comparison experiment that shows local maxima and plateaus.

### 5.6 Player profiling with K-means (Unit 5, stretch)

K-means (Unit 5) reads how the player plays and feeds it back into spawning and the hidden story.

- Every 5 s, log: average distance to nearest enemy, % time moving, % time in cover, shots per minute, barricades/traps placed, dodge rolls used.
- Min-max normalise; K-means with k = 3, k-means++ init, max 100 iterations.
- Clusters are labelled by inspecting centroids — expected styles: **Camper**, **Kiter**, **Rusher** (to verify with playtest data, not assumed).
- **In game:** spawn points and archetype mix lean toward countering the current style (e.g. more Spitters vs. Campers).
- **Final boss:** the Seed mirrors the player's dominant style.

## 6. Navigation and movement AI

Goal: enemies that feel very smart and move smoothly, using techniques that are each small enough to write in a day. The core is **one shared flow field + simple steering**; a few cheap tricks on top make the horde look tactical.

### 6.1 The plan at a glance

| # | Technique | What the player sees | Effort (rough estimate) | When |
| --- | --- | --- | --- | --- |
| 1 | **Flow field** (Dijkstra / UCS from the player) | Whole horde finds the best route around walls, instantly | \~60 lines | Prototype |
| 2 | **Steering**: seek + separation + wall avoidance | Fluid motion, enemies spread out instead of stacking | \~40 lines | Prototype |
| 3 | **Line-of-sight shortcut** | When an enemy sees you, it comes straight at you — no grid zig-zag | \~10 lines | Prototype |
| 4 | **Pursuit prediction** | Enemies cut you off instead of trailing behind | \~5 lines | Prototype |
| 5 | **Attack ring** (tokens) | Enemies surround you; only a few attack at once | \~40 lines | Prototype |
| 6 | **Hand-written A\*** for single targets | Enemies investigate noises and reach flank points | \~80 lines | Prototype (syllabus) |
| 7 | **Small utility AI** (3 actions) | Quick, readable decisions that evolve | \~60 lines | Prototype |
| 8 | **Danger memory** | Horde learns to avoid your turret's line of fire | \~20 lines | Later |
| 9 | **Terrain cost profiles** | Swimmers/climbers take routes others can't | \~30 lines | Later (with zones 2–4) |

Line counts are estimates to show scale, not measurements.

### 6.2 Flow field — the core

- Run **one Dijkstra (= Uniform Cost Search)** outward from the player's tile over the terrain cost grid. Each tile stores the direction to its cheapest neighbour.
- Every enemy just reads the arrow under its feet → cost per enemy is almost zero, so 100+ enemies are fine.
- Rebuild only when the player moves to a new tile or terrain changes. a \~60 × 34 map (\~2,000 tiles) is small, so a full rebuild is cheap.
- This is the main reason horde games feel smooth: no enemy ever "waits" for a path.

### 6.3 Steering — the smoothness

Each frame, an enemy adds up a few force vectors and moves along the result (classic boids-style steering):

- **Seek** the flow-field direction (or the player directly if in line of sight).
- **Separation:** small push away from enemies closer than \~1 tile.
- **Wall avoidance:** two short feeler raycasts ahead; steer away if they hit a wall.
- **Pursuit:** aim at player position + player velocity × 0.3 s.
- Smooth turning: limit how fast velocity can change per frame, so nothing snaps.

### 6.4 Looking tactical for cheap

- **Attack ring:** 8 slots on a circle around the player. Max 3 enemies may attack at once; the rest take free slots and circle. Looks like surrounding, keeps fights fair.
- **A\*** (hand-written, octile heuristic) is used only when the target isn't the player: last heard noise, a flank point, the objective. Max 4 searches per frame, results cached.

### 6.5 Utility AI — fast decisions that evolve

Every 0.2 s each enemy scores a few actions; the best wins (with a small bonus for the current action to stop flickering).

| Action (prototype) | Score goes up when | Gene weight |
| --- | --- | --- |
| Chase | Player visible and close | Aggression |
| Flank | Allies already chasing, player facing elsewhere | Flanking |
| Investigate | Noise heard, player not visible | Patience |

Later: Hold for pack, Retreat, Break obstacle. Because the GA evolves the weights, a population can shift from charging to flanking — evolved tactics, not just stats.

### 6.6 Experiments for the report

| # | Compare | Metric |
| --- | --- | --- |
| N1 | Flow field vs. A\* per enemy at 20 / 50 / 100 enemies | ms per frame |
| N2 | A\* vs. Greedy vs. BFS | Nodes expanded, path cost, time |
| N3 | Steering on vs. off | Average heading change (smoothness), enemies stuck |
| N4 | Evolved vs. random behaviour weights | Damage to player, time to first hit |

## 7. Player and progression

One fixed player character: a **ranged shooter**, no classes and no melee. All extra abilities come from the skill tree; the player grows through levels, the skill tree, research and the Safehouse.

### 7.1 Player basics

**Rule: every way the player damages enemies works at a distance** — guns, turrets, traps, throwables. No melee attacks, ever.

| Item | Value (starting point) |
| --- | --- |
| Controls | WASD move · mouse aim · LMB shoot · Space dodge roll · R reload · Q/E skills · F interact · B build · Tab map |
| Health | 100 HP; healing from Safehouse and medkits |
| Dodge roll | Movement only (no damage): 0.3 s invulnerable, 1.2 s cooldown |
| Loadout | 2 guns + up to 2 unlocked skills |

### 7.2 XP and levels

- XP from kills (more for highly evolved enemies), objectives and research.
- Level cap 30; each level = 1 skill point. Every 5th level = bonus perk choice (pick 1 of 3).
- Death in a level: keep XP and research, restart the level. The enemies' evolution is kept too.

### 7.3 Skill tree — 3 branches

The branches are upgrade paths for the same shooter, not classes; players can mix them freely.

| Branch | Sample nodes | Capstone (level 20+) |
| --- | --- | --- |
| **Firepower** | Faster reload, piercing rounds, bonus damage on weak spots, bigger magazine | **Overclock** — 5 s of double fire rate |
| **Fortify** | Stronger barricades, auto-turret, spike traps, repair kit | **Fortress** — deploy walls + turret instantly |
| **Adapt** | Faster dodge, quieter footsteps, stealth in tall grass, slow regen | **Mimic** — enemies lose track of you for 6 s |

\~8 nodes per branch in v1 (24 total). Prototype: 6 nodes. Respec at the Safehouse.

### 7.4 Weapons

- **Prototype:** pistol + one unlockable gun (shotgun).
- **Later:** SMG, crossbow (silent), flamethrower (sets terrain on fire), nail gun; 2 mod slots each.
- **Power-ups: dropped from the prototype.** Possible later addition, not planned yet.

### 7.5 Research — counter the evolution

- Killed enemies drop **samples** tagged with their strain.
- At the Safehouse lab, samples unlock: the strain's bestiary entry → its gene readout in the HUD → a **counter-item** (e.g. anti-swarm grenade vs. high-Cohesion strains, sonic lure vs. Night-sense strains).
- The arms race made explicit: they adapt, you study, you counter.

### 7.6 Safehouse (hub)

- An old ice-cream factory on the edge of town. Return between levels and zones.
- Upgradable rooms with **scrap**: Workbench (gun mods), Lab (research), Radio (side objectives), Garden (healing items), Bunks (rescued survivors live here).
- Rescued survivors each offer one service (trader, medic, mechanic).

## 8. Objectives and campaign

The campaign is 16 levels (4 zones × 3 levels + 4 Apex bosses), each level built around one objective type so no two levels play the same.

### 8.1 Structure

- **Main goal:** reach Sunnyseed Labs and destroy the Seed.
- **Per zone:** 3 objective levels → Apex boss → return to Safehouse.
- **Level length:** 6–12 minutes.
- **Waves inside a level:** enemies arrive in waves; the GA runs between waves *within* the level and the population persists across the zone.

### 8.2 Objective types

| Type | Player goal | What it tests | AI twist |
| --- | --- | --- | --- |
| **Survive** | Last N waves | Core combat | Pure evolution pressure |
| **Hold the point** | Defend a radio tower / generator for X min | Building, positioning | Fitness rewards objective damage |
| **Escort** | Walk a survivor to the exit | Protecting an NPC | Enemies evolve to target the escort |
| **Purge nests** | Destroy 3–5 nests spread over the map | Movement, routing | Nests keep spawning until destroyed |
| **Extract** | Collect samples/supplies, reach evac | Risk vs. reward | Noise from looting draws enemies |
| **Stealth** | Cross the map without triggering alarms | Stealth skills | Vision/hearing genes matter most |
| **Apex boss** | Beat the zone boss | Everything learned | Boss built from the zone's best genome |

### 8.3 Side objectives

- Rescue survivors (they move into the Safehouse).
- Complete bestiary entries via research.
- Optional challenges per level (no damage, under time, no barricades) for bonus scrap.
- Story collectibles: decided after the prototype, when the story is finalised.

### 8.4 Win and lose

- **Level fail:** player HP = 0, escort dies, or point lost.
- **Campaign win:** destroy the Seed.
- **Post-game:** Endless mode (pure evolution, leaderboard of waves survived) and New Game+ with a higher mutation rate.

## 9. UI/UX and audio-visual

The look is pixel art in a bright, toy-like, early-2000s edutainment style that slowly turns unsettling — the UI itself is styled like a cheerful company product that gets corrupted as the story goes on.

### 9.1 Screens

| Screen | Contents |
| --- | --- |
| Title / main menu | Continue, New game, Endless (locked), Bestiary, Settings, Quit; mascot animates and "glitches" more as you progress |
| Settings | Audio sliders, keybinds, resolution/fullscreen, screen shake on/off, colour-blind palette, damage numbers on/off |
| Safehouse | Walkable hub with interactable rooms (skill tree, lab, workbench, map) |
| Skill tree | 3 branches, node tooltips, respec button |
| Zone / level map | Hand-drawn town map, unlocked levels, objective preview |
| Pause | Resume, settings, current objective, controls, quit to Safehouse |
| Wave report | Strain name, gene changes vs. last wave (arrows), fitness mini-graph |
| Bestiary | Every strain found: art, genes, lineage tree, counters unlocked |
| Level complete / fail | XP, scrap, samples, survivors, challenge results |
| Run summary (end of zone) | Evolution graph of the zone, "nemesis" strain family tree |

### 9.2 HUD

- Top-left: HP, dodge cooldown, ability icons.
- Top-right: objective tracker + wave counter.
- Bottom: XP bar, ammo, throwable.
- **Strain readout:** small panel showing the current wave's dominant traits as icons (e.g. fins + long arms) — the core of "visible evolution".
- Enemy outline appears when out of sight but heard (from noise system).

### 9.3 Art direction

- **Pixel art**, internal resolution 480 × 270, scaled ×4 to 1080p (crisp on common screens).
- **Palette:** saturated pastels in early zones; colours drain and turn fleshy toward the Lab.
- **Enemies:** 5 base sprites with walk/attack/hit/death animations + modular overlays driven by genes (fins, arms, eyes, growths) + colour tint. Infinite variety from limited art.
- **Tools:** Aseprite (paid) or Pixelorama / LibreSprite (free) for sprites; Godot TileMap for terrain.
- Art helper later: give them a style guide (palette, outline rules, sprite sizes) from this section.

### 9.4 Game feel ("juice")

Screen shake, hit-stop (2–3 frames on hits), muzzle flash, hit flash, knockback, particles on death, shell casings, footstep dust, damage numbers (toggle). Cheap to add, large effect on feel.

### 9.5 Audio

- **Adaptive music:** each zone theme has layers (calm → tense → combat → boss) faded in by threat level.
- **SFX:** distinct sound per archetype so players hear what's coming; evolved enemies sound more distorted.
- **Mascot jingles** on menus that slowly detune as the story progresses.
- Start with licensed free packs (check each licence); commission or replace later.

## 10. Tech: Godot architecture

Godot 4 with GDScript; game objects are scenes, but every graded algorithm lives in plain script classes with no scene dependencies, so it can be unit-tested and run headless for experiments.

### 10.1 Project structure

```
res://
├── autoload/            # global singletons
│   ├── game_state.gd    # current zone, level, player progress
│   ├── event_bus.gd     # signals: enemy_died, noise_emitted, wave_ended…
│   ├── save_system.gd   # JSON save/load to user://
│   └── audio_director.gd
├── ai/                  # pure logic, no Node dependencies
│   ├── grid/terrain_grid.gd, cost_profiles.gd
│   ├── nav/astar.gd, greedy.gd, flow_field.gd, path_smoother.gd, path_queue.gd
│   ├── steering/context_steering.gd
│   ├── decision/utility_ai.gd, actions/*.gd
│   ├── evolution/genome.gd, fitness.gd, genetic_algorithm.gd, hill_climbing.gd
│   ├── learning/kmeans.gd
│   ├── levelgen/csp_solver.gd
│   └── bot/bot_player.gd
├── entities/            # scenes
│   ├── player/, enemies/ (base_enemy.tscn + archetypes), projectiles/, pickups/
├── world/               # tilesets, room chunks per zone, hazards
├── ui/                  # menus, HUD, bestiary, skill tree
├── data/                # .tres Resources: weapons, skills, archetypes, zones, config
├── tools/               # headless experiment runner, CSV export
└── tests/               # GUT unit tests
```

### 10.2 Key patterns

- **Data-driven:** weapons, skills, archetypes and tuning numbers are Godot Resources (`.tres`), editable in the Inspector without code changes.
- **Event bus:** systems talk through signals (e.g. `noise_emitted(pos, radius)`), so AI, audio and UI stay decoupled.
- **Enemy scene = thin shell:** the Node handles sprite, physics and animation; it calls `UtilityAI`, `FlowField`/`AStar` and `ContextSteering` objects for every decision.
- **Fixed tick for AI** (decisions 5 Hz, steering every physics frame) independent of render FPS.
- **Heavy work off the main thread later:** flow-field rebuilds can move to Godot's `WorkerThreadPool` if profiling shows spikes.

### 10.3 Headless experiments

- `godot --headless -- --experiment ga_vs_random --generations 50 --seeds 5`
- Uses the same AI code with `bot_player.gd` in place of keyboard input; writes CSV to `user://runs/`.
- Graphs made from the CSV (Python + Matplotlib is fine for the report).

### 10.4 Testing

- **GUT** (Godot Unit Test addon) for `ai/`: A\* optimality on hand-made grids, flow field directions, genome repair within both budgets, GA elitism, CSP generator always yields a reachable objective, K-means on synthetic clusters.
- Playtests: 3–5 people per milestone, with a short feedback form.
- Git from day 1; commit after every working feature.

## 11. Roadmap, risks and open decisions

Phase 0 is a 2-week greybox prototype (target 15 Oct 2026) that proves evolution + smooth navigation; everything after is phased so a working AI build exists before the heavy content and art work.

### 11.1 Phase 0 — Prototype (2 weeks, greybox)

| Days | Goal |
| --- | --- |
| 1–2 | Godot basics: official "Your first 2D game" tutorial, scenes, signals, TileMap |
| 3–4 | Player: move, aim, shoot, dodge; camera; one greybox Maple Hollow map with 4–5 tile types |
| 5–6 | Terrain grid; **flow field** (Dijkstra) + hand-written **A\***; Runner follows the field |
| 7–8 | Steering (seek + separation + wall avoidance), line-of-sight shortcut, pursuit, attack ring |
| 9–10 | Utility AI (chase / flank / investigate); genome; fitness tracking; **GA between waves** |
| 11–12 | XP + levels, 6 skill-tree nodes, HUD, main menu, wave report screen |
| 13–14 | Bug fixes, playtest with 3 people, first GA vs. random run |

**Prototype done when:** Runners visibly change behaviour across waves, move smoothly with 50+ on screen, and the player can level up.

### 11.2 Later phases (no fixed dates yet)

1. **AI submission build** — add Greedy/BFS comparison, hill climbing, headless runner, experiments N1–N5 and GA charts. Freeze this build for the AI course.
2. **Vertical slice** — Zone 1 complete: 3 levels + The Mailman, Brute archetype, Safehouse v1, first real art and audio.
3. **Content** — Zones 2–4, remaining archetypes, CSP level generator, research, survivors, bestiary.
4. **Polish** — juice, adaptive music, settings, accessibility, balancing, story items.
5. **Release** — public build on itch.io (optional), trailer.

### 11.3 Risks

| Risk | Mitigation |
| --- | --- |
| Learning Godot slows the prototype | Days 1–2 reserved for tutorials; prototype stays greybox |
| Scope keeps growing | Pillars test (Section 1); new ideas go to a parking list, not into the current phase |
| GA makes the game unfair or boring | Budgets, attack tokens, diversity guard, playtests each milestone |
| Performance with 100+ enemies | Flow fields, path queue, AI LOD, profile early |
| Art bottleneck | Gene-driven modular sprites; style guide ready for an art helper |
| AI course deadline clashes with content work | AI submission build is Phase 1, before content |
| Burnout (solo, long project) | Small weekly goals; playable build every week |

### 11.4 Open decisions

- [ ] AI course submission / demo date
- [x] Final game title — decided: Amortia
- [ ] Pixel art confirmed, or a hand-drawn style instead?
- [ ] Who helps with art, and from which phase
- [ ] Story details — finalised after the prototype

## 12. Simple summary

**What it is:** A top-down pixel-art action game where cute-looking creatures evolve every wave to beat your playstyle — and get creepier as they do.

**Story:** A cheerful biotech company's evolving organism escaped. You're a courier fighting through 4 zones to destroy it at the lab. The deeper story is hidden in the world.

**The 4 zones:** Maple Hollow (suburbs) → Lowtide (flooded) → Greywood (forest) → Sunnyseed Labs (lab turning into hive). Each zone's terrain makes enemies evolve differently.

**How the AI works:**

- **Genetic Algorithm** evolves enemy stats, terrain skills *and* tactics between waves.
- **One shared flow field + hand-written A\*** find paths; **simple steering** keeps movement smooth; a small **utility AI** makes fast decisions.
- **K-means** reads your playstyle; a **CSP solver** builds level layouts (later).

**How you grow:** XP and levels, a 3-branch skill tree, weapons and power-ups, a Safehouse to upgrade, and research that unlocks counters to each strain.

**Plan:** 2-week greybox prototype → AI submission build → Zone 1 slice → full content → polish.

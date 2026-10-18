# Graded AI code — approach and pseudocode (expansion phases 2–8)

Learning-mode companion (CLAUDE.md): every change to `ai/nav`, `ai/evolution`, `ai/decision`,
`ai/learning`, `ai/levelgen` made during the 2026-10-13 evening build is explained here first,
then implemented with line comments. Read this before the code.

---

## Phase 2 — terrain genes (`ai/evolution/genome.gd`, `genome_rules.gd`, `genetic_algorithm.gd`)

**Idea.** Five genes 0..1: swimmer, climber, crawler, toxin_resistance, night_sense. They sit in
their own budget (sum ≤ 1.5, GDD 5.3), so a creature can be great at one or two terrains, not
all. Unlike stat points, the adaptation budget is a *ceiling*: a genome may spend less.

```
random(rng, rules, budget):
    ... stats and behaviour exactly as before ...
    weights[5] = rng.randf() each
    total      = rng.randf_range(0, adaptation_random_max)
    spread total over the 5 genes by weights, each capped at 1 (water-filling)

mutate(rate):
    ... as before ...
    for each terrain gene: with probability rate, gene += Gaussian(0, adaptation_sigma)
    repair()

repair():
    ... clamp stats / behaviour, spend stat budget (unchanged) ...
    clamp each terrain gene to 0..1
    if sum > adaptation_budget: multiply every terrain gene by adaptation_budget / sum
```
Scaling keeps the genome's *ratios* (a 2:1 swimmer:climber stays 2:1), like the stat repair.
Crossover: terrain genes are picked 50/50 per gene like every other number.
Old saves: missing terrain genes load as 0 (always legal).

Why draw the terrain genes last in `random()`: the first draws (behaviour, path mode, stat
weights) come out of the RNG in the same order as before.

## Phase 2 — `ai/nav/flow_field_set.gd` (new)

**Problem.** One shared flow field can only use one cost table, but a climber should see fences as
cost 2 and a non-climber as 6. One field per enemy is too slow (~8 ms each, rebuilt every
time the player changes tile).

**Idea: buckets.** Two enemies share a field if their costs for every terrain *on this map*
round to the same numbers. The first profile in a bucket is its representative; everyone in the
bucket navigates (flow field, A*, climb speed) with the representative, so A* and the flow
field always agree for that enemy.

```
key_of(profile):
    for each terrain id present on the map:
        part = name + ":" + (INF or round(cost, cost_step))
    return join(parts)

canonical_profile(p):
    k = key_of(p)
    if k not in buckets:
        if too many buckets: return base profile
        buckets[k] = (p, new FlowField built now)
    return buckets[k].profile

set_target(cell):        # player entered a new tile
    base field: build now
    every other field: mark stale (queue)

process():               # once per physics frame
    rebuild up to max_rebuilds_per_frame stale fields, oldest first
```
Stale fields lead to where the player was a frame or two ago — good enough to follow arrows,
and the enemy switches to straight-line pursuit when it can see the player anyway.
Deterministic: work per frame is counted, not timed.

## Phase 2 — `ai/nav/path_queue.gd`

Same algorithm; the cache key now includes the profile label:
`"profile|start|goal"`. Without it, a climber's cached path over a fence could be handed to a
non-climber (who would then walk into collision). Tail reuse is per (profile, goal) too.

---

## Phase 3 — `ai/decision/perception.gd` (new), `perception_settings.gd`, `world_conditions.gd`

**Idea.** Awareness (the memory: IDLE / INVESTIGATE / SEARCH / CHASE) is unchanged. What changed is
the *input* to it: whether this frame counts as "seeing" the player, and how far a noise carries.
Those rules are small pure functions so they can be unit-tested and explained one by one.

```
effective_sight_range(range, fog, night, night_sense):
    r = range * fog                          # fog tile at either end: 0.5
    if night: r *= 1 - 0.4 * (1 - night_sense)
    return r

can_see(distance, sense_radius, sight_range, line_clear, concealed):
    if distance <= sense_radius: return true  # 2 tiles: always noticed (GDD 4.3)
    if concealed: return false                # tall grass + walking + no recent shot
    return distance <= sight_range and line_clear

hearing_radius(radius, night, night_sense):
    if not night: return radius
    return radius * (1 + 0.25 + 0.5 * night_sense)

is_concealed(in_tall_grass, seconds_since_shot, dodging):
    return in_tall_grass and not dodging and seconds_since_shot >= 1.5
```
Night sense never adds information: it only scales ranges, and seeing still needs a clear grid
line, hearing still needs a noise event. A heard noise only sets `last_known` once (no tracking).
The two-tile exception is measured from the enemy to the concealed player.
Player noise: every 0.5 s of walking, a noise with the tile's loudness (grass 24 px, road 48,
mud / shallow water 96); a dodge roll 64 px; shots as before (weapon radius).

---

## Phase 7 — CSP level generator (`ai/levelgen/`)

**Problem.** Build a level from hand-made 16 × 16 room chunks so that exits line up, the player
can walk from the entry to the exit, enemy spawns are far from the player, there is at least one
hazard and no long runs of chokepoints — reproducibly from a seed.

**Model (Unit 4 CSP).**
- *Variables*: the chunk slots of a `cols × rows` grid (default 4 × 2 → 64 × 32 tiles).
- *Domains*: every chunk in the library, after unary pruning: a slot on the map edge may not
  have an exit pointing outside, except the entry slot (must open West) and the exit slot (must
  open East).
- *Binary constraints*: neighbours agree on their shared edge —
  `left.E == right.W`, `top.S == bottom.N` (an exit is a 2-tile opening in the middle of an edge,
  so "both open" or "both closed" is exactly "the boundary is valid").
- *Run constraint*: in any row or column, no 3 consecutive chokepoint chunks.
- *Global constraints* (checked when everything is assigned):
  hazard ≥ 1, BFS entry → exit over player-walkable tiles, ≥ `min_spawns` enemy spawn
  cells reachable by enemies and ≥ 15 tiles from the player spawn.

**Search: backtracking + MRV + forward checking.**
```
solve(seed):
    rng = seeded RNG
    domains[slot] = chunks passing the unary edge rules        # node consistency
    if some domain is empty: fail "no chunk fits slot ..."
    return backtrack({})

backtrack(assignment):
    if nodes > max_nodes: fail "search budget exhausted"
    if every slot assigned:
        return assignment if global_constraints_ok(assignment) else FAIL
    slot = unassigned slot with the FEWEST values left (MRV; ties -> lowest index)
    for chunk in shuffled(domains[slot], rng):                 # seed decides the layout
        nodes += 1
        if not run_constraint_ok(slot, chunk): continue
        saved = copy of the neighbours' domains
        assignment[slot] = chunk
        # forward checking: drop neighbour values that can't sit next to `chunk`
        prune neighbours of slot to chunks with a matching shared edge
        if no neighbour domain is empty:
            result = backtrack(assignment)
            if result: return result
        undo: assignment.erase(slot), restore saved domains      # backtrack
    return FAIL
```
MRV picks the most constrained slot first, so dead ends show up early; forward checking turns
an impossible neighbour into an immediate backtrack instead of a deep failed search. The global
BFS checks only run on complete layouts, which are few because the local constraints already
guarantee matching exits.

**Reachability for different movers.** The player uses `TerrainDefinition.player_passable`
(fences, water, walls block). Enemy spawns only need to reach the player for *enemies*: base
enemy cost < INF (they climb fences). Both BFS's are 4-way.

**Determinism.** All randomness is the shuffle of domain order from one seeded RNG; the slot order
(MRV with index tie-break) is deterministic, so a seed always gives the same layout.


## Wave pressure — the Bloom's hunger ramp (ai/decision, audit follow-up 2026-10-15)

**Problem.** Utility AI picks the highest score each 0.2 s. A lazy enemy holding a stale lead
scores `patience × 0.4` (≈ 0.02–0.08), a timid enemy watching the player scores
`aggression × 0.5…` (≈ 0.05–0.1); both lose to idle (0.1) forever, so a kill-all wave never ends.

**Idea.** One extra *input* — `wave_pressure` in 0..1 — rises with wave time, and both
approach actions take the larger of their gene and the pressure as their drive. The gene still
decides *how long* an enemy holds out; pressure decides *when everyone gives up*.
```
pressure(t) = clamp((t - start) / ramp, 0, 1)         # start 30 s, ramp 30 s (data/utility_ai.tres)

InvestigateAction.score:   (needs a lead, player not visible — unchanged)
    drive = patience + (1 - patience) * lead_strength
    drive = max(drive, pressure)                       # NEW
    return drive * (0.4 + 0.6 * freshness)             # pressure 1 -> at least 0.4 > idle 0.1

ChaseAction.score:         (needs the player visible — unchanged)
    drive = max(aggression, pressure)                  # NEW
    return drive * (chase_base + (1 - chase_base) * closeness)
```
Pressure never creates a lead and never overrides sight, so unaware enemies are not teleport-aggroed.
Flank is untouched (it needs allies chasing, which pressure now produces).

**Safety net (not AI).** `WaveManager.wave_deadline_seconds` = 75: a kill-all wave (Survive) ends
as cleared, survivors scored as survivors. Objective waves end by their own goal.

**Why it fits the GA.** Hiding used to be free (S = alive time / 45 s, D and P stay 0). With
pressure, a hider is eventually dragged into the fight and takes D/P like everyone else, so the
single fitness formula no longer rewards pure hiding. Measured (seed 4242, standing bot, 8 waves):
before — wave 1 never ended (stalled); after — every wave cleared in 52–73 s, 20/20 killed,
evolved patience settles ≈ 0.13 instead of drifting to 0.05.

Tests: `tests/test_wave_pressure.gd` (13).


## Pack tactics, escort hunting and ferocity (ai/decision, ai/evolution — behaviour step)

**Cohesion = pack coordination, not a stat.** It never adds aggression, speed or damage, and the
attack ring (3 tokens) is untouched. Two mechanisms, both in `PackCoordination` (pure) + `RegroupAction`:
```
SHARE (alarm call). When an enemy FIRST sees the player (and its cooldown of 2 s is over):
    for every ally within pack_radius (128 px):
        ally.awareness.hear(player_pos, min(sender.cohesion, ally.cohesion) * 0.8)
    -> an ordinary lead: it feeds the normal Investigate score, so a loner (cohesion ~0) ignores it.
       Real perception only: one position at the moment of sighting, no tracking.

REGROUP. inputs: pack_size = engaged allies (chasing / investigating) within 128 px,
                 anchor = centroid of engaged allies within 192 px, if a clear line to it exists
    RegroupAction.score = cohesion * 0.7 * (1 - wave_pressure)
        only if: player visible, anchor available, not expired, distance > 64 px, pack_size + 1 < 3
    Chase is NOT boosted. When pack_size + 1 >= 3 the score drops to 0 and every member's next
    decision (5 Hz) is Chase: the pack goes together. Movement = arrive at the anchor.

NO INDEFINITE WAITING (RegroupBudget, per enemy):
    spent += dt while (action == REGROUP and player seen)
    expired = spent >= 4 s
    spent resets ONLY after 6 s without seeing the player  -> flickering sight cannot restart the clock
    plus (1 - wave_pressure): the wave's hunger ramp fades regrouping out
```
Measured (open line, A sees the player at 110 px, B 125 px behind A, C/D further): cohesion 0 -> A
charges alone (arrives 1.1 s), B/C/D never hear of the player; cohesion 1 -> B is alerted, A waits
(bounded by the 4 s budget, never more), then A and B arrive within 0.2 s of each other.

**Hunt survivor (Escort).** The survivor is perceived with the player's rules (always within
`sense_radius`, further only inside the fog/night-adjusted sight range with a clear grid line).
```
HuntSurvivorAction.score = max(aggression, wave_pressure) * (chase_base + (1 - chase_base) * closeness(survivor))
                           * survivor_priority        # needs survivor_visible; competes with Chase on distance
execute: straight if the fat ray is clear, else A* through the shared PathQueue (re-plan when the
         survivor moves 2 cells); stand next to it. EscortObjective applies the hits:
         the 3 nearest enemies within reach, own cooldown, damage x ferocity scale.
```

**Ferocity** is a 4th budgeted stat (speed, health, vision, ferocity; each 1..10).
Budget 20 -> 32 (+1/wave): 4 x neutral 5 = 20, so the average enemy equals the archetype.
```
damage   = 8   * (1 + (ferocity - 5) * 0.08)        gene 10: 11.2, gene 1: 5.44
cooldown = 1.2 * (1 - (ferocity - 5) * 0.04), >= 0.5  gene 10: 0.96 s, gene 1: 1.39 s
DPS factor at gene 10 = 1.40 / 0.80 = 1.75  == health at gene 10 (1 + 5 * 0.15 = 1.75)
```
Points spent on ferocity come out of speed / health / vision (repair re-spends the exact budget
in the genome's own proportions), so there is no free power. Selection blind to ferocity does not
move it (40-seed mean 5.0 +- 0.45); selection that rewards it does, and the others pay.
Seeded standing-bot run (4242, 8 waves): total = budget every wave, ferocity 5.3 -> 6.8 (damage is
part of the fixed fitness formula; weights untouched).

**Removed genes.** `caution` and `path_mode` (and the diversity guard that only watched path_mode)
are gone from genomes, mutation, crossover, reports. Flow field, A* and the greedy straight line stay
in the code for the comparison experiments. Old saves: removed keys ignored; missing ferocity = 5
(old stats + 5 = the new wave-1 budget, so nothing is boosted or rescaled while it fits the budget).

## Reactive Survival V1 — vision cone, suspicion, safe survivor routes, objective fairness (2026-10-18)

**Vision cone and suspicion** (`ai/decision/perception.gd`, `awareness.gd`, settings in
`data/perception.tres`). Before V1 an enemy saw all around and one frame in view meant CHASE. Now:
```
in_view_cone(to_target, facing, cone):  cone >= 360 or facing == 0 -> true
                                        else |angle(facing, to_target)| <= cone / 2        (cone 120)

each frame, per enemy (Enemy._update_awareness):
    in_view = within sense_radius (32 px, any direction, even in tall grass)          # GDD 4.3 unchanged
              or (in cone and not concealed and distance <= effective range and clear grid line)
    if in_view and distance <= sense_radius:  awareness.see(p)            # no doubt: CHASE now
    elif in_view:                              awareness.notice(p, rate, dt, 0.5)
    else:                                      awareness.unnoticed(dt, ..., decay 0.5 / s)

suspicion_rate(d) = 1 / lerp(0.5 s, 1.8 s, (d - sense) / (range - sense))   x1.5 if already investigating / searching

notice:    glimpse = p; suspicion += rate * dt
           suspicion >= 1                      -> see(p)              = CHASE = "it sees you" (the alarm)
           crossed 0.5 (not chasing yet)       -> hear(p, suspicion)  = an ordinary lead to the glimpse spot
unnoticed: lose_sight()  (CHASE -> INVESTIGATE the last seen spot, unchanged); suspicion -= 0.5 * dt
```
The lead at 0.5 goes through the normal Investigate score, so the patience gene still decides
whether an enemy bothers (no new genes, fitness untouched). No live tracking: `glimpse` is only
updated while the player is really in view.

**Facing** (Enemy, Node side; numbers in perception settings): chasing -> at the player; moving ->
walking direction (becomes the rest direction); suspicion > 0 -> stare at the glimpse spot; idle ->
sweep +-30 degrees around the rest direction every 5 s; searching -> +-70 degrees every 2 s; a heard
noise turns the rest direction towards it. Turn speed 300 degrees/s. Spawn facing comes from the
spawn cell (no RNG draw, so seeded runs stay reproducible).

**SafePath** (`ai/nav/safe_path.gd`, new) — the Escort survivor's route:
```
A*, 4-way, player walking rules (gate counts as walkable)
step_cost(c) = 1 + threat_weight(8) * danger(c)
danger(c)    = sum over seen enemies t of max(0, 1 - |c - t| / 4 cells)
h(c)         = Manhattan(c, goal)           admissible: every step costs >= 1
```
No threats = shortest walk. Threats = detour if one exists; danger never blocks (a corridor with an
enemy in it is still walked). Re-planned every 0.5 s while following. Separately (objective code, not
graded): an enemy within 32 px makes the survivor step away, biased towards the player.

**ObjectiveFairness** (`ai/levelgen/objective_fairness.gd`, new) — generated Stealth / Escort areas:
```
route = SafePath(entry -> exit, no threats);  none -> reject "exit unreachable"
cover_ratio = share of route cells with tall grass or a sight blocker within 2 cells;  < 0.65 -> reject
stealth only:
    watchers(c) = spawn markers within 240 px with a clear line, unless c is tall grass
                  (worst case: all-round vision, by day, best vision gene)
    least-exposed route = Dijkstra, step cost 1 + 50 * |watchers(c)|
    distinct spawns watching it > 4 -> reject
rejected -> GeneratedArea tries seed + k * 104729 (k = 1..7), first that passes is used;
            none passes -> keep the first (warning). Same level -> same map, always.
```
Thresholds from 200 generator seeds: cover p05 0.62 / p50 0.74; watching spawns 3: 13 %, 4: 39 %,
5: 40 %, 6: 9 %. So it rejects the worse half for Stealth and the least-covered ~8 %, not everything.
Enemies, GA, fitness and navigation are untouched: only which layout a level uses can change.

Tuning note: the first fill times (0.35 s / 1.6 s, x2 alert) gave a scripted walk-through only
0.4-0.7 s between the first "?" and the alarm (footsteps had already made nearby enemies alert), so
they were raised to 0.5 s / 1.8 s, x1.5 before committing.

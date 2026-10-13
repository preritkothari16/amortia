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

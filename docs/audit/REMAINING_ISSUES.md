# Amortia audit — remaining issues and manual testing (2026-10-15)

Nothing here blocks the build. Items are ordered by how likely they are to matter. "Design" = a decision for the
user, not a bug to fix unasked (HANDOFF design principle: no rule changes from one playtest).

## Unresolved behaviour
1. **(FIXED in step 44: hunger ramp + 75 s deadline.)** ~~A wave can stall (design).~~ A wave ends only when every Runner is dead (Survive / Apex-less levels) or its
   objective is met. Low-patience Runners stay IDLE after a lead (`aware = INVESTIGATE`, action = IDLE) and never come;
   my bot spent 300 s with 2–3 of them left. There is no wave timer and no stragglers-to-the-player rule. Needs a
   design call (timer? let the idle ones drift toward the player?). Known since step 26.
2. **(FIXED in step 46: `caution` and `path_mode` removed, `cohesion` implemented as pack coordination, `ferocity` added.)**
3. **Enemy archetypes / weapons.** Only the Runner exists (GDD 5.1 lists Brute, Spitter, Screamer, Crawler); one
   weapon (GDD 7.4: + shotgun in the prototype); no research / Lab / bestiary (GDD 7.5); Safehouse rooms are disabled
   placeholders; Apex = a big Runner with no boss attack; Escort enemies now hunt the survivor (step 46).
4. **Course deliverables not in the repo** (GDD 5.5, 5.6, 6.6, 10.3): hill-climbing baseline, K-means player
   profiling, an in-repo headless experiment runner (`CLAUDE.md` still shows
   `godot --headless -- --experiment ga_vs_random`; `tools/` has only builders; `ai/learning/` and `ai/bot/` are
   empty). GA-vs-random was only run from scratch scripts and not rerun with the terrain genes.
5. **Zones 2–4 are placeholders** (Maple Hollow chunks + the zone's events). The generated areas contain no bridge
   tiles, so `BridgeCollapse` never fires; tide, living walls, fog and night do run.
6. **LivingWalls guarantee is not wired.** `protected_cells` is never set by the campaign, so the "can't cut entry
   from exit" promise rests on luck. 295 seeded 600-s runs on the zone-4 areas never cut the route. Fix when it
   bites (set entry + exit + objective cells in `main._setup_level`).
7. **(FIXED in step 45: Endless is test-only, saves nothing.)** ~~Endless overwrites the prototype save.~~ Endless is the prototype loop, so its wave checkpoints write
   `user://save.json`, replacing a New Game run's save. Design: give Endless its own slot or no checkpoints.
8. **Debug keys are live in every build.** F1–F10 (F3 skips a wave, F8 ends it, F9 restarts, F10 ignites) are not
   gated behind a debug build; F3 mid-level in the campaign would start waves outside `LevelFlow`'s control (reasoned from the code, not run).
9. **Two wave counters on the HUD.** "WAVE 3 generation 2" counts the zone's waves; "Wave 1 / 1" counts the level's.
10. **Cosmetic log noise.** Each new zone prints three `… missing or invalid; a fresh one will be used` warnings
    (a brand-new population has no RNG state yet — expected).
11. **Hitches.** ~100 ms on area load (Retry / next wave: generate + instantiate + flow rebuild) and ~48 ms when 20
    enemies spawn (headless numbers; windowed not re-measured). A single long A* can still reach ~23 ms (step 26).
12. **Working-tree churn left alone:** `data/terrain_costs.tres` (uid headers + two `= null` lines the editor saved),
    `world/main.tscn`, `world/tilesets/greybox_tileset.tres` (uid headers). They load and all tests pass with them.
    Commit or discard them yourself.

## Open design decisions (from HANDOFF, unchanged)
Proposed numbers (fire 15 / toxic 6 dps, footstep radii, adaptation budget 1.5, boss ×12 HP ×2 dmg…); death after a
cleared wave keeps the wave; grass burnable; enemies not slowed by mud / tall grass; fences shootable; fitness only
learns from cleared waves; XP does not follow the wave budget.

## Needs a human (not automatable by me)
- **Feel and balance:** player damage vs Runner HP, 100 HP per wave, dodge timing, XP pace, objective timers
  (Hold 45 s, Escort speed 40 px/s), whether Stealth is fair (my crude bot was spotted on every attempt, which says little about a person), Apex difficulty.
- **Evolution you can see:** does a real player notice the Bloomed adapting over 3–4 waves? Does the Wave Report make it
  clear? (Report text and numbers are verified; the experience is not.)
- **Windowed performance** with 50 Runners in zones 2–4 on your machine (headless timing is unreliable here).
- **Fights in the new terrain:** tall-grass stealth, fog, night, fire spreading on grass, tide, living walls — only
  exercised by tests and bots, never by a person.
- **UI at other aspect ratios / window sizes,** pause + skill tree + report stacking by mouse, keyboard-only play.
- **Full campaign by hand** (20 waves) including a death → Retry and a death → Restart level on an objective level,
  quitting at the Safehouse and continuing (the fixed path), New Game+ and Endless.

# Amortia - project audit & demo readiness (2026-10-29)

Audit only: no code, data or scene was changed. Evidence in this folder (levels/, menus/,
stealth_escort/, gameplay/). Godot 4.7.2, Windows, windowed runs unless stated.

## A. Executive summary

Verdict: **READY AFTER MINOR FIXES.** No crash, no broken progression, no failing test. All 16
campaign levels (20 areas) load, run a wave with 20 enemies, end the wave, open the exit, show the
report and emit `level_completed`. Stealth and Escort behave as designed in live runs. Menus and
HUD work with mouse and keyboard and stay sharp at 720p / 810p / 1080p.

What stands between this and a confident demo is mostly process and presentation, not function:
eight steps of work are uncommitted (plus 173 MB of untracked screenshots), the 15 generated
levels all come from one Maple Hollow generator (4 area pairs are identical maps), debug F-keys are
live in any debug build and there is no export preset, Greywood is hazy and low-contrast, and
frame pacing could not be verified with vsync on this machine.

## B. Repository state

- Branch `main`, HEAD `cf8d291` "Add deadline-ready player, enemy and atmosphere graphics".
- Uncommitted: steps 65-72 (world/menu/HUD overhaul, buildings, HUD x2, menus, power-up icons).
  - 30 modified tracked files: +2242 / -662 real lines (`git diff --ignore-cr-at-eol`).
    `enemy.gd` (1880 lines) and `test_objectives.gd` (525) look huge only because of CRLF churn;
    real changes are 14 and 25 lines. `core.autocrlf=true` normalises on commit.
  - About 60 new untracked source / data / art files (ui/theme/*, ui/hud/*, ui/menus/*,
    world/atmosphere/*, world/powerups/*, data/architecture.tres, data/hud.tres, 5 test files).
  - 173 MB of untracked screenshots in `art_src/forsaken_scientist/playtest/`.
  - No tracked file is deleted. The untracked `ruin_builder.gd` was deleted in step 69.
- HEAD alone does not contain the new files that the modified files need (e.g. `world/main.gd`
  uses `HudLayout`, the menus use `MenuStyle`). A partial commit would break the build.
- `ui/menus/safehouse.gd`: `SHOW_UNFINISHED_ROOMS = false` is present and the rooms are hidden
  (verified in code against HEAD and in the Safehouse screenshot). The diff vs HEAD is the step-65
  flag plus the step-70 restyle; nothing was lost.
- Load check: all 266 .gd / .tscn / .tres / .gdshader files under res:// load (0 failed).
- Main scene boots and quits cleanly (0 errors / warnings).
- Obsolete references: none to minimap, portrait, `ruin_builder`, `RuinBuilder` or
  `bake_ruins` in code or data. Only tests that assert their absence mention them.

## C. System by system

| System | Result | Evidence |
|---|---|---|
| Tests | 675 / 675, 162 921 asserts, 0 script errors; 16 warnings, all from deliberate bad-input fixtures (save validation, wrong-sized art, unknown terrain) | full GUT run, 330 s |
| Level flow | 16/16 levels, 20/20 areas: wave -> end -> exit -> report -> next area / `level_completed` | audit_levels runs, 0 errors |
| Reachability | exit reachable from the player spawn in 20/20 areas; every enemy spawn reaches the player (7/7 or 8/8) | same |
| Stealth (z3_l1, live) | 10/10: spotted in the open -> SPOTTED 3.0 s countdown; breaking line of sight = close call; second escape possible with a shorter countdown (2.4 s); staying exposed fails the objective; noise-maker -> enemy INVESTIGATE at the noise; tall grass conceals; shooting breaks concealment; no cones, F6 overlay off | stealth_escort/ |
| Escort (z1_l3, live, real key events) | E -> WAIT (survivor stays), E -> FOLLOW (catches up to about 27 px), R -> RUN (stamina drains), R -> FOLLOW; at a followable pace the survivor reaches the exit -> goal; an enemy on the survivor -> HP 0 -> "the survivor died" -> Game Over, paused, no revival | stealth_escort/ |
| Menus | navigation 20/20 twice: arrows / Enter / Esc / mouse hover + click, fullscreen on/off, persisted in user://settings.cfg, launch a level, pause -> settings -> back -> resume, pause -> main menu | menus/ |
| Text sharpness | MSDF body font; the heading font follows the window scale (x3 at 1440x810, x4 at 1920x1080 and 1920x1200 fullscreen, x2 at 1280x720) | font_scale_check, 1080p captures |
| HUD | 28 px strip, no portrait / minimap (test-enforced); live data verified in steps 71-72 captures; Apex text bug, see A-08 | levels/, hud_redesign/ |
| Buildings | 37 archetypes in `INFO` = 37 `paint` arms; 16 districts, one per level; Labs infection 0.03 -> 0.3 -> 0.62 -> 1.0 shows clearly in levels/z4_*; entrances drawn shut; collision / flow fields hash-identical to before (step 69) | levels/, data/architecture.tres |
| Power-ups | 5 types; every type has a 9x9 icon + 15x15 token (test); pickup = token + pulsing ring; HUD = per-effect icon + real-duration bar | powerup_icons/, test_power_up_art |
| Boss | Apex boss has aura ring, magenta halo, HP bar; objective HP shown | gameplay/boss_* |
| Removed systems | no ammo, magazine or reload anywhere; XP / levels / skills only in legacy-save migration text | grep |

## D. Level by level

All levels: completed their flow, exit reachable, enemy spawns reach the player, 0 script errors.
FPS = vsync-off average over 3 s with 20-21 enemies on the field, 1440x810 (see A-07).

| Level | Objective | Areas | District (landmark) | Buildings | FPS | Notes |
|---|---|---|---|---|---|---|
| z1_l1 | Survive | 2 | maple_residential | 8 / 6 hand-built | 622 / 678 | hand-built areas |
| z1_l2 | Hold | 1 | maple_commercial (supermarket) | 22 | 638 | |
| z1_l3 | Escort | 1 | maple_evacuation (hospital) | 22 | 511 | same map as z4_l1 area 2 |
| z1_l4 | Apex | 1 | maple_town_centre (town hall) | 18 | 619 | "HP 328 / 327" (A-08) |
| z2_l1 | Extract | 2 | lowtide_flooded_homes | 18 / 22 | 686 / 590 | |
| z2_l2 | Purge | 1 | lowtide_harbor_market (fish market) | 22 | 646 | |
| z2_l3 | Survive | 1 | lowtide_waterfront (hotel) | 18 | 607 | same map as z3_l2 |
| z2_l4 | Apex | 1 | lowtide_docks (harbour office) | 18 | 507 | same map as z4_l4 |
| z3_l1 | Stealth | 2 | greywood_trailhead (visitor centre) | 24 / 18 | 495 / 541 | area 2 = same map as z3_l4 |
| z3_l2 | Hold | 1 | greywood_lodge_camp (lodge) | 18 | 536 | |
| z3_l3 | Purge | 1 | greywood_logging (sawmill) | 18 | 558 | |
| z3_l4 | Apex | 1 | greywood_outpost (field lab) | 18 | 526 | |
| z4_l1 | Extract | 2 | labs_perimeter (admin) | 22 / 22 | 659 / 635 | clean, sterile |
| z4_l2 | Escort | 1 | labs_research_wings (lab tower) | 18 | 491 | first growth |
| z4_l3 | Survive | 1 | labs_containment (containment) | 18 | 547 | spreading |
| z4_l4 | Apex | 1 | labs_root (research complex) | 18 | 541 | overrun; "HP 263 / 262" (A-08) |

The prototype / Endless map (hand-built Maple Hollow) uses the zone's first district (residential).

## E. Tests and live checks

- GUT: 675 / 675 passing, 0 failing, 0 script errors.
- Live: level flow 20/20 areas; stealth 10/10; escort 10/10 (walk 7, death 3); menu nav 20/20 (x2);
  heading-font scaling 4/4; boss capture 2/2.
- Harness mistakes during the audit (my scripts, not the game), fixed before the passing runs:
  one stealth run stayed exposed through the whole countdown (the game correctly failed it), and
  one escort run outpaced the survivor's 96 px leash (the survivor correctly waited, A-06).
- Not verified: a human playthrough with real aiming and balance feel, frame pacing with vsync on
  (A-07), audio, New Game+ live, very long sessions (memory over time).

## F. Issue register

### P0 - none found

### P1
- **A-01 Uncommitted work at risk** - repo. Steps 65-72: 30 modified files, about 60 new source
  files. A partial commit breaks the build (new files are required by the modified ones).
  Fix: commit everything source-side together (or in ordered commits, each including its new
  files). Effort: Small.
- **A-02 173 MB of screenshots untracked** - `art_src/forsaken_scientist/playtest/`. `git add -A`
  would put them in history for good. Fix: ignore playtest/ (or keep only a few comparison
  sheets) before committing. Effort: Small.

### P2
- **A-03 Level variety** - all 15 generated levels use `data/levelgen/maple_hollow.tres`; area
  pairs with identical terrain: z1_l3 = z4_l1 area 2, z2_l3 = z3_l2, z2_l4 = z4_l4, z3_l1 area 2 =
  z3_l4. Zones differ by colour grade and buildings, not layout: Lowtide has one pool, not a
  flooded district; Greywood is suburb blocks with cabins, not a dense forest.
  Fix: per-zone generator settings / chunks (Large), or distinct seeds for the duplicates (Small,
  but changes layouts; fairness checks re-run). Needs your decision.
- **A-04 Debug keys live in demos** - `ui/debug/debug_keys.gd` enables F1-F10 (end / restart wave,
  overlays, ignite) in any debug build; there is no `export_presets.cfg`, so a demo from the
  editor has them on. Level Select also mentions F8. Fix: release export preset, or
  `DebugKeys.override = 0` for the demo. Effort: Small.
- **A-05 Greywood readability** - levels/z3_*: strong green haze; buildings and the dark enemy
  sprites have low contrast on dark green. Fix: lighten zone 3 fog / darkness in
  `data/visual_fx.tres` (data only). Effort: Small. Partly a matter of taste.
- **A-06 Escort pace** - `escort_leash` 96 px, survivor 40 px/s, player 90 px/s: walking normally
  loses the survivor within about 2 s. It then waits by design and "LOST YOU" shows only inside
  the long overflow line. Working as designed, but likely to confuse demo players.
  Fix (gameplay, needs approval): bigger leash or a clearer cue. Effort: Small.
- **A-07 Frame pacing unverified** - vsync off: 490-690 fps average, median frame 1.2-1.5 ms at
  1440x810 / 1080p / 720p, static memory 54-61 MB, VRAM 15-28 MB. Periodic ~140 ms stalls
  appear even in an empty scene (environment, not the project). Vsync-on runs gave 13-16 fps with
  150 ms frames even on the menu, which looks like OS throttling of a background window, so no
  trustworthy vsync figure. Fix: one human run with the window focused (Godot profiler / FPS
  monitor). Effort: Small.

### P3
- **A-08** Apex objective HP can read "328 / 327" (`world/objectives/apex_objective.gd:52`:
  `ceili(health)` vs `roundi(max_health)`). Committed code. Small.
- **A-09** Facade pixel-font `N` reads as `U` ("COUTAINMENT") - `world/atmosphere/pixel_font.gd`. Small.
- **A-10** Lowtide neon signs dim (known since step 69). Small.
- **A-11** Unreferenced: `entities/player/art/scientist_portrait_64.png` / `_96.png` (portrait
  retired), `ui/widgets/segment_bar.gd`; archetype `mall` is never assigned (no generated
  footprint is 7x4+). Cleanup later. Small.
- **A-12** Root-level reference images with lost path separators
  (`art_srcreferences*.png.png` + .import, 2.8 MB) get imported as project resources. Move them
  to `art_src/references/`. Small.
- **A-13** CRLF churn makes `enemy.gd` / `test_objectives.gd` look rewritten; review with
  `--ignore-cr-at-eol`. Small.
- **A-14** HANDOFF.md is 769 lines / 137 KB with very long "Latest" entries; trim. Small.
- **A-15** Regular enemies are small dark blobs: fine on Maple Hollow / Labs, weak on Greywood
  (see A-05). Character art itself is adequate for the demo; boss is clearly readable.

## G. Smallest action plan to demo-ready

1. A-02 then A-01: ignore the playtest screenshots, commit all source (your approval).
2. A-04: release export preset (or debug keys off) for the demo build.
3. A-07: one focused, vsync-on run to confirm smooth frame pacing.
4. A-08 + A-09: two one-line fixes.
5. A-05: one data tweak for Greywood visibility (optional, your call).
6. Decide A-03 / A-06 (layout variety, escort leash): design questions, not blockers.

## H. Verdict

**READY AFTER MINOR FIXES.** No P0. The P1s are repository hygiene (commit safely, keep 173 MB of
screenshots out). The functional evidence is strong: 675 tests green, every level completes its
flow, stealth / escort / menus pass live checks, and text is sharp at three resolutions. The
weakest point for "polished survival horror" is level variety across zones (A-03), which is a
content decision rather than a fix.

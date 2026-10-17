# Progression recovery audit (2026-10-17)

Audit of the interrupted player-progression work. **Nothing was fixed, reverted, staged or committed**
during this audit; the only files written are this report and a pointer in `HANDOFF.md`.

## Resolution (same day, user-approved)
Steps 1–5 of section 6 were done and committed as "Progression 4" (HANDOFF step 51): the two editor-noise files were
restored to HEAD (only uid / `= null` lines, no references to the new uids), stale comments / names / params and the
HUD gap cleaned, and 3 regression tests added (kills never raise permanent stats; expired power-ups vanish and spawning
continues — fails on `d958db4` code, passes now; collected power-ups free their place). Suite: 551 / 551.
The findings below describe the state *before* that commit. Step 6 (windowed playtest) is still open.

## 1. Git state

| | |
|---|---|
| Branch | `main` |
| Last commits | `93974a1` Progression 1 (enemy budget) → `679f7ce` Progression 2 (modifiers, weapons, research, Safehouse) → `d958db4` Progression 3 (power-ups) = HEAD |
| Last known good commit | `d958db4`: 577/577 tests pass, **but it has a power-up bug** (see 3.1) that the working tree already fixes. Before the progression work: `69f4716`. |
| Uncommitted = "Progression 4: remove XP / levels / skill tree" | 26 files **deleted and staged** (`D `), 25 files **modified, not staged** (` M`), 1 untracked (`docs/PROGRESSION.md`). Mixed staged / unstaged state; nothing lost. |

Staged deletions: `data/progression.tres`, `data/skill_tree.tres`, `data/skills/*.tres` (6),
`entities/player/player_progression.gd`, `progression_settings.gd`, `skills/player_skills.gd`, `skills/skill_node.gd`,
`skills/skill_tree.gd`, `ui/hud/xp_bar.gd`, `ui/menus/skill_tree_menu.gd`, `tests/test_player_progression.gd`,
`tests/test_player_skills.gd` (+ their `.uid` files).

Unstaged modifications: GDD, `autoload/game_state.gd`, `entities/player/player.gd/.tscn`, `project.godot` (K input removed),
`ui/menus/{game_over_screen,main_menu,pause_menu,report_screen,wave_report}.gd`, `world/{main.gd,main.tscn,save_game.gd}`,
`world/campaign/debug_scenarios.gd`, `world/powerups/power_up_manager.gd`, 9 test files, and 2 editor re-save files
(`data/terrain_costs.tres`, `world/tilesets/greybox_tileset.tres`; see 5).

## 2. Feature status

| # | Feature | Status | Where | Notes |
|---|---|---|---|---|
| 1 | Remove XP / levels / skill tree, fixed base stats | **Complete in code, Partial in docs** (uncommitted) | step 4 working tree | No code or scene references the removed classes, input action or nodes. Base stats only change through research + temporary layer (`Player._rebuild_stats`). Leftovers are comments, one unused var and one layout offset (section 5). |
| 2 | Research (Lab, samples + scrap, vaccines, +30 cap) | **Complete** (committed `679f7ce`) | `world/research/*`, `data/research_tree.tres`, `ui/menus/safehouse.gd` | Vaccine I/II/III: 10+60 / 20+120 / 30+180, zone gated, chained, +10 each, hard cap 30 (`group_caps`), enforced on unlock and on save restore. Only the vaccines exist: no other "rare permanent upgrades" are defined. |
| 3 | Weapons, blueprints, inventory, shotgun | **Complete** (committed) | `player_loadout.gd`, `weapon_library.gd`, `data/weapons/shotgun.tres`, `Pickup.create_blueprint`, Safehouse Workbench | Pistol always owned; 2 slots, Q swap with draw time; shotgun 8×6 dmg, 0.85 s, short range, loud. Blueprint hidden in z1_l1 last area + handed over by zone 1 Apex; build 80 scrap. Only one discoverable weapon. |
| 4 | Enemy budget 20/23/26/29, +1/wave, cap 32 | **Complete** (committed `93974a1`) | `GenomeRules.budget_for`, `data/genome_rules.tres`, `WaveManager.zone` | GA, fitness formula and genome allocation untouched (only `genome_rules` changed in `ai/evolution`). Old zone populations repaired to the new budget on load. |
| 5 | Power-ups (heal, shield, haste, fire rate, damage) | **Complete in working tree; Broken at HEAD** | `world/powerups/*`, `data/power_up_set.tres` | Seeded per wave (Retry replays), reachable cells 8–40 from player, max 3/wave, 2 on map, ≤ 12 s, same kind refreshes, max 3 timed effects, cleared on revive, never saved. HEAD bug: see 3.1. |
| 6 | Saves / migration | **Complete** (format 2 committed; XP migration uncommitted) | `GameState.to_dict/from_dict`, `SaveGame.validate` | Campaign format 2 stores loadout + research + scrap + samples; no `player` section written. Format 1 loads, XP/skills dropped, one-time menu notice (`legacy_notice`, cleared on next save). Prototype `save.json`: old `player` section ignored with a warning. Temporary effects never saved (tested). Lost attempt gives back scrap / samples / blueprints. |
| 7 | Integration | **Complete, docs Partial** | HUD, reports, Safehouse, campaign, Endless | HUD shows weapon `[Q]`, shield, active effects. Wave Report / Downed: Skills button and XP removed; Downed shows scrap / samples found this attempt. Pause menu controls say Q swap. Safehouse Workbench + Lab work and fit the viewport (tested). Campaign + Endless/prototype loop boot. |

No conflicting implementations found (no second XP path, no stat growth on kills: `EventBus.enemy_killed` is only
used by `LevelFlow` for resource drops). No orphaned scripts/resources (only `addons/gut/menu_manager.gd.uid`, vendored, pre-existing).

## 3. Test and startup results

| Check | Working tree | HEAD `d958db4` (clean export in scratchpad) |
|---|---|---|
| Full GUT suite | **548 / 548 pass**, 36 scripts, 160 021 asserts, 173.6 s | **577 / 577 pass**, 38 scripts, 174.9 s |
| `SCRIPT ERROR` / engine `ERROR` | 0 / 0 | 0 / 0 |
| Warnings | 15 (all expected, from save-validation tests) | same 15 |
| Orphans | 16 (one test, `test_retry_reloads_the_same_area_and_wave`) | same 16 → pre-existing |
| Deprecated (`wait_frames`) | 11 | 11 → pre-existing |
| `--import` | clean | clean |
| Boot main menu (180 frames) | no errors | – |
| Boot `world/main.tscn` (600 frames, prototype loop) | no errors | – |
| Load + instantiate all 50 `.tscn` / `.tres` | 50 / 50 OK | – |
| User saves (`campaign.json`, `save.json`) | unchanged by the boot checks (md5 checked); test files that write saves back them up and restore them | – |

Test count change 577 → 548 (−29) is fully explained: `test_player_progression` (15) and `test_player_skills` (12) deleted
with their features; `test_save_game` 24 → 20 (7 XP/skill validation tests removed, 3 legacy-save tests added);
`test_loadout_research` +1 (format 1 without progress → no notice); `test_power_ups` +1 (regression for 5.3).
No remaining test was weakened: the edited assertions test the new behaviour (gear per zone, no Skills button, legacy notice).

Focused areas covered by the passing suite: save/load + migration (`test_save_game`, `test_loadout_research`,
`test_audit_regressions`), campaign transitions incl. Safehouse and zone carry-over (`test_campaign`, `test_debug_scenarios`),
equipment + research (`test_loadout_research`), enemy budgets (`test_progression`), power-ups (`test_power_ups`), combat
(`test_melee_attack`, `test_enemy_tactics`). No manual windowed playtest was done in this audit.

### 3.1 New vs pre-existing issues
* **Bug in committed HEAD, fixed in the working tree:** `PowerUpManager._physics_process` did
  `_on_map = _on_map.filter(func(p: PowerUpPickup) ...)`. Once a pickup is freed (expired or collected) this logs every
  physics frame `Cannot convert argument 1 from Object to Object` + `Trying to assign an array of type "Array" to a variable
  of type "Array[PowerUpPickup]"`, and the list never shrinks, so after `max_on_map` pickups no more power-ups spawn.
  Reproduced by running the working tree's new test against HEAD code: it fails with those errors. Working tree fix:
  `_on_map.assign(_on_map.filter(func(p: Variant) ...))` (`world/powerups/power_up_manager.gd:58`).
* No new failures introduced by the uncommitted work. Orphans / deprecation / warnings are pre-existing.

## 4. Missing

* `HANDOFF.md` has no rows for the progression steps (1–3 committed, 4 uncommitted); its "Resume here", controls list
  (line ~176: "K skill tree", "XP bar, skill points") and gotchas still describe XP and the skill tree.
* `docs/PROGRESSION.md` (design + numbers of the redesign) is untracked.
* Step 4 is not committed.
* Not built (by the approved scope or later): more discoverable weapons, research beyond the vaccines. Listed only for
  completeness; not part of the interrupted work.
* No test asserts "killing an enemy does not change player stats" (the old XP path is deleted, so this is a guard only).

## 5. Exact files needing fixes (all small, none blocking)

| File | Issue |
|---|---|
| `ui/menus/game_over_screen.gd:5-7` | Garbled comment ("and and shows what you found ... the attempt can be spent before retrying"); line 14 still says "XP and evolution kept". Vars `_level` / `_xp` now hold "Found this attempt" / scrap text (misleading names). |
| `ui/menus/report_screen.gd:5-6, 29` | Comment fragment "the Skills\n## and the keys"; `_pulse` Tween var now unused. |
| `ui/hud/player_status.gd:3, 10` | Comment "above the XP bar"; `BOTTOM_OFFSET` 22 still leaves room for the removed XP bar (cosmetic gap). |
| `world/level/level_flow.gd:11, 14` | Comments mention skill tree / skill points. |
| `world/main.gd:14, 44, 134` | Comments mention skills bought / XP. |
| `autoload/event_bus.gd:8` | Comment "for XP". |
| `entities/player/player_stats.gd:5` | Comment "Nothing damages the player yet; the Fortify skills already raise it." |
| `autoload/game_state.gd` `finish_level` / `restart_level` | Unused `_legacy_player` parameter kept for compatibility; no caller passes it any more. |
| `data/terrain_costs.tres` | Editor re-save noise: uid added + `impassable = null`, `blocks_vision = null` lines. Verified harmless (compiled lists still correct: 7 impassable, 8 vision blockers), but unrelated to this step. Recommend `git restore` (needs your approval). |
| `world/tilesets/greybox_tileset.tres` | Editor re-save noise (uid only). Recommend `git restore` (needs approval). |
| `world/main.tscn` | Real change (XpBar + SkillTreeMenu nodes removed) mixed with Godot 4.7 editor re-save noise (uids, `unique_id`, typed events array). Loads fine; keep. |
| `HANDOFF.md` | Add progression steps, fix controls / resume text. |

## 6. Recommended order to finish

1. **Decide on editor noise**: restore `data/terrain_costs.tres` and `world/tilesets/greybox_tileset.tres` to HEAD (or keep).
2. **Clean stale comments / names** in the 8 files of section 5 (comments only + `_pulse`, `BOTTOM_OFFSET`, var names). No behaviour change; re-run GUT.
3. Optional guard test: a kill leaves `Player.stats` / `weapon` unchanged.
4. **Update `HANDOFF.md`** (steps 48–51: Progression 1–4, controls, resume line) and track `docs/PROGRESSION.md`.
5. **Commit step 4** ("Progression 4: remove XP, levels and skill tree; legacy save migration; power-up list fix") — this also ships the HEAD power-up fix.
6. Windowed playtest: one campaign level (power-ups spawn and expire repeatedly, Q swap, Downed screen), Safehouse Workbench + Lab, Continue from a format 1 save (notice shown once).
7. Only then: any new scope (more weapons / research), balance.

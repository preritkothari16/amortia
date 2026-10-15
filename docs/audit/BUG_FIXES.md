# Amortia audit — bug fixes (2026-10-15)

Commits: `878b7ce` "Audit: campaign continuity, damaged-save hardening, Safehouse layout" and a test-stability commit (item 7).
All six product issues were reproduced before fixing. Regression tests: `tests/test_audit_regressions.gd` (12 tests).
Suite: 461 → **473 / 473 pass**. No agreed mechanic, GA rule, fitness weight or save format changed
(the campaign save gained one optional key, `safehouse_pending`; old files load with it `false`).

| # | Severity | Issue | Root cause | Fix | Test |
|---|---|---|---|---|---|
| 1 | High | After beating the campaign, **New Game+** (or any new run) never shows **Continue Campaign** again | `GameState.campaign_won` was set at the Seed and never cleared; the menu hides Continue when it is true. The e2e run showed `won=true` in `campaign.json` right after New Game+ started | `start_new_campaign()` clears `campaign_won`. The unlocks (Endless, NG+) stay | `test_new_run_after_a_win_…`, `test_continue_campaign_is_offered_in_a_new_game_plus_run` (builds the real menu) |
| 2 | High | Quitting at the Safehouse ("Main Menu (progress saved)") and pressing Continue **replays the zone's Apex boss** | `finish_level()` on an Apex does not advance `level_index`; `enter_next_zone()` only runs from the Safehouse's own Continue. The save said "zone 1, level 4" so Continue loaded the Apex again (confirmed: `campaign.json` after the Seed = zone 4, level 3) | New saved flag `GameState.safehouse_pending` (set by an Apex win, cleared by `enter_next_zone` / `start_new_campaign`). Continue Campaign opens the Safehouse when it is set; the menu label says "Safehouse" | `test_beating_an_apex_marks_the_safehouse_as_pending_and_it_is_saved` (via JSON), `…clears_the_pending_safehouse`, `…normal_level…`, `…victory_is_not_a_pending_safehouse` |
| 3 | Medium | Endless "best wave" is lost when the game closes | `main.gd` only updated `GameState.endless_best_wave` in memory; it is written by `save_campaign()`, which Endless never called | `GameState.note_endless_wave(wave)`: raises the best and saves, only when it improves; test mode never writes (as before) | `test_endless_best_wave_is_saved_and_never_lowered`, `…not_saved_in_test_mode`. S: 5 Endless waves headless, best 1 → 5 |
| 4 | Medium | A save whose genome has a non-number terrain gene (`"swimmer": null`) **crashes** `SaveGame.validate` and loads a null genome | `validate` checked stat + behaviour genes but not terrain genes; `Genome.from_dict` then called `float(null)` ("Nonexistent 'float' constructor"). Found by the fuzz (589 script errors in 2 000 cases) | `world/save_game.gd` replaces an unreadable terrain gene with 0 and adds a warning (absent genes = old saves still load as 0). `ai/evolution/genome.gd` (graded file) untouched | `test_save_with_an_unreadable_terrain_gene_is_repaired_not_crashed` |
| 5 | Low | A hand-edited / damaged `campaign.json` with wrong types (`"zone": "two"`, `"side_done": 12`…) crashes `GameState.from_dict` (~600 script errors in 3 000 fuzz cases) | `int()`, `bool()`, `Array.assign()` on unchecked values | Typed helpers `_num` / `_flag`; `side_done` keeps only text ids; unusable values fall back to defaults. A valid save loads exactly as before | `test_campaign_save_with_wrong_types_loads_with_defaults`, `test_side_done_keeps_only_text_ids` |
| 6 | Medium (UX) | Safehouse: the "Strongest strain of the zone: spd … | FLOW" line is 556 px wide in a 480 px viewport, clipped on both sides (screenshots of the zone and victory Safehouse) | Label did not wrap (same class of bug as step 41's reports) | Safehouse labels wrap inside a fixed 400 px width | `test_safehouse_text_fits_the_480_px_viewport` — verified to fail on the old code (556 > 480) |

| 7 | Test only | `test_report_screens::test_skills_badge_shows_unspent_points` failed once in a full run (1 of 4) | The badge follows the points in `_process`, but the test waited with `wait_frames` = *physics* frames; under load two physics frames can pass in one process frame, so the check ran before the badge updated. Not a game bug | The test waits with `wait_process_frames(2)`. Assertions unchanged (not weakened) | 3 isolated runs + 2 full runs pass |

## Investigated and NOT changed
- **Waves that never end** (bot ran 300 s with 2–3 Runners left, aware = INVESTIGATE, action = IDLE). This is the
  documented gene effect (low-patience Runners ignore distant leads) and the user's design principle; see
  REMAINING_ISSUES.
- **Frame hitches** of ~100 ms on area load and ~48 ms on a 20-enemy spawn: single frames, no sustained cost.
- **LivingWalls `protected_cells` is never set** by the campaign (the class comment promises no soft-lock). 295
  seeded 600-s runs on the zone-4 areas never cut entry from exit, so no bug is demonstrated; left as is.
- **Spawn warnings** `ga_seed / ga_rng_state / spawn_rng_state missing or invalid` printed at the start of every
  new zone are the expected path for a fresh population (fresh RNGs are used); cosmetic.
- My own bot's early failures (`Bullet.setup`, greedy pathing into walls, a void-ternary) were harness bugs, not game bugs.

## How the fixes were verified
- GUT: 473 / 473 in two consecutive full runs after the last change (the flaky test above was found by a third run).
- Full campaign e2e (z1_l1 → victory → NG+): `won=false` after New Game+ starts (was `true`).
- Windowed screenshots of the Safehouse after the fix.
- Determinism and fence-climb traces unchanged (hash `3299913234` twice; 69 climb frames).

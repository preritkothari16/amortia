# Player progression (redesign, 2026-10-16)

The player has **no automatic stat progression**: no XP, no levels, no skill tree. Base stats are constant
(`data/player_stats.tres`: 100 HP, 90 px/s, dodge 0.3 s / 1.2 s). Enemies are the ones that grow.

## Layers (never mixed)
```
base stats / weapon       data/player_stats.tres, data/pistol.tres, data/weapons/*.tres   (never modified)
  + research  (permanent, saved)    ResearchState -> StatModifier list -> PlayerModifiers.research
  + weapon in hand (saved loadout)  PlayerLoadout (owned, blueprints, 2 slots) -> Player._base_weapon
  + temporary (power-ups, NOT saved) PowerUpManager -> PlayerModifiers temporary layer / Player.shield
```
`PlayerModifiers.apply()` always works on **copies**; clearing the temporary layer returns exactly to the
permanent values, and `Player.revive()` (every wave start) clears it.

## Where things are
| Part | Files |
|---|---|
| Modifiers | `entities/player/modifiers/stat_modifier.gd`, `player_modifiers.gd` |
| Weapons | `entities/projectiles/weapon_stats.gd` (pellets, spread, draw time), `weapon_library.gd`, `data/weapons/shotgun.tres`, `entities/player/player_loadout.gd` |
| Research | `world/research/research_node.gd`, `research_tree.gd`, `research_state.gd`, `data/research_tree.tres` |
| Blueprints | `Pickup.create_blueprint`, `LevelConfig.blueprint_weapon` (z1_l1 last area), `ZoneConfig.reward_blueprint` (zone 1 Apex), `world/level/reachable_cells.gd` |
| Safehouse | `ui/menus/safehouse.gd` (Workbench: build / carry; Lab: research) |
| Power-ups | `world/powerups/*`, `data/power_up_set.tres`, `LevelConfig.powerups_enabled` (on for the 16 campaign levels) |
| Saves | campaign format 2 (`loadout`, `research`); format 1 loads, XP / skills dropped with a one-time menu notice |
| Enemy budget | `GenomeRules.budget_for(zone, wave)`, `WaveManager.zone` |

## Numbers (all data files)
**Enemy stat budget** (4 stats, neutral genes 5 each = 20): zone 1: 20–24, zone 2: 23–27, zone 3: 26–30,
zone 4: 29–32 (cap 32, first reached in the Apex of zone 4 after +1 per wave).

**Weapons**
| | Pistol | Shotgun |
|---|---|---|
| damage | 10 | 8 pellets × 6 |
| cooldown | 0.25 s | 0.85 s |
| range (speed × lifetime) | 320 px | 96 px |
| noise radius | 192 px | 256 px |
| draw time | – | 0.4 s |
| DPS, all hitting | 40 | 56 (point blank), more in a crowd |
| cost | owned | blueprint + 80 scrap |

**Research** (zone gate = the zone just cleared at the Safehouse): Vaccine I (10 samples + 60 scrap, zone 1),
II (20 + 120, zone 2, needs I), III (30 + 180, zone 3, needs II); +10 max HP each, hard cap +30 (100 → 130).

**Power-ups** (weights 3 / 2 / 2 / 2 / 2): Medkit +25 HP; Shield absorbs 25 for 10 s; Haste ×1.25 move speed 10 s;
Rapid fire ×0.75 cooldown 10 s; Damage ×1.3 10 s. First after 12 s of an open wave, then every 25 s, at most
3 per wave and 2 on the map, 20 s on the ground, 8–40 cells from the player, effects ≤ 12 s, same kind refreshes,
at most 3 timed effects at once.

## Balance assumptions (measured or derived, not playtested)
* Average enemy at budget b has every stat ≈ b / 4: HP 30 / 34.5 / 38 / 43.5 at b = 20 / 24 / 27 / 32 (pistol:
  3 / 4 / 4 / 5 hits), speed ×1.0 → ×1.3 and melee DPS ×1.0 → ×1.4 (ferocity grows with the budget too).
  Three attackers do about 20 damage per second at b = 20 and 28 at b = 32: a 100 HP player survives contact
  for 5 s and then 3.6 s. A flat pistol does not keep up with that, which is why the shotgun comes after
  zone 1; research (+30 HP) buys back roughly one second.
* No unexplained power: every permanent gain is capped (HP +30) or a sideways trade (weapons). Experiments
  and the GA evaluate against the **base** player, so research, the shotgun and power-ups never change the
  fitness baseline.
* A lost attempt gives back scrap, samples and blueprints picked up in it, so Retry cannot farm resources.
* Power-ups are in the campaign levels only; they change D / P measurements while active (the player is
  faster, tougher), which the GA experiences as noise. Keep `powerups_enabled` off for any experiment.

## Migration
* Campaign save format 1 (XP, level, skills, scrap, samples, zone data): scrap, samples, zone and
  evolution load unchanged; XP and skills are dropped and the main menu says so once (`GameState.legacy_notice`);
  the next save writes format 2. No compensation is given for spent skill points.
* Prototype `user://save.json` (format 1): still validated; its `player` section is ignored (warning if it held
  progress). Nothing is deleted. The prototype loop is no longer reachable from New Game (Endless in Test
  Scenarios runs in test mode and saves nothing).
* Zone populations saved before option C are repaired to the zone's higher budget when loaded (warning).

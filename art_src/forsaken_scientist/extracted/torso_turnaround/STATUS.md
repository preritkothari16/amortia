# Torso idle — directions other than S (2026-10-24)

**Result: 1 of 8 directions done (S). 0 of the other 7 can be recovered from existing artwork.**
`scientist_torso_idle.png` is NOT complete; a partial sheet (S row only, other rows empty) is at
`../torso_sheet_partial/scientist_torso_idle.png` and fails `check_sheet.py` with 28 empty frames,
as it should. Nothing is in `entities/player/art/`; the greybox is unchanged.

## Sources checked
| Source | Directions it could give | Why not |
|---|---|---|
| Approved concept (`Amortia_ The Forsaken Scientist.png`) | front full body, head studies (front, 3/4, profile, back of head) | no body turnaround; head studies only |
| Board turnaround (`3b2bb3fb-...png`) | see below | labels wrong, gun painted in, soft |
| Board "torso idle 4 x 8" | — | gun painted into every row, cells cropped, frames redrawn (BOARD_AUDIT.md) |
| Torso Idle South sheet | S only | one direction |

Board turnaround, cell by cell (his right side = facing turned 90° clockwise, y down):
| Board label | Actually shows | Gun | Usable as torso master? |
|---|---|---|---|
| E | faces screen-left | on his LEFT arm, over the torso | no (wrong anatomy; covered torso) |
| SE | faces screen-left / down-left | on his LEFT arm | no |
| S | front 3/4 | his right (viewer's left), over the coat edge | not needed (S master exists, better source) |
| SW | front 3/4 facing down-left | hidden behind him ✓ | **candidate, rejected** (below) |
| W | back view, not a profile | viewer's right, over coat and legs | no (removing it leaves holes) |
| NW | back view | viewer's right, over coat | no |
| N | back view | viewer's right, over coat | no |
| NE | back view, near-identical to N | viewer's right, over coat | no |

So the board has only three distinct correct angles: S front, SW front 3/4, one back view.

## The SW candidate (`candidate_torso_SW_REJECTED.png`)
Extracted at the S master's scale (board scale 0.39: board-S head matches the S master's head,
IoU 0.88), feet on the pivot, cut at the S master's last row (62). Rejected because:
- At 1080p game size it reads as a dark hooded blob: face and collar unreadable, coat a speckled
  mass (neighbour contrast 24.9 vs the S master's 30.3).
- The board's painted floor shadow reaches above the cut, leaving a flat dark slab at the bottom.
- Camera mismatch: the board is a high 3/4 view, the S master near-frontal — turning S → SW would
  pop the camera angle as well as the detail level.
Fixing any of these means repainting, i.e. inventing artwork.

## Next: external generation — see `../../GENERATION_TORSO_DIRECTIONS.md`.

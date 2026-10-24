# Generation brief — torso idle masters E, SE, SW, W, NW, N, NE (2026-10-24)

One **static master per direction** is all that is needed: breathing is made afterwards by pixel
editing (`scripts/animate_torso_breath.py`), never by generating more frames.

## Attach as image references (every request)
1. `Amortia_ Torso Idle Sprite Sheet.png` — frame 0 only (crop it): **the style, scale and
   character to match exactly.** This is what the S master was made from.
2. `Amortia_ The Forsaken Scientist.png` — the approved concept (identity, gun-arm socket, coat).
3. `art_src/forsaken_scientist/extracted/torso_south/torso_idle_S_0.png` scaled x8 nearest — the
   in-game result the new directions must sit next to.

## Delivery format (what worked for the South sheet)
- One PNG per direction, **transparent background**, one figure, no labels/logo/plates needed.
- **Same scale as the South sheet's frame 0**: head top to chin ≈ 150 px, figure ≈ 430–460 px wide,
  framed from the top of the hair down to **mid-thigh** (the coat is cut there, like South).
- Same light (top-left), same palette family, same painterly-pixel rendering. Filename
  `torso_<DIR>.png`, e.g. `torso_NE.png`, into `art_src/forsaken_scientist/`.

## Camera — decide once, keep for all 8
The South master is **near-frontal** (slight high angle). Two consistent options:
- **A (no rework):** generate the 7 directions at the **same near-frontal camera as South** —
  the set matches the existing S master and breathing loop.
- **B (manifest camera):** high 3/4 top-down (~60°) for all 8 — then **South must be regenerated too**
  (and re-animated), because the current S master is not high 3/4.
Recommendation: **A** — it keeps the validated South work; the angle difference to the future
legs/gun layers is small at 48 px. The prompts below say "same camera as the reference".

## Master prompt (prefix every request)
> Same character, same art style, same scale and same camera as the attached reference frame:
> The Forsaken Scientist — gaunt pale scarred man, messy dark hair, angry exhausted face, rusted
> mechanical collar with spikes, open torn bloodstained off-white lab coat, bare scarred chest with
> dark surgical straps and belts, human LEFT arm with a bloodied fist. His RIGHT arm is NOT drawn:
> the right shoulder ends in a capped, rusted mechanical socket (the gun arm is a separate layer).
> Torso layer only: from the top of the hair down to mid-thigh, cut there. Transparent background,
> single figure, no text, no floor shadow.

**Negative:** gun, weapon, right arm, mirrored character, different face, different coat, legs
below mid-thigh, floor shadow, background, text, labels, extra limbs, cartoon, chibi, soft blur.

## Per-direction prompts (append to the master prompt)
His right side = his facing turned 90° clockwise on screen (screen y points down, camera at the bottom).

| File | Facing | Append |
|---|---|---|
| `torso_E.png` | screen-right | "Facing screen-right, side profile. His RIGHT shoulder faces the camera: the capped mechanical socket is clearly visible on the near side. His human left arm is on the far side, mostly hidden behind his chest; only the fist may show past his front." |
| `torso_SE.png` | down-right | "Three-quarter front view facing down and to the screen-right. The capped right-shoulder socket is on the viewer's left, close to the camera. The human left arm is on the viewer's right, slightly behind the body." |
| `torso_SW.png` | down-left | "Three-quarter front view facing down and to the screen-left. The human left arm and bloodied fist are on the viewer's right, close to the camera. The capped right-shoulder socket is on the viewer's left, on the far side, partly hidden." |
| `torso_W.png` | screen-left | "Facing screen-left, side profile. His human left arm is on the near side, in front of the body, bloodied fist visible. His right shoulder and its socket are on the far side, hidden behind his body." |
| `torso_NW.png` | up-left | "Three-quarter BACK view, facing away from the camera and to the screen-left; we see the back of his coat and the back of his head. The human left arm is on the viewer's left, near the camera. The capped right-shoulder socket is on the viewer's right, far side." |
| `torso_N.png` | away | "Full BACK view, facing directly away from the camera; back of the head and the torn back of the coat. Human left arm on the viewer's left. Capped mechanical socket on the viewer's right shoulder." |
| `torso_NE.png` | up-right | "Three-quarter BACK view, facing away from the camera and to the screen-right. The capped right-shoulder socket is on the viewer's right, near the camera and clearly visible. The human left arm is on the viewer's left, far side, partly hidden." |

## Acceptance (checked when each image arrives)
- [ ] No gun or right arm painted; a socket at the RIGHT shoulder on the side given above.
- [ ] Not a mirror of another direction (hair parting, scars, collar spikes, blood on the coat are
      not simply flipped; the fist is on his LEFT).
- [ ] Head size matches South (head silhouette IoU ≥ 0.8 after scaling, like the board check).
- [ ] Clean alpha (0 / ~250), single figure, framed to mid-thigh.
- [ ] After extraction: `check_sheet.py` on `scientist_torso_idle__<DIR>.png` OK; readable at
      1080p game size next to the S master.

## Pipeline per direction (once the image exists)
1. Extract master (alpha cut, same source scale as South 0.07 if the scale matches, head top on y 24,
   hips centred on x 40, palette snap) → `extracted/torso_<dir>/torso_idle_<DIR>_0.png`.
2. Breathing: `python -I art_src/forsaken_scientist/scripts/animate_torso_breath.py <master> <dir> <DIR> <chest_first-chest_last> <belt_row>`.
3. `python -I art_src/forsaken_scientist/scripts/build_torso_sheet.py` → when no row is missing it
   writes `extracted/torso_sheet/scientist_torso_idle.png`; run `check_sheet.py` on it.

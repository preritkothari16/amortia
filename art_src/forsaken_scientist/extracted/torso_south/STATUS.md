# Torso idle — South: status (2026-10-24)

## Breathing loop (current result) — `scientist_torso_idle__S.png`, `torso_idle_S_breath_0..3.png`
Made by `../../scripts/animate_torso_breath.py` from the master `torso_idle_S_0.png` by pixel
EDITING only: the block above a chest row (head, collar, shoulders, upper chest, coat shoulders and
lapels) moves up rigidly and the gap is filled by repeating that chest row. Rise per frame
0 / 1 / 2 / 1 art px = neutral, slight inhale, full inhale, slight exhale. Repeated rows: y 46
(frames 1–3) and y 44 (frame 2), picked as the chest rows most like their neighbours.

Verified by the script (fails otherwise): frame 0 = master byte for byte; rows 49–79 (belt and
below: coat tails, trousers, fist) identical in all frames; no colour outside the master's; alpha
0 / 255 only; head pixels = master pixels moved up by the rise. `check_sheet.py` OK (head top
y 22–24, guide 24). Visually (x12 chest zoom): no visible seam, the chest reads as taller on inhale.

Limitations:
- The head rides on the shoulders (+1 / +2 px, pixels unchanged) — keeping it still would mean
  squashing the collar, which has no clean row to remove.
- Every chest row is noisy (seam cost 143–221; the source is a downscaled painting), so a repeated
  row is a duplicated texture row, not a cleanly drawn one. Invisible at x1; a hand pass in
  Aseprite could tidy it.
- At the current 480 x 270 render (sprite scale 0.5, nearest) the 1 px frames (1, 3) fall between
  screen pixels: 76 % of the upper body re-samples (shimmer). Frame 2 is a clean 1 screen-px rise
  (9 % differ). At the planned 960 x 540 render all frames are exact.
- `data/player_visual.tres` `idle_fps` = 6 gives a 0.67 s breath; a calm breath needs ~1.5–2 fps
  (visual-only data value, not changed).

Previews: `preview_breath_S_x6.png` (frames + changed pixels in red: everything above row 46,
because it moved), `preview_breath_S.gif` (6 fps).

---

# Extraction status (2026-10-24)

Source: `Amortia_ Torso Idle Sprite Sheet.png` (repo root, 1983 x 793, 4 frames).
Script: `../../scripts/extract_torso_south.py`. Not assigned to the game; greybox unchanged.

**Verdict: usable as a static South torso pose (frame 0 recommended). NOT usable as the 4-frame
idle loop** — the frames are four separate redraws, not breathing.

| File | Status |
|---|---|
| `torso_idle_S_0.png` | ✅ valid still: passes `check_sheet.py`, on-model, head top on the guide (y 24), coat ends y 62 (hem guide 60) |
| `torso_idle_S_1..3.png` | ⚠ source redraws: each valid as a still, but they don't animate with frame 0 (see below); superseded by the breathing loop |
| `redraws_torso_idle_S_row.png` | the 4 source redraws as one row (rejected) |
| `preview_*.png` | previews, not assets |

## What was done
- Background, labels, logo and the labels' soft halo plates removed via the source alpha (figure
  250..253, background 0..3 → threshold 128, biggest piece per frame).
- One scale for all four frames (0.07: 10.5 px head, ~28 px shoulders; MANIFEST 10–11 / 24–28) —
  no per-frame stretching. Frames registered on the belt buckle so real motion is kept.
- Palette-snapped (32 colours) with hard alpha; `check_sheet.py` (new single-row mode) passes.

## Against MANIFEST and the concept
- ✅ Gun arm removed; human bloodied LEFT hand on his left (viewer's right). Mechanical collar,
  open torn bloodstained coat, dark straps and belts, messy dark hair, angry scarred face.
- ⚠ Camera is a near-frontal portrait view; the turnaround and legs are a higher top-down 3/4.
  Next to legs drawn from above the torso will look tilted towards the camera.
- ⚠ The right shoulder shows only an empty coat sleeve with a dark slit — no capped mechanical
  socket. OK if the gun-arm layer carries the shoulder mount (MANIFEST), but it must cover it.
- ⚠ Chest is fully human (abs, scars, blood); the concept's partial torso reconstruction /
  surgical attachments are missing. A cross pendant on the collar is new (not in the concept).
- ⚠ Coat ends at mid-thigh; the concept coat reaches the calves, so the legs layer must carry the
  coat tails below the hem.

## Breathing check (measured)
| | Ideal breathing (upper body 1 px up) | Frame 1 vs 0 | Frame 2 vs 0 | Frame 3 vs 0 |
|---|---|---|---|---|
| Lower body (below belt) pixels that differ | **0 %** | 74 % | 70 % | 67 % |
| Upper body, after best shift (±2 px) | 47 % (with the shift: 0 %) | 49 % | 64 % | 50 % |
| Best shift found | (0, −1) | (0, 0) | (0, 0) | (0, 0) |

Consecutive frames: 56–68 % of figure pixels change and 57–88 silhouette pixels flip per step
(edge boiling). Source landmarks relative to the belt: eye −270 / −271 / −250 / −279 src px —
frame 2 drops ~1 art px and frame 3 jumps ~1.5 px above frame 0; no smooth rise and fall. Hair
strands, scars, blood splats and lapel shapes are redrawn every frame. In game this would flicker,
not breathe.

## Readability
- Art scale (= the planned 960 x 540 render): reads as him — hair, open coat, dark chest, red fist.
  But painterly: 56,448 source colours, no clean 1 px outline, speckled coat edges, face ~4 px.
  Needs a hand cleanup pass (outline, clusters) before it is production quality.
- Current 480 x 270 render (sprite scale 0.5, nearest): a 16 px blob; the face is lost. The
  960 x 540 render step is needed for this art to read at all.

## Source changes needed
1. **One drawing, animated by edits** — not four generations. Keep frame 0 as the master; the other
   frames must be the same pixels with only the head, shoulders and chest raised 1–2 art px
   (e.g. 0, +1, +2, +1) and the coat lapels following. Below the belt: pixel-identical. A generator
   cannot do this reliably; do it in Aseprite / Pixelorama from frame 0 (or image-to-image edits of
   frame 0 that are then diffed and cleaned).
2. **Higher camera**: top-down 3/4 (~60°) like the turnaround — more top of head and shoulders,
   less underside of the chin.
3. **Native pixel art**: draw at the target size (≈ 32 x 40 px inside 80 x 80) or an exact integer
   multiple of it, ≤ 32 flat colours, 1 px selective outline — not a painted image to be shrunk 14x.
4. **Concept details**: a visible capped mechanical socket at the right shoulder; stitched / partly
   mechanical chest reconstruction; drop the cross pendant unless wanted.
5. Same delivery format again (transparent background, one direction per image) works well: the
   alpha was clean and the frames separated without manual masking.

# Generated pixel-art board — extraction audit (2026-10-24)

Source: `3b2bb3fb-30bb-4bd7-8dea-1a0152edb45d.png` (repo root, 1536 x 1024).
Extraction script: `scripts/extract_board.py` → `extracted/`.

**Result: none of the three required sheets can be built from this board.** The board shows the
right character and style, but its sections are illustrations of sheet layouts, not usable frames.
`data/player_visual.tres` is unchanged; the game still draws the greybox player.

## Findings per section

| Section (board label) | What it really contains | Usable? |
|---|---|---|
| 8-direction turnaround | One static pose per direction. **E and SE are wrong**: he faces screen-left with the gun on the near (south) side — that is a west-facing pose with the gun on his LEFT arm, not E / SE. S, NW, N, NE agree with the right-arm rule. SW and W hide the gun and read as 3/4 back views rather than SW / W. Layers are not separated. | Reference only (`extracted/board_turnaround_80.png`) |
| Legs walk (6 x 8) | 48 near-identical crops of the same 3/4 lower body. Row-to-row difference (18.4 mean RGB) is no bigger than frame-to-frame (19.4): **the 8 rows are not 8 directions** (E, S and N rows show the same view). Frames are not a stride: feet positions change at random. Coat hem fragments included. | **No** |
| Torso idle (4 x 8) | Rows do change view (front for E…W, back for NW/N). But: the **gun arm is painted into every torso** (removing it leaves holes in the coat and chest that would have to be invented); cells are **cropped at the waist and at the left edge** (the gun is cut off); the 4 frames per row are **not a breathing loop** — head angle, hair and face change at random between frames, so it would flicker; the **W row has the gun on the near side** (= his left arm). | **No** |
| Gun arm (4 x 16) | **Only 3 columns.** All 16 rows point the same way: measured principal axis 0–17° or 166–180° in every row, against the required 11.25°…348.75° (row k = 11.25 + 22.5 k). Rows 4–11 should point S → W → N; none do. No shoulder mount aligned to a torso. | **No** |
| FX muzzle flash (3 x 16) | 3 genuine frames of a round, non-directional burst; the 16 rows repeat it. | Yes, 3 frames (`extracted/flash_pistol_0..2.png`); per-row placement needs the gun-arm art |
| FX shotgun flash (3 x 16) | **2 columns**, drawn pointing east only; rows repeat. | Partly (`extracted/flash_shotgun_east_0..1.png`): east only, frame 3 missing |
| Portrait 96 x 96 | Good, on-model, readable. | **Yes** (`extracted/board_portrait_96.png`, `_64.png`, palette-snapped) |
| Details (zoom), palette | Close-ups and a 32-swatch palette illustration. | Reference only |

Whole board: alpha is noisy everywhere (13…253, 45 % of pixels below 250), and the art is painted
at a soft, non-integer pixel grid (anti-aliased edges), so even good regions need palette snapping and
hard alpha. `extract_board.py` does both; all extracted files pass the alpha / palette checks.

Gameplay readability: at the current 480 x 270 render the 48 px figure is shown 24 px tall and the
turnaround poses blur to a dark shape with a light coat and red specks
(`extracted/board_turnaround_gamescale_x4.png`); at art scale (= a 960 x 540 render) coat, hair and gun
cores read (`extracted/board_turnaround_preview_x3.png`). The planned 960 x 540 render step matters.
Note: the extracted turnaround includes the board's painted floor shadow, so feet sit ~2 px above the
pivot; fine for reference, not for runtime.

## Exact missing frames (required for the rig to switch on)

| Sheet | Missing | Must show |
|---|---|---|
| `scientist_legs_walk.png` 480 x 640 | **all 48** (6 frames x E, SE, S, SW, W, NW, N, NE) | lower legs + boots only, a real stride per row, each row a different facing |
| `scientist_torso_idle.png` 320 x 640 | **all 32** (4 frames x 8 directions) | torso + head + coat + human left arm, **no gun arm**, full height to the hem, consistent face/hair across the 4 frames (breathing only) |
| `scientist_gunarm.png` 320 x 1280 | **all 64** (4 frames x 16 angles) | gun arm + shoulder mount only, row k pointing 11.25 + 22.5 k degrees |

Optional sheets still missing: all of legs_idle, torso_walk, torso_throw, torso_hurt, gunarm_glow, roll,
death, shadow; muzzle_flash needs per-row placement (art exists); muzzle_flash_shotgun needs frame 3
and 15 non-east rows (or a symmetric design).

## What new source images are needed

Generators did not hold direction, layer separation or frame consistency across a whole board.
Ask for **one row at a time**, flat single-colour background (e.g. pure #00FF00), no labels, no grid:

1. **Torso, one direction per image**, gun arm removed: "...torso, head, open lab coat to the hem and
   human left arm only; the right arm ends at a capped mechanical shoulder socket; facing {DIR};
   4 frames left to right of slow breathing; identical face, hair and coat in all 4 frames."
2. **Gun arm, one angle per image** (16 images, or 4 images of 4 angles): "...only the right gun arm
   with its shoulder mount, nothing else, barrel pointing {ANGLE} degrees clockwise from screen-right,
   seen from a high 3/4 top-down camera; 4 frames: rest, firing kick, recoil, settle."
3. **Legs, one direction per image**: "...only boots and lower legs below a coat hem, walking toward
   {DIR}, 6 frames of one full stride, same scale every frame."
4. **Turnaround fix**: E and SE again, with the gun on his RIGHT arm (for E the gun is on the near,
   south side pointing right; for W it is hidden behind him).

Full prompt text and the master / negative prompts: `MANIFEST.md`. Each row still needs a hand pass
over the guide template (pivot, shoulder dot, aim line) before `check_sheet.py`.

Alternative that avoids frame-consistency problems entirely: a pixel artist (or 3D model rendered to
pixels) using `templates/` and the turnaround as reference.

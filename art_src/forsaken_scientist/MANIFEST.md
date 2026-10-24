# The Forsaken Scientist — sprite manifest

**Status: BLOCKED on artwork.** The rig, layout, palette, guides, checks and HUD portrait exist.
The 13 animation sheets below do not. No image generator was usable in the build environment
(Canva: credit quota exceeded; no local Aseprite / Blender / diffusion model). Until the three
**required** sheets are in `data/player_visual.tres`, the game keeps drawing the greybox player.

Approved design: `Amortia_ The Forsaken Scientist.png` (repo root). Everything here must match it.

2026-10-24: a generated pixel-art board (`3b2bb3fb-...png`, repo root) was audited — it gives the
portrait, 3 pistol-flash frames and a static turnaround reference, but **none of the three required
sheets**. Details and exact missing frames: `BOARD_AUDIT.md`.
2026-10-24: "Torso Idle - South" (`Amortia_ Torso Idle Sprite Sheet.png`, repo root) extracted to
`extracted/torso_south/`: valid as a static S pose, not as an idle loop (four redraws, not breathing).
See `extracted/torso_south/STATUS.md`. Single rows can be checked as `<sheet>__<ROW>.png`.
2026-10-24: S breathing loop done by pixel editing (`scripts/animate_torso_breath.py`). The other 7
torso directions cannot be recovered from existing art (`extracted/torso_turnaround/STATUS.md`);
generation brief: `GENERATION_TORSO_DIRECTIONS.md`. `scripts/build_torso_sheet.py` assembles the sheet
and leaves missing rows empty; `check_sheet.py` now fails any empty frame.

## Character lock
- Mostly human face, moderate disfigurement: deep scratches, surgical scars. Angry, exhausted.
  Messy dark hair. No mask, no facial plating.
- Lean, imposing, slightly asymmetrical. Pale damaged skin. Exposed rusted mechanical collar,
  neck and shoulder plates; stitched, partly reconstructed torso with dark surgical straps.
- Long torn bloodstained off-white lab coat, ragged hem; dark ragged trousers; heavy spiked boots;
  belts, buckles, hanging straps.
- **His RIGHT arm is the gun**: large rusted industrial barrel arm, surgically fused at the
  shoulder, exposed mechanics, red-orange glowing cores. His LEFT arm is human (bloodied hand).
- Horror, not hero. No clean armour, no cartoon shapes.

## Technical rules (all sheets)
| Rule | Value |
|---|---|
| Frame | 80 x 80 px, transparent PNG, RGBA |
| Pivot | feet centre at (40, 72) in every frame |
| In game | drawn at scale 0.5: 2 art px = 1 world px; 32 art px = one 16-unit world tile |
| Figure | ~48 px tall standing (head top y 24, chin y 35, shoulders y 38, coat hem ~y 60), shoulders ~24–28 px wide, head ~10–11 px |
| Footprint | 24 x 12 ellipse around the pivot = the collision circle (radius 6 world px) |
| Camera | top-down 3/4 (high angle, about 60°); same angle in every sheet |
| Light | from top-left; cold shadows; red-orange glow only on the gun cores and muzzle flash |
| Palette | `palette_forsaken.gpl` (32 colours) only; `fx_*` sheets may also use them all |
| Outline | 1 px selective: `outline` #060504 on the shadow side, darker neighbour shade on the lit side |
| Anti-aliasing | none: alpha 0 or 255 only, no blur, no soft brushes |
| Mirroring | **never** for torso / gun arm / roll / death (it would move the gun to his left arm) |

Row order, 8-direction sheets (Godot angles, y down): **E, SE, S, SW, W, NW, N, NE**.
Death rows: **E, S, W, N**. Gun-arm rows: row *k* points at **11.25 + 22.5 k** degrees
(row 0 = 11.25° just below east, row 4 = 101.25° just past south, row 12 = 281.25° just past north).
The gun arm is drawn **in front of** the torso for rows 14, 15, 0–5 and **behind** for rows 6–13
(aiming W through N), so draw the torso complete on those rows.

## Sheets — `entities/player/art/<name>.png`
| Name | Cols x rows | Size px | Req. | Timing | Content |
|---|---|---|---|---|---|
| scientist_legs_walk | 6 x 8 | 480 x 640 | **yes** | stride: 28 world px per loop | boots and shins below the hem, one full stride (two steps); frame 0 = contact, right foot forward |
| scientist_torso_idle | 4 x 8 | 320 x 640 | **yes** | 6 fps loop | torso, head, coat, human left arm; breathing, coat sway. No gun arm, no legs below the hem |
| scientist_gunarm | 4 x 16 | 320 x 1280 | **yes** | 24 fps after a shot | right gun arm + shoulder mount only: rest, fire (kick), recoil, settle |
| scientist_legs_idle | 1 x 8 | 80 x 640 | | — | standing legs |
| scientist_torso_walk | 6 x 8 | 480 x 640 | | in step with legs | bob and coat swing matching legs_walk frame for frame |
| scientist_torso_throw | 4 x 8 | 320 x 640 | | 16 fps once | noise-maker throw with the LEFT hand: wind-up, release, follow-through, recover |
| scientist_torso_hurt | 2 x 8 | 160 x 640 | | 12 fps once | flinch back, recover (red flash is added by code) |
| scientist_gunarm_glow | 4 x 16 | 320 x 1280 | | as gunarm | glow pixels only (glow_0..3), same frames as gunarm |
| fx_muzzle_flash | 3 x 16 | 240 x 1280 | | 30 fps once | pistol flash at the visual barrel tip of the matching gun-arm row |
| fx_muzzle_flash_shotgun | 3 x 16 | 240 x 1280 | | 30 fps once | wider, longer flash for the shotgun |
| scientist_roll | 6 x 8 | 480 x 640 | | spread over the 0.3 s roll | whole body roll in the row's direction; coat wraps; gun stays on his right |
| scientist_death | 8 x 4 | 640 x 320 | | 10 fps, last held | whole body collapse to a corpse; last frame stays until revive |
| scientist_shadow | 1 x 1 | 80 x 80 | | — | dark ground ellipse (dithered edge) under the pivot |

HUD / menu portrait (done, converted from the approved neutral head study):
`entities/player/art/scientist_portrait_96.png`, `scientist_portrait_64.png`. Not wired into any
HUD yet.

## Guide templates — `templates/<name>_guide.png`
Put them on a locked reference layer. Cyan = frame edge; green = head top / chin / hem heights;
yellow ellipse = collision footprint; magenta cross = pivot; orange dot = his right shoulder for
that row; red line = facing (body sheets) or the row's exact aim angle from the shoulder (gun-arm and
flash sheets); white dot = where bullets really spawn (ground level, may lie outside the frame).
The muzzle flash goes at the end of the drawn barrel, not on the white dot.

## Pipeline
1. Draw (or generate and repaint) each sheet over its guide, palette locked to `palette_forsaken`.
2. Optional first pass on generated frames: `python -I art_src/forsaken_scientist/scripts/snap_to_palette.py in.png out.png`.
   Hand cleanup of every frame is still needed (outline, clusters, silhouette, pivot).
3. Check: `python -I art_src/forsaken_scientist/scripts/check_sheet.py entities/player/art/*.png`
   (size, alpha, palette, feet on the pivot row).
4. In Godot: select each PNG → Import: Filter off (project default Nearest), Mipmaps off.
   Assign it to the matching slot of `data/player_visual.tres`. With the three required sheets
   set, the rig switches from the greybox to the art on its own; wrong-sized sheets are ignored
   with a warning.
5. Rebuild palette / guides / portrait: `python -I art_src/forsaken_scientist/scripts/build_kit.py`.

## Generation prompts
Attach the approved concept sheet as the image reference in every prompt. Generate one direction
(one row) at a time on a flat, single-colour background, then repaint onto the 80 x 80 guide.
Expect every generated frame to need repainting; generators do not hold a pixel grid, a pivot or
a consistent design across frames.

**Master prompt** (prefix every prompt with it):
> Detailed top-down 2D pixel art game sprite, high 3/4 top-down camera, survival-horror, dark gritty
> palette of near-blacks, rust, bone-white, pale skin and blood red, restrained red-orange glow.
> The Forsaken Scientist from the reference sheet: gaunt, pale, scarred human face with messy dark
> hair and an angry exhausted expression; rusted mechanical collar, neck and shoulder plates; stitched
> pale chest crossed by dark surgical straps; long torn bloodstained off-white lab coat with ragged hem;
> dark ragged trousers; heavy black spiked boots; his RIGHT arm is a large rusted industrial gun barrel
> surgically fused at the shoulder with glowing red-orange cores; his left arm is human with a bloodied
> hand. Crisp 1 px outline, hard pixel edges, no anti-aliasing, no blur, flat plain background.

**Negative prompt:** cartoon, chibi, cute, heroic, clean sci-fi armour, robot mask, helmet, glossy,
photoreal, 3D render, soft shading, blur, gradient background, text, watermark, gun in left hand,
handheld rifle, extra limbs.

| Sheet | Prompt (after the master prompt) |
|---|---|
| turnaround (do first) | Eight views of the same standing character in one row, facing east, south-east, south, south-west, west, north-west, north, north-east; identical proportions, gun always on his right arm |
| legs_walk | Lower legs and boots only below the coat hem, walking, six frames of one full stride, facing {DIR} |
| torso_idle | Torso, head, coat and human left arm only, no gun arm and no legs, standing, four frames of slow breathing with slight coat sway, facing {DIR} |
| torso_walk | Same torso layer walking, six frames, shoulders bobbing, coat hem swinging, facing {DIR} |
| torso_throw | Same torso layer, four frames: left hand winds up, throws a small metal noise-maker canister, follows through, recovers, facing {DIR} |
| torso_hurt | Same torso layer, two frames: violent flinch backwards, then recovering, facing {DIR} |
| gunarm | Only his right gun arm with its shoulder mount and fused flesh, no body, pointing {ANGLE} degrees clockwise from east (screen space, top-down), four frames: rest, firing kick with cores flaring, recoil pulled back, settling |
| gunarm_glow | Same gun arm frames, only the glowing red-orange cores and vents on black, everything else removed |
| muzzle_flash | Small harsh orange-white muzzle flash and sparks only, three frames: burst, flare, fade, pointing {ANGLE} degrees |
| muzzle_flash_shotgun | Wide cone-shaped shotgun muzzle blast and smoke, three frames, pointing {ANGLE} degrees |
| roll | Whole character in a fast combat dodge roll heading {DIR}, six frames, coat wrapping the body, gun arm tucked on his right side |
| death | Whole character collapsing, eight frames: hit, knees buckle, falls, lies broken and still with the gun arm's glow dying, facing {DIR4} |
| shadow | Plain dark oval ground shadow, top-down, hard dithered edge |

`{DIR}` = east, south-east, south, south-west, west, north-west, north, north-east (sheet row order).
`{DIR4}` = east, south, west, north. `{ANGLE}` = 11.25, 33.75, 56.25, ... 348.75 (row k: 11.25 + 22.5 k).

## Acceptance checklist
- [ ] `check_sheet.py` passes for every delivered sheet.
- [ ] Turnaround reads as the approved character at 1x zoom on a dark tile (silhouette, coat, gun arm).
- [ ] The gun is on his right arm in all 8 directions and 16 angles; no mirrored rows.
- [ ] Gun arm rows line up with the torso's right shoulder (orange dot) in all 16 rows.
- [ ] Torso rows 6–13 are complete behind the gun; rows 14, 15, 0–5 take the arm in front.
- [ ] Legs and torso walk frames are in phase (contact frames match).
- [ ] Feet on the pivot row in every standing frame; roll and death stay inside the frame.
- [ ] Palette only, 1 px outline, no anti-aliasing.

## Render resolution (done 2026-10-24, HANDOFF step 61)
`display/window/stretch/mode = "canvas_items"` (was "viewport"), base size still 480 x 270, integer
scale, `gui/fonts/dynamic_fonts/use_oversampling = false`. The game is laid out in 480 x 270 (world
framing, HUD, menus unchanged) but drawn at the window's integer multiple: 1920 x 1080 at 1080p
(1 art px = 2 x 2 screen px), exactly 960 x 540 in a 1280 x 720 window (1 art px = 1 screen px).
Measured: 799 / 799 art pixels of a test frame drawn exactly at every sub-pixel position (was
197–201 / 799 at 480 x 270). Windows smaller than 960 x 540 fall back to x1 and lose art pixels again.
The earlier plan here (960 x 540 + `window/stretch/scale = 2`) was wrong: Godot divides the render
size by that factor, so it still renders 480 x 270. Comparison screenshots: `render_check/`.

"""Extracts the four "Torso Idle - South" frames from `Amortia_ Torso Idle Sprite Sheet.png`
(repo root) into art_src/forsaken_scientist/extracted/torso_south/. One direction only (S).

python -I art_src/forsaken_scientist/scripts/extract_torso_south.py

- Background, labels, logo and their dark halo plates are removed with the source alpha
  (figure 250..253, background 0..3): alpha >= 128, biggest connected piece per frame.
- All four frames use ONE scale, so nothing is stretched per frame.
- Frames are registered on the belt buckle (the body's base, which should not move while
  breathing), not re-centred on their own bounding boxes, so the real motion is kept.
- Frame 0's head top sits on the head-top guide (y 24); x centres the belt buckle on the pivot.
- Downscale: premultiplied area average, then palette_forsaken + hard alpha (snap_to_palette).
"""
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from snap_to_palette import snap  # noqa: E402
import spec  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
SOURCE = os.path.join(ROOT, "art_src", "forsaken_scientist", "reference", "Amortia_ Torso Idle Sprite Sheet.png")
OUT = os.path.join(ROOT, "art_src", "forsaken_scientist", "extracted", "torso_south")

# Source px -> art px. Head top 130 -> chin ~280 in frame 0 = 150 src px; 0.07 gives a 10.5 px
# head and ~28 px shoulders (MANIFEST: head 10-11 px, shoulders 24-28 px).
SCALE = 0.07
# Search windows (source px) holding one frame each, and the belt-buckle template in frame 0.
FRAME_BOXES = [(20, 100, 510, 705), (525, 100, 990, 705), (1015, 100, 1490, 705), (1500, 100, 1983, 705)]
BUCKLE = (215, 515, 40, 30)  # x, y, w, h in frame 0


def figure_mask(rgba: np.ndarray) -> np.ndarray:
    solid = rgba[..., 3] >= 128
    lab, n = ndimage.label(solid)
    if n == 0:
        return solid
    sizes = ndimage.sum(solid, lab, range(1, n + 1))
    return lab == (1 + int(np.argmax(sizes)))


def find_buckle(lum: np.ndarray, template: np.ndarray, guess: tuple) -> tuple:
    """Best match of the buckle template within +-40 px of `guess` (absolute source coords)."""
    th, tw = template.shape
    gx, gy = guess
    best = (1e18, gx, gy)
    for y in range(gy - 40, gy + 41):
        for x in range(gx - 40, gx + 41):
            d = np.abs(lum[y:y + th, x:x + tw] - template).mean()
            if d < best[0]:
                best = (d, x, y)
    return best[1], best[2]


def downscale(rgba: np.ndarray, size: tuple) -> Image.Image:
    arr = rgba.astype(float)
    arr[..., :3] *= arr[..., 3:4] / 255.0
    small = np.asarray(Image.fromarray(arr.clip(0, 255).astype(np.uint8), "RGBA").resize(size, Image.BOX)).astype(float)
    a = small[..., 3:4]
    small[..., :3] = np.where(a > 0, small[..., :3] * 255.0 / np.maximum(a, 1), 0)
    return snap(Image.fromarray(small.clip(0, 255).astype(np.uint8), "RGBA"))


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    src = np.asarray(Image.open(SOURCE).convert("RGBA"))
    lum = src[..., :3].astype(float).mean(axis=2)
    bx, by, bw, bh = BUCKLE
    template = lum[by:by + bh, bx:bx + bw]
    first = FRAME_BOXES[0]

    frames = []
    anchor = None  # (art x, art y) of frame 0's buckle inside its 80x80 frame
    for i, (x0, y0, x1, y1) in enumerate(FRAME_BOXES):
        buckle = (bx, by) if i == 0 else find_buckle(lum, template, (bx + x0 - first[0] - 20, by))
        cell = src[y0:y1, x0:x1].copy()
        mask = figure_mask(cell)
        cell[..., 3] = np.where(mask, 255, 0)
        cell[~mask, :3] = 0
        # Sub-pixel registration: shift the cell so the buckle lands on the same art pixel in every
        # frame, by padding before the downscale (shift in source px = whole art px x 1/SCALE).
        local_bx, local_by = buckle[0] - x0, buckle[1] - y0
        if anchor is None:
            ys, xs = np.nonzero(mask)
            head_top = ys.min()
            # Art position of the buckle: head top on the guide, buckle centre on the pivot column.
            anchor = (spec.PIVOT[0] - (bw * SCALE) / 2.0, spec.HEAD_TOP_Y + (local_by - head_top) * SCALE)
        # Where the cell's top-left must go (art px) so its buckle lands on the anchor.
        ox = anchor[0] - local_bx * SCALE
        oy = anchor[1] - local_by * SCALE
        # Integer art offset + the fractional part folded into source padding.
        ix, iy = int(np.floor(ox)), int(np.floor(oy))
        pad_x, pad_y = int(round((ox - ix) / SCALE)), int(round((oy - iy) / SCALE))
        padded = np.zeros((cell.shape[0] + pad_y, cell.shape[1] + pad_x, 4), np.uint8)
        padded[pad_y:, pad_x:] = cell
        size = (max(1, round(padded.shape[1] * SCALE)), max(1, round(padded.shape[0] * SCALE)))
        small = downscale(padded, size)
        frame = Image.new("RGBA", (spec.FRAME, spec.FRAME), (0, 0, 0, 0))
        frame.alpha_composite(small, (ix, iy))
        frames.append(frame)
        frame.save(os.path.join(OUT, f"torso_idle_S_{i}.png"))
        print(f"frame {i}: buckle at source {buckle}, figure bbox in frame {frame.getbbox()}")

    row = Image.new("RGBA", (spec.FRAME * 4, spec.FRAME), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        row.alpha_composite(f, (i * spec.FRAME, 0))
    # The four source redraws side by side (rejected as an idle loop, see STATUS.md). The real row,
    # scientist_torso_idle__S.png, is made from frame 0 by animate_torso_breath.py.
    row.save(os.path.join(OUT, "redraws_torso_idle_S_row.png"))

    # Previews (not game assets): over the guide on a dark ground tile, at art scale x4, and as the
    # current 480 x 270 game shows it (sprite scale 0.5, nearest filter) x8.
    guide = Image.open(os.path.join(ROOT, "art_src", "forsaken_scientist", "templates", "scientist_torso_idle_guide.png"))
    guide_row = guide.crop((0, 2 * spec.FRAME, 4 * spec.FRAME, 3 * spec.FRAME))
    ground = Image.new("RGBA", row.size, (30, 27, 27, 255))
    over = ground.copy()
    over.alpha_composite(row)
    with_guide = over.copy()
    with_guide.alpha_composite(guide_row)
    sheet = Image.new("RGBA", (row.width, row.height * 2), (0, 0, 0, 255))
    sheet.paste(with_guide, (0, 0))
    sheet.paste(over, (0, row.height))
    sheet.resize((sheet.width * 4, sheet.height * 4), Image.NEAREST).save(os.path.join(OUT, "preview_artscale_x4.png"))
    # Godot draws a 0.5-scaled sprite with nearest filtering: one source pixel of every 2 x 2 survives.
    game = over.resize((over.width // 2, over.height // 2), Image.NEAREST)
    game.resize((game.width * 8, game.height * 8), Image.NEAREST).save(os.path.join(OUT, "preview_gamescale_480x270_x8.png"))
    # Frame-to-frame flicker: pixels that change between consecutive frames (loop 0-1-2-3-0).
    a = [np.asarray(f) for f in frames]
    for i in range(4):
        j = (i + 1) % 4
        changed = (np.abs(a[i].astype(int) - a[j].astype(int)).sum(axis=2) > 0) & ((a[i][..., 3] > 0) | (a[j][..., 3] > 0))
        union = ((a[i][..., 3] > 0) | (a[j][..., 3] > 0)).sum()
        print(f"frame {i} -> {j}: {changed.sum()} of {union} figure pixels change ({100.0 * changed.sum() / union:.0f} %)")


if __name__ == "__main__":
    main()

"""Idle breathing for one torso direction, made by EDITING the validated master frame — no
redraw, no new colours, no whole-sprite scaling.

python -I art_src/forsaken_scientist/scripts/animate_torso_breath.py [master.png] [out_dir] [row] [chest_first-chest_last] [belt_row]
default: extracted/torso_south/torso_idle_S_0.png -> extracted/torso_south/, row S, chest 41-48, belt 49.
Other directions: pass that master's chest band (rows between collar and belt) and its belt row.

Technique (standard pixel-art idle): the block above a chest row (head, shoulders, collar, upper
chest, coat shoulders and lapels) moves up as one rigid piece, and the opened gap is filled by
repeating that chest row once, so the ribcage gains a row. Every original pixel keeps its exact
colour; it is only displaced. Rows from the belt down are never touched.

Sequence (rise in art px): 0 neutral, 1 slight inhale, 2 full inhale, 1 slight exhale.
The rows repeated are the chest rows most like their neighbours (least visible seam), chosen
automatically between the collar and the belt.
"""
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import spec  # noqa: E402

KIT = os.path.abspath(os.path.join(HERE, ".."))
# Chest band (art px rows) that may be repeated: below the collar, above the belt (S master).
CHEST_ROWS = range(41, 49)
# First row that must stay pixel-identical (the belt and everything below it).
BELT_ROW = 49
RISE = [0, 1, 2, 1]


def configure(chest: str, belt: str) -> None:
    global CHEST_ROWS, BELT_ROW
    first, last = (int(v) for v in chest.split("-"))
    CHEST_ROWS = range(first, last + 1)
    BELT_ROW = int(belt)
    assert 36 < first <= last < BELT_ROW, "chest rows must lie below the head check (row 36) and above the belt"


def seam_cost(img: np.ndarray, r: int) -> float:
    """How visible repeating row r would be: its difference from the rows above and below,
    over the pixels that are opaque in any of the three rows."""
    rows = img[r - 1:r + 2].astype(int)
    occ = (rows[..., 3] > 0).any(axis=0)
    if not occ.any():
        return 0.0
    up = np.abs(rows[1] - rows[0]).sum(axis=1)[occ]
    down = np.abs(rows[1] - rows[2]).sum(axis=1)[occ]
    return float((up + down).mean())


def raise_block(img: np.ndarray, r: int) -> np.ndarray:
    """Moves every row above r up by one and repeats row r into the gap (row r stays put)."""
    out = img.copy()
    out[:r - 1] = img[1:r]  # row k -> k-1 for k < r; old row r-1 lands on r-2
    out[r - 1] = img[r]     # the repeated chest row
    return out


def breathe(master: np.ndarray) -> list:
    costs = sorted((seam_cost(master, r), r) for r in CHEST_ROWS)
    # Two repeat rows, not neighbours, so full inhale doesn't show a three-row identical band.
    first = costs[0][1]
    second = next(r for _, r in costs[1:] if abs(r - first) > 1)
    frames = []
    for rise in RISE:
        img = master
        # Repeat the lower row first so the upper row's index is still valid afterwards.
        for r in sorted([first, second][:rise], reverse=True):
            img = raise_block(img, r)
        frames.append(img)
    return frames, (first, second), costs


def verify(master: np.ndarray, frames: list) -> list:
    problems = []
    colours = {tuple(c) for c in master[master[..., 3] > 0][:, :3]}
    for i, (img, rise) in enumerate(zip(frames, RISE)):
        if not np.array_equal(img[BELT_ROW:], master[BELT_ROW:]):
            problems.append(f"frame {i}: pixels changed at or below the belt (row {BELT_ROW})")
        if not np.isin(img[..., 3], (0, 255)).all():
            problems.append(f"frame {i}: soft alpha")
        new = {tuple(c) for c in img[img[..., 3] > 0][:, :3]} - colours
        if new:
            problems.append(f"frame {i}: {len(new)} colours not in the master")
        # The head (everything above the collar) must be the master's pixels, moved up by `rise`.
        head = slice(0, 36)
        if rise and not np.array_equal(img[head.start:head.stop - rise], master[head.start + rise:head.stop]):
            problems.append(f"frame {i}: head pixels differ from the master")
        if rise == 0 and not np.array_equal(img, master):
            problems.append("frame 0 is not the master")
    return problems


def main() -> None:
    master_path = sys.argv[1] if len(sys.argv) > 1 else os.path.join(KIT, "extracted", "torso_south", "torso_idle_S_0.png")
    out_dir = sys.argv[2] if len(sys.argv) > 2 else os.path.dirname(master_path)
    row_label = sys.argv[3] if len(sys.argv) > 3 else "S"
    if len(sys.argv) > 5:
        configure(sys.argv[4], sys.argv[5])
    master = np.asarray(Image.open(master_path).convert("RGBA")).copy()
    frames, rows, costs = breathe(master)
    print("seam cost per chest row:", ", ".join(f"y{r}={c:.0f}" for c, r in sorted(costs, key=lambda t: t[1])))
    print(f"repeated rows: y{rows[0]} (1 px), + y{rows[1]} (2 px)")
    problems = verify(master, frames)
    for p in problems:
        print("FAIL", p)
    if problems:
        sys.exit(1)
    strip = Image.new("RGBA", (spec.FRAME * 4, spec.FRAME), (0, 0, 0, 0))
    for i, img in enumerate(frames):
        im = Image.fromarray(img, "RGBA")
        im.save(os.path.join(out_dir, f"torso_idle_{row_label}_breath_{i}.png"))
        strip.alpha_composite(im, (i * spec.FRAME, 0))
    strip.save(os.path.join(out_dir, f"scientist_torso_idle__{row_label}.png"))
    # Previews: x8 frames on a dark tile, and a diff map (red = pixel differs from the master).
    ground = Image.new("RGBA", strip.size, (30, 27, 27, 255))
    ground.alpha_composite(strip)
    diff = ground.copy()
    px = diff.load()
    for i, img in enumerate(frames):
        changed = (np.abs(img.astype(int) - master.astype(int)).sum(axis=2) > 0)
        for y, x in zip(*np.nonzero(changed)):
            px[i * spec.FRAME + x, y] = (255, 0, 0, 255)
        print(f"frame {i} (rise {RISE[i]}): {int(changed.sum())} pixels differ from the master, none at or below row {BELT_ROW}")
    both = Image.new("RGBA", (strip.width, strip.height * 2))
    both.paste(ground, (0, 0))
    both.paste(diff, (0, strip.height))
    both.crop((0, 16, strip.width, strip.height * 2)).resize((strip.width * 6, (strip.height * 2 - 16) * 6), Image.NEAREST).save(
        os.path.join(out_dir, f"preview_breath_{row_label}_x6.png"))
    # Animated preview at the loop's timing (data/player_visual.tres idle_fps = 6).
    gif = [Image.alpha_composite(Image.new("RGBA", (80, 80), (30, 27, 27, 255)), Image.fromarray(f, "RGBA")).crop((16, 16, 68, 68)).resize((52 * 6, 52 * 6), Image.NEAREST) for f in frames]
    gif[0].save(os.path.join(out_dir, f"preview_breath_{row_label}.gif"), save_all=True, append_images=gif[1:], duration=1000 // 6, loop=0)


if __name__ == "__main__":
    main()

"""Checks a delivered sheet before it goes into entities/player/art/.

python -I art_src/forsaken_scientist/scripts/check_sheet.py entities/player/art/scientist_legs_walk.png
Fails on: wrong size, no alpha, semi-transparent pixels (anti-aliasing), colours outside the
palette, standing legs whose feet are not on the pivot row, and torso frames whose head top is
more than 3 px off the head-top guide.

One row delivered on its own (one direction / angle) is named <sheet>__<ROW>.png, e.g.
scientist_torso_idle__S.png or scientist_gunarm__4.png, and is checked as columns x 1.
"""
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from palette import PALETTE, rgb  # noqa: E402
import spec  # noqa: E402

STANDING = ("scientist_legs_idle", "scientist_legs_walk", "scientist_torso_idle", "scientist_torso_walk")


def check(path: str) -> list:
    name = os.path.splitext(os.path.basename(path))[0]
    single_row = "__" in name
    if single_row:
        name, row_label = name.split("__", 1)
        labels = spec.DIRS_4 if name == "scientist_death" else (
            [str(k) for k in range(16)] if spec.SHEETS.get(name, (0, 0))[1] == 16 else spec.DIRS_8)
        if name in spec.SHEETS and row_label not in labels:
            return [f"unknown row '{row_label}' for {name}, expected one of {labels}"]
    if name not in spec.SHEETS:
        return [f"unknown sheet name '{name}' (see spec.SHEETS)"]
    cols, rows, _required, _what = spec.SHEETS[name]
    if single_row:
        rows = 1
    img = Image.open(path)
    problems = []
    want = (cols * spec.FRAME, rows * spec.FRAME)
    if img.size != want:
        problems.append(f"size {img.size}, expected {want} ({cols} frames x {rows} rows of {spec.FRAME})")
    if img.mode != "RGBA":
        problems.append(f"mode {img.mode}, expected RGBA with transparency")
        img = img.convert("RGBA")
    allowed = {rgb(h) for _, h in PALETTE}
    off_palette = set()
    soft = 0
    pixels = img.get_flattened_data() if hasattr(img, "get_flattened_data") else img.getdata()
    for r, g, b, a in pixels:
        if a == 0:
            continue
        if a != 255:
            soft += 1
        if (r, g, b) not in allowed:
            off_palette.add((r, g, b))
    if soft:
        problems.append(f"{soft} semi-transparent pixels (no anti-aliasing: alpha must be 0 or 255)")
    if off_palette and not name.startswith("fx_"):
        problems.append(f"{len(off_palette)} colours outside palette_forsaken, e.g. {sorted(off_palette)[:4]}")
    if name in STANDING and not problems:
        alpha = img.getchannel("A")
        for r in range(rows):
            for c in range(cols):
                box = alpha.crop((c * spec.FRAME, r * spec.FRAME, (c + 1) * spec.FRAME, (r + 1) * spec.FRAME)).getbbox()
                if box is None:
                    problems.append(f"frame ({c},{r}) is empty")
                    continue
                if name.startswith("scientist_legs") and abs((box[3] - 1) - spec.PIVOT[1]) > 2:
                    problems.append(f"frame ({c},{r}) feet end at y={box[3] - 1}, pivot row is {spec.PIVOT[1]}")
                if name.startswith("scientist_torso") and abs(box[1] - spec.HEAD_TOP_Y) > 3:
                    problems.append(f"frame ({c},{r}) head top at y={box[1]}, guide is {spec.HEAD_TOP_Y}")
    return problems


if __name__ == "__main__":
    failed = False
    for p in sys.argv[1:]:
        found = check(p)
        print(("OK   " if not found else "FAIL ") + p)
        for line in found:
            print("     - " + line)
        failed = failed or bool(found)
    sys.exit(1 if failed else 0)

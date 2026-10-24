"""Deadline player sprite: four static full-body poses (E, S, W, N) from the generated board's
turnaround -> entities/player/art/scientist_simple_poses.png (4 x 80x80, feet on the pivot).

python -I art_src/forsaken_scientist/scripts/build_simple_poses.py

E = board "E" mirrored (the board drew it facing left with the gun on his LEFT arm; mirrored it
faces right with the gun on his RIGHT arm). S = board "S". W = board "SW" (faces down-left, gun
hidden behind him, which is right for a left-facing pose). N = board "N" (back view).
The board's painted floor shadow is removed; the game draws its own ground shadow.
"""
import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from extract_board import BOARD  # noqa: E402
from extract_torso_turnaround import frame_for  # noqa: E402
import spec  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
OUT = os.path.join(ROOT, "entities", "player", "art", "scientist_simple_poses.png")
POSES = [("E", "E", True), ("S", "S", False), ("W", "SW", False), ("N", "N", False)]
SHADOW_LUM = 22  # painted floor shadow is darker than this; boot outlines sit inside the feet


def strip_floor_shadow(frame: Image.Image) -> Image.Image:
    arr = np.asarray(frame).copy()
    a = arr[..., 3] > 0
    lum = arr[..., :3].astype(int).mean(axis=2)
    # Everything below the soles row is shadow.
    arr[spec.PIVOT[1] + 1:] = 0
    # Around the feet: a dark pixel stays only if a lit (boot / trouser) pixel is within 2 px;
    # the painted shadow is a wide dark pool with nothing lit inside it.
    top = spec.PIVOT[1] - 10
    lit = a & (lum >= SHADOW_LUM)
    for y in range(top, spec.PIVOT[1] + 1):
        for x in range(spec.FRAME):
            if a[y, x] and lum[y, x] < SHADOW_LUM:
                near = lit[max(0, y - 2):y + 3, max(0, x - 2):x + 3]
                if not near.any():
                    arr[y, x] = 0
    return Image.fromarray(arr, "RGBA")


def main() -> None:
    board = Image.open(BOARD).convert("RGBA")
    flat = Image.new("RGBA", board.size, (16, 16, 15, 255))
    flat.alpha_composite(board)
    board = flat.convert("RGB")
    sheet = Image.new("RGBA", (spec.FRAME * len(POSES), spec.FRAME), (0, 0, 0, 0))
    for i, (_dir, cell, mirror) in enumerate(POSES):
        frame = strip_floor_shadow(frame_for(board, cell))
        if mirror:
            # Mirror around the pivot column (x 40), not the frame centre.
            arr = np.asarray(frame)
            flipped = np.zeros_like(arr)
            for x in range(spec.FRAME):
                mx = 2 * spec.PIVOT[0] - x
                if 0 <= mx < spec.FRAME:
                    flipped[:, mx] = arr[:, x]
            frame = Image.fromarray(flipped, "RGBA")
        sheet.alpha_composite(frame, (i * spec.FRAME, 0))
        print(f"{_dir} (board {cell}{', mirrored' if mirror else ''}): bbox {frame.getbbox()}")
    sheet.save(OUT)
    print("wrote", OUT)


if __name__ == "__main__":
    main()

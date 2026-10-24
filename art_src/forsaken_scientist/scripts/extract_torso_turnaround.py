"""Torso candidates for directions other than S, cut from the generated board's turnaround
(3b2bb3fb-30bb-4bd7-8dea-1a0152edb45d.png). Kept as evidence: on 2026-10-24 NO candidate was good
enough to become a master (see extracted/torso_turnaround/STATUS.md). Outputs are named
candidate_* / inspect_* and are never used by the game or by the sheet builder.

python -I art_src/forsaken_scientist/scripts/extract_torso_turnaround.py

- One source scale for every board pose (0.39, fitted: the board S head matches the S master's
  head at IoU 0.88), so head and body sizes agree with the S master.
- Feet-aligned: soles (lowest non-shadow row) on the pivot row y 72, feet centre on x 40.
- Torso layer = everything above the cut row (the S master's lowest row, 62: mid-thigh); the
  rest belongs to the future legs layer. The board's painted floor shadow reaches above that row
  on SW (dark slab at the bottom of the candidate) - one of the reasons it was rejected.
- Palette-snapped with hard alpha (same downscale as the S master).
"""
import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from extract_board import BOARD, TURN_CELLS, TURN_LABELS, cut_figure  # noqa: E402
from extract_torso_south import downscale  # noqa: E402
import spec  # noqa: E402

KIT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
OUT = os.path.join(KIT, "extracted", "torso_turnaround")
SCALE = 0.39
CUT_ROW = 62  # last torso row (S master ends here)
# Board cell -> game direction it really shows, for cells whose torso is complete without the gun
# (the gun is hidden behind him). Extracted as candidates; rejected on quality (STATUS.md).
CANDIDATES = {"SW": "SW"}
# Extracted for inspection only (gun arm overlaps the torso; not a master).
INSPECT = {"N": "back view", "W": "back view", "NW": "back view"}


def soles_and_centre(fig: Image.Image) -> tuple:
    arr = np.asarray(fig).astype(int)
    a = arr[..., 3] > 0
    lum = arr[..., :3].mean(axis=2)
    real = a & (lum > 32)  # the painted floor shadow is darker than any boot pixel
    rows = [y for y in range(a.shape[0]) if real[y].sum() >= 2]
    soles = rows[-1]
    feet = np.nonzero(real[max(0, soles - 6):soles + 1])[1]
    return soles, float(feet.mean())


def frame_for(board: Image.Image, label: str) -> Image.Image:
    fig = cut_figure(board, TURN_CELLS[TURN_LABELS.index(label)])
    soles, cx = soles_and_centre(fig)
    # Offset (art px) of the figure's top-left so the soles land on the pivot row, feet on x 40.
    ox = spec.PIVOT[0] - (cx + 0.5) * SCALE
    oy = spec.PIVOT[1] + 1 - (soles + 1) * SCALE
    ix, iy = int(np.floor(ox)), int(np.floor(oy))
    pad_x, pad_y = int(round((ox - ix) / SCALE)), int(round((oy - iy) / SCALE))
    src = np.asarray(fig)
    padded = np.zeros((src.shape[0] + pad_y, src.shape[1] + pad_x, 4), np.uint8)
    padded[pad_y:, pad_x:] = src
    small = downscale(padded, (max(1, round(padded.shape[1] * SCALE)), max(1, round(padded.shape[0] * SCALE))))
    frame = Image.new("RGBA", (spec.FRAME, spec.FRAME), (0, 0, 0, 0))
    frame.alpha_composite(small, (ix, iy))
    return frame


def torso_only(frame: Image.Image) -> Image.Image:
    arr = np.asarray(frame).copy()
    arr[CUT_ROW + 1:] = 0
    return Image.fromarray(arr, "RGBA")


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    board = Image.open(BOARD).convert("RGBA")
    flat = Image.new("RGBA", board.size, (16, 16, 15, 255))
    flat.alpha_composite(board)
    board = flat.convert("RGB")
    for label, direction in CANDIDATES.items():
        full = frame_for(board, label)
        full.save(os.path.join(OUT, f"candidate_fullbody_{direction}.png"))
        torso = torso_only(full)
        torso.save(os.path.join(OUT, f"candidate_torso_{direction}_REJECTED.png"))
        print(f"{direction}: candidate torso bbox {torso.getbbox()}, full-body bbox {full.getbbox()}")
    for label, what in INSPECT.items():
        full = frame_for(board, label)
        full.save(os.path.join(OUT, f"inspect_board_{label}_{what.replace(' ', '_')}.png"))


if __name__ == "__main__":
    main()

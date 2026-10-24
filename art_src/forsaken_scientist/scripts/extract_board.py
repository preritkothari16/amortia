"""Extracts the genuinely usable parts of the generated pixel-art reference board
(3b2bb3fb-30bb-4bd7-8dea-1a0152edb45d.png, art_src/forsaken_scientist/reference) into art_src/forsaken_scientist/extracted/.
See BOARD_AUDIT.md for what the board does and does not contain.

python -I art_src/forsaken_scientist/scripts/extract_board.py

Outputs are REFERENCE material: the turnaround is one static, un-layered pose per direction, so
it is not a legs / torso / gun-arm sheet and is never assigned to data/player_visual.tres.
"""
import os
import sys

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from palette import PALETTE, rgb  # noqa: E402
from snap_to_palette import snap  # noqa: E402
import spec  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
BOARD = os.path.join(ROOT, "art_src", "forsaken_scientist", "reference", "3b2bb3fb-30bb-4bd7-8dea-1a0152edb45d.png")
OUT = os.path.join(ROOT, "art_src", "forsaken_scientist", "extracted")

# Board regions (board pixels), measured from the 1536 x 1024 board.
TURN_CELLS = [(312, 46, 408, 200), (412, 46, 500, 200), (504, 46, 590, 200), (594, 46, 680, 200),
              (684, 46, 774, 200), (778, 46, 864, 200), (868, 46, 956, 200), (960, 46, 1048, 200)]
TURN_LABELS = ["E", "SE", "S", "SW", "W", "NW", "N", "NE"]
PORTRAIT = (1135, 47, 1333, 245)
# Pistol flash: row 0, three columns (the 16 rows repeat the same non-directional burst).
FLASH_CELLS = [(1155, 524, 1205, 548), (1205, 524, 1255, 548), (1255, 524, 1310, 548)]
# Shotgun flash: row 0, two columns only, drawn pointing east.
SHOTGUN_CELLS = [(1365, 524, 1425, 548), (1428, 524, 1515, 548)]

# Colour distance from the cell background still counted as background.
BACKGROUND_TOLERANCE = 7.0
# Standing figure height in art px (head top 24 -> feet 72).
FIGURE_HEIGHT = spec.PIVOT[1] - spec.HEAD_TOP_Y


def cut_figure(board: Image.Image, box: tuple) -> Image.Image:
    """Removes the cell background by flood-filling from the cell border (so dark hair and boots
    inside the silhouette are kept), then crops to the figure."""
    cell = np.asarray(board.crop(box).convert("RGB")).astype(int)
    # The cell background is a flat near-black (~15) with little noise; his outlines are darker
    # (0..9) and everything else lighter, so a tight colour match flood-filled from the border
    # stops at the outline and keeps dark hair, boots and gun metal.
    edge = np.concatenate([cell[0], cell[-1], cell[:, 0], cell[:, -1]])
    distance = np.sqrt(((cell - np.median(edge, axis=0)) ** 2).sum(axis=2))
    background = distance < BACKGROUND_TOLERANCE
    labels, _ = ndimage.label(background)
    border = set(np.unique(np.concatenate([labels[0], labels[-1], labels[:, 0], labels[:, -1]]))) - {0}
    outside = np.isin(labels, list(border))
    # The painted floor shadow under the feet is part of the background on the board.
    figure = ~outside
    figure = ndimage.binary_opening(figure, iterations=1)
    lab, n = ndimage.label(figure)
    if n > 1:  # keep the biggest piece (drops stray specks)
        sizes = ndimage.sum(figure, lab, range(1, n + 1))
        figure = lab == (1 + int(np.argmax(sizes)))
    rgba = np.dstack([cell, figure * 255]).astype(np.uint8)
    img = Image.fromarray(rgba, "RGBA")
    return img.crop(img.getbbox())


def to_frame(figure: Image.Image) -> Image.Image:
    """Scales a cut-out figure to the 48 px game height and stands its feet on the pivot."""
    scale = FIGURE_HEIGHT / figure.height
    w = max(1, round(figure.width * scale))
    # Premultiplied area average, then hard alpha + palette snap (no soft edges survive).
    arr = np.asarray(figure).astype(float)
    arr[..., :3] *= arr[..., 3:4] / 255.0
    small = Image.fromarray(arr.astype(np.uint8), "RGBA").resize((w, FIGURE_HEIGHT), Image.BOX)
    sarr = np.asarray(small).astype(float)
    a = sarr[..., 3:4]
    sarr[..., :3] = np.where(a > 0, sarr[..., :3] * 255.0 / np.maximum(a, 1), 0)
    small = snap(Image.fromarray(sarr.clip(0, 255).astype(np.uint8), "RGBA"))
    frame = Image.new("RGBA", (spec.FRAME, spec.FRAME), (0, 0, 0, 0))
    frame.alpha_composite(small, (spec.PIVOT[0] - w // 2, spec.PIVOT[1] - FIGURE_HEIGHT))
    return frame


def cut_glow(board: Image.Image, box: tuple) -> Image.Image:
    """Emissive flash on black: keeps pixels bright enough to read, hard alpha."""
    cell = board.crop(box).convert("RGB")
    lum = np.asarray(cell).astype(int).max(axis=2)
    alpha = np.where(lum > 90, 255, 0).astype(np.uint8)
    img = cell.convert("RGBA")
    img.putalpha(Image.fromarray(alpha))
    return img.crop(img.getbbox()) if img.getbbox() else img


def validate(img: Image.Image, name: str, palette_only: bool = True) -> list:
    allowed = {rgb(h) for _, h in PALETTE}
    data = np.asarray(img.convert("RGBA"))
    a = data[..., 3]
    problems = []
    if not np.isin(a, (0, 255)).all():
        problems.append("soft alpha")
    if palette_only:
        opaque = data[a == 255][:, :3]
        off = {tuple(c) for c in opaque} - allowed
        if off:
            problems.append(f"{len(off)} off-palette colours")
    print(("OK   " if not problems else "FAIL ") + name + ("" if not problems else ": " + ", ".join(problems)))
    return problems


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    board = Image.open(BOARD).convert("RGBA")
    # Flatten the board's noisy alpha (13..253 everywhere) onto its own dark background first.
    flat = Image.new("RGBA", board.size, (16, 16, 15, 255))
    flat.alpha_composite(board)
    board = flat.convert("RGB")

    # 1. Portrait (board label "96 x 96"), palette-snapped.
    head = board.crop(PORTRAIT)
    for size in (96, 64):
        p = snap(head.resize((size, size), Image.LANCZOS))
        p.putalpha(255)
        p.save(os.path.join(OUT, f"board_portrait_{size}.png"))
        validate(p, f"board_portrait_{size}.png")

    # 2. Turnaround reference at game scale: 8 x 1 frames of 80 x 80, feet on the pivot.
    sheet = Image.new("RGBA", (spec.FRAME * 8, spec.FRAME), (0, 0, 0, 0))
    for i, box in enumerate(TURN_CELLS):
        sheet.alpha_composite(to_frame(cut_figure(board, box)), (i * spec.FRAME, 0))
    sheet.save(os.path.join(OUT, "board_turnaround_80.png"))
    validate(sheet, "board_turnaround_80.png")
    # Preview: on a dark ground tile at 1x (gameplay: 0.5 -> shown here at art scale) and x4.
    preview = Image.new("RGBA", sheet.size, (34, 30, 30, 255))
    preview.alpha_composite(sheet)
    d = ImageDraw.Draw(preview)
    for i, label in enumerate(TURN_LABELS):
        d.text((i * spec.FRAME + 3, 2), label, fill=(200, 200, 200, 255))
    preview.resize((sheet.width * 3, sheet.height * 3), Image.NEAREST).save(os.path.join(OUT, "board_turnaround_preview_x3.png"))
    game = preview.resize((sheet.width // 2, sheet.height // 2), Image.NEAREST)
    game.resize((game.width * 4, game.height * 4), Image.NEAREST).save(os.path.join(OUT, "board_turnaround_gamescale_x4.png"))

    # 3. Muzzle flash cut-outs (native board size; fx may use any colour).
    for name, cells in (("flash_pistol", FLASH_CELLS), ("flash_shotgun_east", SHOTGUN_CELLS)):
        for i, box in enumerate(cells):
            g = cut_glow(board, box)
            g.save(os.path.join(OUT, f"{name}_{i}.png"))
            validate(g, f"{name}_{i}.png", palette_only=False)


if __name__ == "__main__":
    main()

"""Builds the Forsaken Scientist art kit: palette files, per-sheet guide templates and the
HUD portrait (converted from the approved concept's neutral head study).

Run from the repo root:  python -I art_src/forsaken_scientist/scripts/build_kit.py
Guides are reference layers for the artist, NOT character art; they never go into the game.
"""
import math
import os
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from palette import PALETTE, rgb  # noqa: E402
import spec  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
KIT = os.path.join(ROOT, "art_src", "forsaken_scientist")
REFERENCE = os.path.join(ROOT, "art_src", "forsaken_scientist", "reference", "Amortia_ The Forsaken Scientist.png")
RUNTIME_ART = os.path.join(ROOT, "entities", "player", "art")

GRID = (0, 200, 255, 70)
PIVOT = (255, 0, 255, 255)
FOOTPRINT = (255, 220, 0, 160)
HEIGHTS = (120, 255, 120, 90)
SHOULDER = (255, 140, 0, 255)
AIM = (255, 60, 60, 200)
MUZZLE = (255, 255, 255, 255)


def write_palette() -> None:
    with open(os.path.join(KIT, "palette_forsaken.gpl"), "w", newline="\n") as f:
        f.write("GIMP Palette\nName: Amortia Forsaken Scientist\nColumns: 8\n#\n")
        for name, hex_value in PALETTE:
            r, g, b = rgb(hex_value)
            f.write(f"{r:3d} {g:3d} {b:3d}\t{name}\n")
    # 1 px per colour (Aseprite / Pixelorama "load palette from image") and an 8x zoomed swatch.
    strip = Image.new("RGB", (len(PALETTE), 1))
    for i, (_, hex_value) in enumerate(PALETTE):
        strip.putpixel((i, 0), rgb(hex_value))
    strip.save(os.path.join(KIT, "palette_forsaken.png"))
    strip.resize((len(PALETTE) * 8, 8), Image.NEAREST).save(os.path.join(KIT, "palette_forsaken_x8.png"))


def facing_angle(sheet: str, row: int) -> float:
    if sheet == "scientist_death":
        return math.radians(90.0 * row)
    if sheet.startswith("scientist_gunarm") or sheet.startswith("fx_muzzle"):
        return math.radians(spec.ARM_ANGLES[row])
    return math.radians(45.0 * row)


def right_shoulder(angle: float) -> tuple:
    # His right side is the facing rotated +90 deg (y down). Depth is squashed by half in 3/4 view.
    side = angle + math.pi / 2.0
    return (spec.PIVOT[0] + math.cos(side) * spec.SHOULDER_HALF_WIDTH,
            spec.SHOULDER_Y + math.sin(side) * spec.SHOULDER_HALF_WIDTH * 0.5)


def draw_cell(d: ImageDraw.ImageDraw, ox: int, oy: int, sheet: str, row: int) -> None:
    f = spec.FRAME
    px, py = ox + spec.PIVOT[0], oy + spec.PIVOT[1]
    d.rectangle((ox, oy, ox + f - 1, oy + f - 1), outline=GRID)
    if sheet != "scientist_shadow":
        for y in (spec.HEAD_TOP_Y, spec.CHIN_Y, spec.HEM_Y):
            d.line((ox + 20, oy + y, ox + 60, oy + y), fill=HEIGHTS)
    # Collision footprint: radius 6 world px = 12 art px, squashed to an ellipse on the ground.
    d.ellipse((px - 12, py - 6, px + 12, py + 6), outline=FOOTPRINT)
    angle = facing_angle(sheet, row)
    if sheet.startswith("scientist_gunarm") or sheet.startswith("fx_muzzle"):
        sx, sy = right_shoulder(angle)
        d.line((ox + sx, oy + sy, ox + sx + math.cos(angle) * spec.BARREL_ART_PX,
                oy + sy + math.sin(angle) * spec.BARREL_ART_PX), fill=AIM)
        d.point((ox + round(sx), oy + round(sy)), fill=SHOULDER)
        # Where bullets really spawn (ground level) - for lining up the flash and recoil only.
        # For south-facing rows it lies below the frame, so it is only drawn when inside the cell.
        mx = px + round(math.cos(angle) * spec.MUZZLE_ART_PX)
        my = py + round(math.sin(angle) * spec.MUZZLE_ART_PX)
        if ox <= mx < ox + f and oy <= my < oy + f:
            d.point((mx, my), fill=MUZZLE)
    elif sheet not in ("scientist_shadow", "scientist_death"):
        sx, sy = right_shoulder(angle)
        d.point((ox + round(sx), oy + round(sy)), fill=SHOULDER)
        d.line((px, py, px + math.cos(angle) * 10, py + math.sin(angle) * 5), fill=AIM)
    d.line((px - 3, py, px + 3, py), fill=PIVOT)
    d.line((px, py - 3, px, py + 3), fill=PIVOT)


def write_guides() -> None:
    out = os.path.join(KIT, "templates")
    os.makedirs(out, exist_ok=True)
    for sheet, (cols, rows, _required, _what) in spec.SHEETS.items():
        img = Image.new("RGBA", (cols * spec.FRAME, rows * spec.FRAME), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)
        for r in range(rows):
            for c in range(cols):
                draw_cell(d, c * spec.FRAME, r * spec.FRAME, sheet, r)
        img.save(os.path.join(out, f"{sheet}_guide.png"))


def write_portrait() -> None:
    src = Image.open(REFERENCE).convert("RGB")
    pal = Image.new("P", (1, 1))
    flat = [c for _, h in PALETTE for c in rgb(h)]
    pal.putpalette(flat + flat[:3] * (256 - len(PALETTE)))  # pad with the outline colour, never pure black
    # The NEUTRAL head study (top-left of HEAD DETAILS), hair to collar.
    head = src.crop((583, 72, 737, 226))
    for size in (96, 64):
        small = head.resize((size, size), Image.LANCZOS)
        small.quantize(palette=pal, dither=Image.Dither.NONE).convert("RGBA").save(
            os.path.join(RUNTIME_ART, f"scientist_portrait_{size}.png"))


if __name__ == "__main__":
    os.makedirs(RUNTIME_ART, exist_ok=True)
    write_palette()
    write_guides()
    write_portrait()
    print("kit written to", KIT)

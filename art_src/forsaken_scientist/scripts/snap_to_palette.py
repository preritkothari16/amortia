"""First cleanup pass for generated or painted frames: snaps an image to palette_forsaken with
hard alpha (no anti-aliasing). It does NOT make finished pixel art - hand cleanup of every frame
(outlines, clusters, silhouette, pivot) still follows in Aseprite / Pixelorama.

python -I art_src/forsaken_scientist/scripts/snap_to_palette.py in.png out.png [--size W H]
--size resizes with nearest-neighbour first (use it only on images already near pixel scale).
"""
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from palette import PALETTE, rgb  # noqa: E402


def snap(src: Image.Image) -> Image.Image:
    src = src.convert("RGBA")
    pal = Image.new("P", (1, 1))
    flat = [c for _, h in PALETTE for c in rgb(h)]
    pal.putpalette(flat + flat[:3] * (256 - len(PALETTE)))  # pad with the outline colour, never pure black
    colour = src.convert("RGB").quantize(palette=pal, dither=Image.Dither.NONE).convert("RGBA")
    alpha = src.getchannel("A").point(lambda a: 255 if a >= 128 else 0)
    colour.putalpha(alpha)
    return colour


if __name__ == "__main__":
    args = sys.argv[1:]
    image = Image.open(args[0])
    if "--size" in args:
        i = args.index("--size")
        image = image.resize((int(args[i + 1]), int(args[i + 2])), Image.NEAREST)
    snap(image).save(args[1])

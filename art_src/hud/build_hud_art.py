"""HUD art for the in-game HUD (steps 67-71; the portrait was removed in step 71). Two sources:

1. Cut from the approved HUD reference (repo root `art_srcreferencesamortia_hud.png.png`, the
   upload lost its path separators): heart, skull, noise-maker (the grenade) and sample vial (the
   virus vial). The reference is a smooth mock-up, so each cut is keyed off its dark slot background
   and resampled to the HUD's 2x art density (1 HUD px = 2 texture px).
2. Drawn here, in the reference's colours, for things the reference does not show but Amortia has:
   pistol, shotgun, scrap and the dodge badge. (Power-up icons: art_src/powerups/.) Shapes are drawn 8x larger
   and box-filtered down to 2x, which gives the same soft-edged look as the mock-up.

python -I art_src/hud/build_hud_art.py
-> ui/hud/art/*.png
"""
import os

from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
REF = os.path.join(ROOT, "art_srcreferencesamortia_hud.png.png")
OUT = os.path.join(ROOT, "ui", "hud", "art")

BG = (9, 14, 19)          # panel / slot background in the reference
OUTLINE = (6, 7, 9)
STEEL_D = (38, 36, 34)
STEEL = (72, 68, 62)
STEEL_L = (122, 114, 100)
STEEL_H = (168, 158, 138)
WOOD_D = (52, 34, 22)
WOOD = (92, 62, 38)
WOOD_L = (132, 92, 56)

HI = 8  # supersampling factor for drawn art


def key_cut(img, box, size):
    """Crops `box` from the reference, makes the dark background transparent (soft key) and
    resamples to `size` (2x art)."""
    cut = img.crop(box).convert("RGBA")
    px = cut.load()
    for y in range(cut.height):
        for x in range(cut.width):
            r, g, b, _ = px[x, y]
            d = max(abs(r - BG[0]), abs(g - BG[1]), abs(b - BG[2]))
            a = max(0, min(255, (d - 10) * 255 // 26))
            px[x, y] = (r, g, b, a)
    return cut.resize(size, Image.LANCZOS)


class Canvas:
    """Draws in HUD-pixel coordinates on a supersampled image; `done()` returns the 2x texture."""

    def __init__(self, w, h):
        self.w, self.h = w, h
        self.img = Image.new("RGBA", (w * 2 * HI, h * 2 * HI), (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.img)

    def _p(self, pts):
        return [(x * 2 * HI, y * 2 * HI) for x, y in pts]

    def poly(self, pts, colour):
        self.d.polygon(self._p(pts), fill=colour)

    def rect(self, x0, y0, x1, y1, colour):
        self.poly([(x0, y0), (x1, y0), (x1, y1), (x0, y1)], colour)

    def ellipse(self, x0, y0, x1, y1, colour, width=0):
        box = self._p([(x0, y0), (x1, y1)])
        if width:
            self.d.ellipse(box, outline=colour, width=int(width * 2 * HI))
        else:
            self.d.ellipse(box, fill=colour)

    def line(self, pts, colour, width):
        self.d.line(self._p(pts), fill=colour, width=int(width * 2 * HI), joint="curve")

    def done(self, outline=True):
        img = self.img
        if outline:  # dark rim like the reference icons: grow the alpha by 1 texture px
            alpha = img.getchannel("A").point(lambda a: 255 if a > 40 else 0)
            grown = alpha.filter(ImageFilter.MaxFilter(2 * HI + 1))
            rim = Image.new("RGBA", img.size, OUTLINE + (0,))
            rim.putalpha(grown)
            img = Image.alpha_composite(rim, img)
        return img.resize((self.w * 2, self.h * 2), Image.BOX)


def pistol():
    c = Canvas(30, 15)
    c.poly([(7, 8), (13, 8), (12.5, 14), (5.5, 14), (5, 12.5)], WOOD_D)           # grip
    c.poly([(7.6, 8.6), (12, 8.6), (11.6, 13.2), (8, 13.2)], WOOD)
    for y in (9.6, 10.8, 12):                                                       # grip checkering
        c.line([(8.2, y), (11.4, y)], WOOD_L, 0.35)
    c.line([(13, 8.2), (13.4, 10.8), (17.4, 10.8), (17.6, 8.2)], STEEL, 0.7)       # trigger guard
    c.line([(15, 8.4), (14.6, 10)], STEEL_L, 0.5)                                  # trigger
    c.rect(6, 6.2, 25, 8.6, STEEL_D)                                               # frame
    c.rect(4, 2, 28, 6.4, STEEL)                                                   # slide
    c.rect(4, 2, 28, 3, STEEL_L)                                                   # slide top light
    c.rect(4.4, 2.2, 27.6, 2.6, STEEL_H)
    for x in (5.2, 6.4, 7.6, 8.8):                                                 # rear serrations
        c.line([(x, 3.4), (x, 6)], STEEL_D, 0.4)
    c.rect(17, 3.6, 21, 5.2, STEEL_D)                                              # ejection port
    c.rect(28, 3, 29.2, 5.4, STEEL_D)                                              # muzzle
    c.rect(26.4, 1, 27.6, 2, STEEL_L)                                              # front sight
    c.rect(4.6, 1, 6.4, 2, STEEL_L)                                                # rear sight
    return c.done()


def shotgun():
    c = Canvas(56, 14)
    c.poly([(1, 6), (16, 4.6), (16, 8.4), (8, 11.6), (1, 12.4), (0.5, 9)], WOOD_D)  # stock
    c.poly([(1.6, 6.6), (15.4, 5.2), (15.4, 7.6), (8, 10.6), (1.6, 11.4)], WOOD)
    c.line([(2, 7), (15, 5.8)], WOOD_L, 0.6)                                         # top light
    c.line([(4, 9.2), (12, 7.6)], WOOD_D, 0.35)                                      # grain
    c.rect(0.4, 6, 1.6, 12.4, STEEL_D)                                               # butt pad
    c.rect(16, 3.4, 26, 8.6, STEEL)                                                  # receiver
    c.rect(16, 3.4, 26, 4.4, STEEL_L)
    c.rect(19, 5.2, 23.6, 6.6, STEEL_D)                                              # loading port
    c.line([(18, 8.6), (18.4, 11), (22.6, 11), (23, 8.6)], STEEL, 0.7)              # trigger guard
    c.line([(20.4, 8.8), (20, 10.2)], STEEL_L, 0.5)
    c.rect(26, 3.6, 55, 5.6, STEEL)                                                  # barrel
    c.rect(26, 3.6, 55, 4.3, STEEL_H)
    c.rect(26, 6.2, 47, 7.8, STEEL_D)                                                # magazine tube
    c.rect(31, 5.6, 42, 9.2, WOOD_D)                                                 # pump
    c.rect(31.5, 6, 41.5, 8.6, WOOD)
    for x in range(33, 41, 2):                                                       # pump ridges
        c.line([(x, 6.2), (x, 8.4)], WOOD_D, 0.45)
    c.rect(54, 2.6, 55, 3.6, STEEL_H)                                                # bead sight
    return c.done()


def scrap():
    c = Canvas(18, 16)
    # bent plate, a gear and two bolts: Amortia's scrap (Safehouse building material)
    c.poly([(1, 11), (9, 8.5), (12, 12.5), (4, 15)], (70, 74, 78))
    c.poly([(1.6, 11.2), (8.8, 9.1), (9.6, 10.4), (2.4, 12.6)], (118, 122, 124))
    c.line([(4, 13), (9, 11.4)], (150, 74, 46), 0.6)                                 # rust
    cx, cy = 11.5, 6.5
    for i in range(8):                                                               # gear teeth
        import math
        a = i * math.pi / 4
        x, y = cx + math.cos(a) * 4.6, cy + math.sin(a) * 4.6
        c.rect(x - 1, y - 1, x + 1, y + 1, STEEL_L)
    c.ellipse(cx - 4, cy - 4, cx + 4, cy + 4, STEEL_L)
    c.ellipse(cx - 3, cy - 3, cx + 3, cy + 3, STEEL)
    c.ellipse(cx - 1.4, cy - 1.4, cx + 1.4, cy + 1.4, BG + (255,))
    c.ellipse(cx - 3.6, cy - 3.6, cx - 0.6, cy - 0.6, (190, 182, 160, 70))           # glint
    for bx, by in ((3.5, 6), (15.5, 13)):                                            # bolts
        c.rect(bx - 1.6, by - 1.2, bx + 1.6, by + 1.2, (160, 132, 70))
        c.rect(bx - 1.6, by - 1.2, bx + 1.6, by - 0.4, (214, 186, 110))
    return c.done()


def dodge_badge():
    """Blue round badge like the reference's secondary-bar icon, with dash chevrons (dodge roll)."""
    c = Canvas(8, 8)
    c.ellipse(0.2, 0.2, 7.8, 7.8, (34, 74, 124))
    c.ellipse(0.8, 0.8, 7.2, 7.2, (64, 128, 196))
    c.ellipse(1.4, 1.0, 6.6, 4.4, (112, 170, 226, 120))
    for x in (1.9, 4.0):
        c.line([(x, 2.3), (x + 1.7, 4), (x, 5.7)], (230, 240, 248), 0.85)
    return c.done(outline=False)


def main():
    os.makedirs(OUT, exist_ok=True)
    ref = Image.open(REF).convert("RGB")
    out = {
        "icon_heart.png": key_cut(ref, (121, 67, 143, 89), (14, 14)),
        "icon_skull.png": key_cut(ref, (712, 54, 733, 76), (14, 14)),
        "icon_noise_maker.png": key_cut(ref, (405, 124, 438, 173), (22, 32)),
        "icon_sample.png": key_cut(ref, (491, 125, 517, 174), (17, 32)),
        "weapon_pistol.png": pistol(),
        "weapon_shotgun.png": shotgun(),
        "icon_scrap.png": scrap(),
        "icon_dodge.png": dodge_badge(),
    }
    for name, img in out.items():
        img.save(os.path.join(OUT, name))
        print(name, img.size)


if __name__ == "__main__":
    main()

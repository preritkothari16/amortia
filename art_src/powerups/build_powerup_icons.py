"""Power-up icons (step 72): hand-authored pixel art, one texel = one viewport pixel, so they stay
crisp at every integer window scale (x2 / x3 / x4) with nearest filtering.

Each icon is a 9 x 9 grid of palette letters (light from the top left, dark outline). The same icon
is used by the HUD and, sitting on a dark round token, by the pickup lying on the map:

  heal    Medkit      bone-white field case with a blood-red cross and a handle (pickup only:
                      it heals at once, so it never shows as an active effect)
  shield  Shield      cracked steel-blue heater shield
  haste   Haste       heavy boot with motion streaks
  rapid   Rapid fire  three brass rounds, staggered like a burst
  damage  Damage      blood-edged blade, drops falling from it

python -I art_src/powerups/build_powerup_icons.py
-> ui/hud/art/powerup_<id>.png (9 x 9), world/powerups/art/token_<id>.png (15 x 15)
"""
import os

from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
HUD_OUT = os.path.join(ROOT, "ui", "hud", "art")
TOKEN_OUT = os.path.join(ROOT, "world", "powerups", "art")

OUTLINE = (12, 11, 14)

ICONS = {
    "heal": {
        "grid": [
            "...KKK...",
            "..KdKdK..",
            "KKKKKKKKK",
            "KhLLrLLmK",
            "KLLrrRLmK",
            "KLLLRLLmK",
            "KLmLLLmdK",
            "KmmmmmmdK",
            "KKKKKKKKK",
        ],
        "palette": {"h": (246, 240, 224), "L": (214, 204, 184), "m": (158, 148, 132), "d": (96, 88, 80),
                    "r": (196, 38, 42), "R": (128, 20, 26)},
    },
    "shield": {
        "grid": [
            "KKKKKKKKK",
            "KhhLLcLmK",
            "KhLLcLLmK",
            "KLLcLLmdK",
            "KLhcmmmdK",
            ".KLhcmdK.",
            ".KLLmcdK.",
            "..KmmcK..",
            "...KKK...",
        ],
        "palette": {"h": (196, 228, 255), "L": (122, 168, 218), "m": (72, 106, 152), "d": (40, 60, 94),
                    "c": (18, 22, 32)},
    },
    "haste": {
        "grid": [
            "...KKKK..",
            "...KhLK..",
            "Ss.KLmK..",
            "...KLmKK.",
            "SssKLLmmK",
            "...KLLLmK",
            ".SsKhLLmK",
            "...KddddK",
            "...KKKKKK",
        ],
        "palette": {"h": (204, 236, 172), "L": (122, 170, 96), "m": (74, 108, 60), "d": (38, 46, 34),
                    "s": (168, 240, 132), "S": (88, 150, 78)},
    },
    "rapid": {
        "grid": [
            ".......K.",
            "....K.KtK",
            ".K.KtKKyK",
            "KtKKyKKbK",
            "KyKKbKKbK",
            "KbKKbKKdK",
            "KbKKdKKKK",
            "KdKKKK...",
            "KKK......",
        ],
        "palette": {"t": (214, 120, 70), "y": (250, 220, 132), "b": (206, 160, 64), "d": (112, 76, 32)},
    },
    "damage": {
        "grid": [
            "......KKK",
            ".....KhLK",
            "....KhLrK",
            "...KhLrK.",
            "..KhLrKR.",
            ".KgLrK.R.",
            "KgwgK....",
            "KwgK.....",
            ".KK......",
        ],
        "palette": {"h": (232, 232, 236), "L": (164, 166, 176), "r": (176, 30, 36), "R": (200, 40, 44),
                    "g": (112, 100, 86), "w": (62, 42, 30)},
    },
}

## Token (pickup) colours: dark disc, steel rim lit at the top left.
TOKEN_FILL = (22, 24, 30)
TOKEN_FILL_LOW = (14, 15, 19)
TOKEN_RIM = (92, 96, 106)
TOKEN_RIM_DARK = (46, 48, 54)


def icon(name):
    spec = ICONS[name]
    grid = spec["grid"]
    assert len(grid) == 9 and all(len(row) == 9 for row in grid), name
    img = Image.new("RGBA", (9, 9), (0, 0, 0, 0))
    px = img.load()
    for y, row in enumerate(grid):
        for x, ch in enumerate(row):
            if ch == ".":
                continue
            rgb = OUTLINE if ch == "K" else spec["palette"][ch]
            px[x, y] = rgb + (255,)
    return img


def token(name):
    """15 x 15 dark round token with a steel rim and the icon in the middle."""
    img = Image.new("RGBA", (15, 15), (0, 0, 0, 0))
    px = img.load()
    c = 7.0
    for y in range(15):
        for x in range(15):
            d = ((x - c) ** 2 + (y - c) ** 2) ** 0.5
            if d <= 7.3:
                px[x, y] = OUTLINE + (255,)
            if d <= 6.3:
                lit = (x + y) < 12
                px[x, y] = (TOKEN_RIM if lit else TOKEN_RIM_DARK) + (255,)
            if d <= 5.3:
                px[x, y] = (TOKEN_FILL if y < 8 else TOKEN_FILL_LOW) + (255,)
    img.alpha_composite(icon(name), (3, 3))
    return img


def main():
    os.makedirs(HUD_OUT, exist_ok=True)
    os.makedirs(TOKEN_OUT, exist_ok=True)
    for name in ICONS:
        icon(name).save(os.path.join(HUD_OUT, "powerup_%s.png" % name))
        token(name).save(os.path.join(TOKEN_OUT, "token_%s.png" % name))
        print(name)


if __name__ == "__main__":
    main()

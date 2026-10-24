"""Hand-placed pixel art for the Runner ("the Bloomed"), top-down, facing +x (the game rotates it
to Enemy.facing). -> entities/enemies/art/runner_sheet.png: 3 frames of 24 x 24 (rest, left arm
reaching, right arm reaching). Walk frames are edits of the rest frame (arms shifted), not redraws.

python -I art_src/enemies/build_runner.py
"""
import os

from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "entities", "enemies", "art", "runner_sheet.png")

COLOURS = {
    ".": None,
    "o": (11, 9, 10),       # outline
    "c": (34, 28, 30),      # cloth dark
    "C": (54, 45, 48),      # cloth mid
    "d": (78, 66, 68),      # cloth fold highlight
    "s": (72, 82, 64),      # rotting skin shadow
    "S": (104, 116, 88),    # rotting skin
    "k": (146, 156, 120),   # skin highlight
    "h": (30, 24, 22),      # scalp hair
    "b": (96, 18, 18),      # dried blood
    "B": (150, 32, 26),     # fresh blood
    "r": (168, 46, 36),     # bloom flesh
    "R": (226, 96, 58),     # bloom petal
    "g": (255, 190, 100),   # bloom glow core
    "w": (214, 204, 190),   # claws / bone
}

REST = [
    "........................",
    "........................",
    "........................",
    "........ooo.............",
    ".......oCCCoooooo.......",
    "......ocCdCCsSSSSoo.....",
    "......ocCCCcosSSbkSoo...",
    ".....occCCcoo.oosSSkwo..",
    ".....occCcoohhhooossowo.",
    ".....occCohhSSShho.oo...",
    "....occcohrRSSkSSho.....",
    "....occcorgRrSSkSho.....",
    "....occcorRrbSSSSho.....",
    "....occcohrRSSSSsho.....",
    ".....occCohhSSsshho.oo..",
    ".....occCcoohhhooossowo.",
    ".....occCCcoo.oosSSkwo..",
    "......ocCCbcosSSSkSoo...",
    "......ocCdCCsSSSSoo.....",
    ".......oCCCoooooo.......",
    "........ooo.............",
    "........................",
    "........................",
    "........................",
]
UPPER_ARM = range(4, 9)    # rows of the arm at the top of the sprite (his left, facing +x)
LOWER_ARM = range(15, 20)  # rows of the other arm
ARM_FROM = 12              # columns from here on are arm, not shoulder


def shift_arm(rows: list, arm_rows: range, dx: int) -> list:
    """Moves the arm part of these rows dx px forward (+) or back (-); the shoulder stays."""
    out = list(rows)
    for y in arm_rows:
        row = out[y]
        arm = row[ARM_FROM:]
        if dx > 0:  # reach: the arm stretches (its first column repeats), so it stays attached
            arm = arm[0] * dx + arm[:-dx]
        elif dx < 0:
            arm = arm[-dx:] + "." * (-dx)
        out[y] = row[:ARM_FROM] + arm
    return out


def render(rows: list) -> Image.Image:
    assert len(rows) == 24 and all(len(r) == 24 for r in rows), [len(r) for r in rows]
    img = Image.new("RGBA", (24, 24), (0, 0, 0, 0))
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            colour = COLOURS[ch]
            if colour is not None:
                img.putpixel((x, y), colour + (255,))
    return img


def main() -> None:
    frames = [
        REST,
        shift_arm(shift_arm(REST, UPPER_ARM, 1), LOWER_ARM, -1),
        shift_arm(shift_arm(REST, UPPER_ARM, -1), LOWER_ARM, 1),
    ]
    sheet = Image.new("RGBA", (24 * len(frames), 24), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        sheet.alpha_composite(render(f), (24 * i, 0))
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    sheet.save(OUT)
    print("wrote", OUT)


if __name__ == "__main__":
    main()

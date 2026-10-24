"""Assembles scientist_torso_idle.png (4 x 8) from per-direction breathing rows
extracted/torso_<dir>/scientist_torso_idle__<DIR>.png (S lives in extracted/torso_south/).

python -I art_src/forsaken_scientist/scripts/build_torso_sheet.py [out.png]
default out: extracted/torso_sheet_partial/scientist_torso_idle.png while rows are missing.
Missing directions stay EMPTY (never filled with copies or mirrors); check_sheet.py then fails and
names them. Copy the sheet to entities/player/art/ only when all 8 rows pass.
"""
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import spec  # noqa: E402

KIT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
ROW_DIRS = {"S": "torso_south"}  # direction -> extracted/ subfolder; others: torso_<dir lower>


def main() -> None:
    sheet = Image.new("RGBA", (4 * spec.FRAME, 8 * spec.FRAME), (0, 0, 0, 0))
    missing = []
    for r, d in enumerate(spec.DIRS_8):
        folder = ROW_DIRS.get(d, "torso_" + d.lower())
        path = os.path.join(KIT, "extracted", folder, f"scientist_torso_idle__{d}.png")
        if not os.path.exists(path):
            missing.append(d)
            continue
        row = Image.open(path).convert("RGBA")
        assert row.size == (4 * spec.FRAME, spec.FRAME), f"{path} is {row.size}"
        sheet.alpha_composite(row, (0, r * spec.FRAME))
    default = os.path.join(KIT, "extracted", "torso_sheet_partial" if missing else "torso_sheet", "scientist_torso_idle.png")
    out = sys.argv[1] if len(sys.argv) > 1 else default
    os.makedirs(os.path.dirname(out), exist_ok=True)
    sheet.save(out)
    print(f"wrote {out}; rows present: {[d for d in spec.DIRS_8 if d not in missing]}; MISSING: {missing}")


if __name__ == "__main__":
    main()

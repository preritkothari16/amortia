"""Sheet layout for the Forsaken Scientist. Must match entities/player/player_visual.gd.

Every sheet: transparent PNG, 80x80 frames, columns = animation frames, rows = directions.
Pivot (feet centre) at (40, 72) in every frame. In game a frame is drawn at scale 0.5,
so 2 art px = 1 world px (32 art px = one 16-unit world tile).
"""

FRAME = 80
PIVOT = (40, 72)

# Row order for 8-direction sheets (Godot angles, y points down): 0 deg = E, 90 deg = S.
DIRS_8 = ["E", "SE", "S", "SW", "W", "NW", "N", "NE"]
# Row order for the death sheet.
DIRS_4 = ["E", "S", "W", "N"]
# Gun-arm rows: row k is drawn pointing at 11.25 + 22.5 * k degrees.
ARM_ANGLES = [11.25 + 22.5 * k for k in range(16)]

# name -> (columns, rows, required, what)
SHEETS = {
    "scientist_legs_idle":           (1, 8, False, "boots and shins below the coat hem, standing"),
    "scientist_legs_walk":           (6, 8, True,  "one full stride (two steps), frame 0 = contact, right foot forward"),
    "scientist_torso_idle":          (4, 8, True,  "torso, head, coat, human LEFT arm; breathing and coat sway loop"),
    "scientist_torso_walk":          (6, 8, False, "same as idle, bob and coat swing in phase with the legs"),
    "scientist_torso_throw":         (4, 8, False, "left (human) hand throws the noise-maker: wind-up, release, follow, recover"),
    "scientist_torso_hurt":          (2, 8, False, "flinch: snap back, recover"),
    "scientist_gunarm":              (4, 16, True, "right gun arm only: rest, fire, recoil, settle"),
    "scientist_gunarm_glow":         (4, 16, False, "emissive cores only (glow_* colours), same frames as gunarm"),
    "fx_muzzle_flash":               (3, 16, False, "pistol flash at the barrel tip of the matching gunarm row"),
    "fx_muzzle_flash_shotgun":       (3, 16, False, "wider shotgun flash, same placement"),
    "scientist_roll":                (6, 8, False, "full body dodge roll in the row's direction, gun arm stays on his right"),
    "scientist_death":               (8, 4, False, "full body collapse, last frame = corpse (held)"),
    "scientist_shadow":              (1, 1, False, "soft-edged (dithered, not blurred) ground ellipse under the feet"),
}

# Guide heights (art px, y down) for a standing 48 px tall figure.
HEAD_TOP_Y = 24
CHIN_Y = 35
SHOULDER_Y = 38
HEM_Y = 60
# The logical muzzle (where bullets really spawn) is 11 world px = 22 art px from the pivot.
MUZZLE_ART_PX = 22
# Visual barrel: from the right shoulder, about this long.
BARREL_ART_PX = 24
SHOULDER_HALF_WIDTH = 9

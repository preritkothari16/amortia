class_name HudLayout
extends RefCounted
## Where everything sits in the bottom HUD strip (step 71), in viewport px (480 x 270, integer-scaled
## by the window). Rects are relative to the strip's top-left corner; the strip spans the full width.
## No boxes round the groups - thin dividers and darker inlays only:
##   left    player status: heart + segmented HEALTH bar + HP value, dodge badge + compact cooldown
##           bar + RDY / seconds, HIDDEN chip while concealed
##   centre  weapon in hand (art + name), swap key + spare weapon (only when one is carried), items:
##           noise-maker, power-up (only while one runs), samples, scrap
##   right   wave block (WAVE / GEN, the big wave number, Bloomed left) and a 3-row objective checklist
## main.gd frames the camera half a strip lower, so the player sits in the middle of the uncovered view.

const STRIP_HEIGHT: float = 28.0
## Height of one extra objective line above the strip (overflow, see WaveHud).
const OVERFLOW_LINE: float = 8.0
const MAX_OVERFLOW_LINES: int = 2
## Soft shadow above the strip (drawn, not counted as covered: it only darkens the world a little).
const FADE: float = 4.0

# Left: player status.
const HEART: Rect2 = Rect2(6, 6, 7, 7)
const HP_BAR: Rect2 = Rect2(17, 7, 72, 5)
## HP value: left edge and baseline.
const HP_VALUE: Vector2 = Vector2(94, 13)
const DODGE_ICON: Rect2 = Rect2(6, 16, 8, 8)
const DODGE_BAR: Rect2 = Rect2(17, 19, 36, 3)
const DODGE_TEXT: Vector2 = Vector2(57, 23)
const HIDDEN_CHIP: Rect2 = Rect2(82, 16, 32, 8)

# Centre: weapons and items.
const WEAPON_ART: Rect2 = Rect2(128, 3, 56, 15)
const WEAPON_NAME_BASELINE: float = 26.0
const SWAP_KEY: Rect2 = Rect2(190, 4, 7, 7)
const SPARE_ART: Rect2 = Rect2(188, 13, 34, 9)
## Items: 2 x 2 cells (noise-maker, power-up / samples, scrap), icon on the left of each cell.
const ITEM_X: Array[float] = [232.0, 264.0]
const ITEM_Y: Array[float] = [3.0, 15.0]
const ITEM_SIZE: Vector2 = Vector2(30, 11)

## Faint vertical rules between the three groups.
const DIVIDERS: Array[float] = [120.0, 226.0, 298.0]

# Right: wave block and objective checklist.
const RIGHT_X: float = 302.0
const RIGHT_MARGIN: float = 4.0
const WAVE_LABEL_BASELINE: float = 7.0
const WAVE_NUMBER_BASELINE: float = 19.0
const BLOOMED_BASELINE: float = 26.0
const CHECK_X: float = 350.0
const CHECK_BASELINE: Array[float] = [9.0, 17.0, 25.0]
## Checklist text starts this far right of the row's left edge (after the square marker).
const CHECK_TEXT_INDENT: float = 9.0


static func item(index: int) -> Rect2:
	return Rect2(Vector2(ITEM_X[index % 2], ITEM_Y[index / 2]), ITEM_SIZE)


## Every fixed area of the strip, for overlap tests.
static func boxes() -> Array[Rect2]:
	var list: Array[Rect2] = [HEART, HP_BAR, Rect2(HP_VALUE - Vector2(0, 7), Vector2(22, 8)), DODGE_ICON,
		DODGE_BAR, Rect2(DODGE_TEXT - Vector2(0, 6), Vector2(22, 7)), HIDDEN_CHIP, WEAPON_ART, SWAP_KEY, SPARE_ART]
	for i: int in 4:
		list.append(item(i))
	return list


## Width available to one checklist line in the right column of a `viewport_width` px wide screen.
static func check_text_width(viewport_width: float) -> float:
	return viewport_width - RIGHT_MARGIN - CHECK_X - CHECK_TEXT_INDENT

class_name FacadeBuilder
extends RefCounted
## Bakes one building into an Image (visual only), drawn for the game's top-down / three-quarter
## view: the front (south) facade with its storeys, windows, entrance and signage fills most of
## the footprint, the roof is only the strip above it, a narrow side wall on the east edge gives it
## depth, and its shadow on the ground grows with its height. The footprint is painted fully
## opaque (what looks solid is exactly what collides) and every entrance is shut (boarded,
## chained, shuttered, sealed), so nothing promises an interior that isn't there. The margin
## round the footprint only holds the shadow and a few flat specks, never over cells the caller
## marks as blocked.
##
## BuildingArchetypes lays each building type out with the primitives below; then the district's
## look adds the passes: an occasional collapsed corner, weathering (stains, cracks, cables),
## flood marks, burns, overgrowth and the Bloom's fleshy growth. Seeded: the same building always
## bakes the same image.

enum Part { NONE, ROOF, WALL, GLASS, DOOR, SIGN, TRIM, PROP, DARK, GROWTH }
enum Surface { SIDING, BRICK, RENDER, CONCRETE, PANEL, METAL, LOGS, BOARDS, STONE }
enum Glass { CLEAN, DARK, CURTAIN, INTERIOR, BROKEN, BOARDED, MEMBRANE, SHUTTER }

const TILE: int = 16
## Margin (px) round the footprint for the ground shadow and debris specks.
const MARGIN: int = 12
const OUTLINE: Color = Color(0.05, 0.05, 0.06)
const WOOD: Color = Color(0.52, 0.37, 0.23)
const CHAR: Color = Color(0.07, 0.06, 0.055)
const EMBER: Color = Color(1.0, 0.45, 0.14)
const BLOOD: Color = Color("#6d252a")
const HAZARD: Color = Color(0.92, 0.74, 0.16)
const FLESH: Color = Color(0.5, 0.15, 0.19)
const VEIN: Color = Color(0.84, 0.3, 0.32)
const PUS: Color = Color(0.95, 0.64, 0.52)
const LEAF: Color = Color(0.3, 0.45, 0.2)
const RUST: Color = Color(0.5, 0.27, 0.14)

## Materials per zone (Maple Hollow, Lowtide, Greywood, Sunnyseed Labs). The ground material
## grades everything by zone afterwards, so these stay fairly bright and contrasty.
const STYLE: Array[Dictionary] = [
	{
		"siding": [Color(0.68, 0.74, 0.78), Color(0.66, 0.72, 0.62), Color(0.8, 0.76, 0.66), Color(0.76, 0.66, 0.66), Color(0.72, 0.72, 0.75)],
		"brick": [Color(0.58, 0.34, 0.27), Color(0.52, 0.38, 0.31), Color(0.62, 0.43, 0.33)],
		"render": [Color(0.75, 0.75, 0.72), Color(0.68, 0.7, 0.73), Color(0.78, 0.74, 0.68)],
		"concrete": [Color(0.62, 0.63, 0.64), Color(0.56, 0.57, 0.6)],
		"logs": [Color(0.5, 0.36, 0.23)],
		"roof": [Color(0.3, 0.32, 0.37), Color(0.38, 0.3, 0.27), Color(0.45, 0.27, 0.25), Color(0.34, 0.39, 0.42)],
		"flat": [Color(0.33, 0.34, 0.36)],
		"trim": [Color(0.9, 0.9, 0.86)],
		"door": [Color(0.46, 0.18, 0.17), Color(0.2, 0.33, 0.27), Color(0.2, 0.27, 0.42), Color(0.42, 0.31, 0.2)],
		"curtain": [Color(0.62, 0.3, 0.3), Color(0.72, 0.68, 0.5), Color(0.36, 0.5, 0.4), Color(0.52, 0.44, 0.62)],
		"glass": [Color(0.22, 0.29, 0.36)],
		"metal": [Color(0.5, 0.53, 0.56), Color(0.43, 0.47, 0.52)],
		"accent": [Color(0.74, 0.2, 0.18), Color(0.2, 0.52, 0.33), Color(0.2, 0.37, 0.64), Color(0.88, 0.66, 0.2)],
	},
	{
		"siding": [Color(0.56, 0.7, 0.68), Color(0.72, 0.78, 0.74), Color(0.5, 0.62, 0.67), Color(0.75, 0.71, 0.6)],
		"brick": [Color(0.5, 0.37, 0.31), Color(0.45, 0.41, 0.37)],
		"render": [Color(0.62, 0.75, 0.73), Color(0.78, 0.8, 0.77), Color(0.56, 0.67, 0.71), Color(0.8, 0.72, 0.62)],
		"concrete": [Color(0.56, 0.6, 0.6), Color(0.5, 0.55, 0.56)],
		"logs": [Color(0.46, 0.38, 0.28)],
		"roof": [Color(0.3, 0.43, 0.45), Color(0.52, 0.33, 0.25), Color(0.28, 0.34, 0.39)],
		"flat": [Color(0.29, 0.33, 0.34)],
		"trim": [Color(0.86, 0.9, 0.88)],
		"door": [Color(0.2, 0.37, 0.41), Color(0.5, 0.25, 0.2), Color(0.3, 0.31, 0.35)],
		"curtain": [Color(0.3, 0.5, 0.55), Color(0.7, 0.62, 0.45), Color(0.6, 0.3, 0.36)],
		"glass": [Color(0.17, 0.29, 0.32)],
		"metal": [Color(0.46, 0.52, 0.52), Color(0.53, 0.37, 0.27)],
		"accent": [Color(0.94, 0.3, 0.58), Color(0.3, 0.88, 0.88), Color(0.2, 0.43, 0.62), Color(0.88, 0.42, 0.2)],
	},
	{
		"siding": [Color(0.50, 0.59, 0.47), Color(0.61, 0.53, 0.41), Color(0.44, 0.51, 0.44)],
		"brick": [Color(0.5, 0.5, 0.46), Color(0.46, 0.45, 0.41)],
		"render": [Color(0.6, 0.6, 0.54), Color(0.55, 0.57, 0.52)],
		"concrete": [Color(0.52, 0.54, 0.5), Color(0.47, 0.5, 0.47)],
		"logs": [Color(0.59, 0.42, 0.27), Color(0.52, 0.38, 0.26), Color(0.65, 0.48, 0.32)],
		"roof": [Color(0.37, 0.32, 0.26), Color(0.32, 0.41, 0.33), Color(0.41, 0.37, 0.32)],
		"flat": [Color(0.27, 0.29, 0.26)],
		"trim": [Color(0.92, 0.87, 0.73)],
		"door": [Color(0.42, 0.28, 0.19), Color(0.29, 0.39, 0.27)],
		"curtain": [Color(0.5, 0.3, 0.24), Color(0.6, 0.56, 0.42), Color(0.3, 0.4, 0.3)],
		"glass": [Color(0.16, 0.21, 0.2)],
		"metal": [Color(0.44, 0.47, 0.44), Color(0.49, 0.35, 0.25)],
		"accent": [Color(0.86, 0.72, 0.3), Color(0.38, 0.27, 0.17), Color(0.72, 0.25, 0.2), Color(0.3, 0.5, 0.3)],
	},
	{
		"siding": [Color(0.86, 0.88, 0.9), Color(0.8, 0.83, 0.86)],
		"brick": [Color(0.72, 0.74, 0.77)],
		"render": [Color(0.88, 0.9, 0.92), Color(0.82, 0.85, 0.88)],
		"concrete": [Color(0.7, 0.72, 0.75), Color(0.64, 0.67, 0.7)],
		"logs": [Color(0.5, 0.36, 0.23)],
		"roof": [Color(0.56, 0.6, 0.64)],
		"flat": [Color(0.5, 0.53, 0.57)],
		"trim": [Color(0.96, 0.97, 0.98)],
		"door": [Color(0.6, 0.64, 0.68)],
		"curtain": [Color(0.7, 0.75, 0.8)],
		"glass": [Color(0.3, 0.43, 0.5)],
		"metal": [Color(0.6, 0.63, 0.67), Color(0.52, 0.56, 0.6)],
		"accent": [Color(0.95, 0.78, 0.22), Color(0.42, 0.72, 0.33), Color(0.3, 0.5, 0.72), Color(0.8, 0.25, 0.22)],
	},
]

var zone: int = 0
var archetype: StringName = &""
## Footprint size (px); image = footprint + 2 * MARGIN.
var width: int = 0
var height: int = 0
var image_size: Vector2i = Vector2i.ZERO
## Set by the archetype through begin(): where the facade starts (the roof strip is above it),
## how many storeys the building has, and the facade width left of the side wall.
var facade_top: int = 0
var storeys: int = 1
var fw: int = 0
## Look of this building (BuildingDetail fills it from the district): decay, infection,
## overgrowth, flood (0..1) and burned / collapse (bool).
var look: Dictionary = {}
## Where smouldering fires sit, in image px (AmbientLights puts a flickering light there).
var fires: Array[Vector2] = []
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

var img: Image
var _part: PackedByteArray = PackedByteArray()
var _seed: int = 0
var _blocked: Dictionary = {}
var _noise: FastNoiseLite = FastNoiseLite.new()
## Windows painted so far (footprint px) and their state, for the passes (soot, stains).
var _windows: Array[Rect2i] = []
var _window_state: Array[int] = []
var _doors: Array[Rect2i] = []


## Bakes a `size_cells` building of type `archetype_id`. `blocked` holds cells (relative to the
## footprint's top-left cell) next to it that are not walkable; nothing is drawn over them.
func bake(size_cells: Vector2i, archetype_id: StringName, zone_index: int, building_look: Dictionary,
		seed_value: int, blocked: Dictionary = {}) -> Image:
	zone = clampi(zone_index, 0, 3)
	archetype = archetype_id
	look = building_look
	_seed = seed_value
	_blocked = blocked
	rng.seed = seed_value
	_noise.seed = seed_value + 11
	_noise.noise_type = FastNoiseLite.TYPE_VALUE
	_noise.frequency = 0.16
	width = size_cells.x * TILE
	height = size_cells.y * TILE
	image_size = Vector2i(width + MARGIN * 2, height + MARGIN * 2)
	img = Image.create(image_size.x, image_size.y, false, Image.FORMAT_RGBA8)
	_part.resize(width * height)
	_part.fill(Part.NONE)
	begin(height / 3, 1)
	BuildingArchetypes.paint(self, archetype_id)
	if look.get("collapse", false):
		_collapse()
	_weather()
	if look.get("flood", 0.0) > 0.0:
		_flood()
	if look.get("burned", false):
		_burn()
	_overgrow()
	_infect()
	_shadow()
	return img


## Part painted at a footprint pixel (tests): Part.NONE off the footprint.
func part_at(fx: int, fy: int) -> Part:
	if not inside(fx, fy):
		return Part.NONE
	return _part[fy * width + fx] as Part


func inside(fx: int, fy: int) -> bool:
	return fx >= 0 and fy >= 0 and fx < width and fy < height


## Sets the roof strip height and storey count; the side wall's width follows from the height.
func begin(cap: int, storey_count: int) -> void:
	facade_top = clampi(cap, 0, height - 4)
	storeys = maxi(storey_count, 1)
	fw = width - side_width()


func side_width() -> int:
	return clampi(1 + storeys, 2, 5)


# --- random / palette ------------------------------------------------------------------------

func pick(key: String) -> Color:
	var list: Array = STYLE[zone][key]
	return list[rng.randi() % list.size()]


func chance(p: float) -> bool:
	return rng.randf() < p


func rand(lo: int, hi: int) -> int:
	return rng.randi_range(lo, hi)


func hash01(x: int, y: int, salt: int) -> float:
	var h: int = (x * 73856093) ^ (y * 19349663) ^ ((_seed + salt * 83492791) & 0x7fffffff)
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return float(h & 0xffff) / 65535.0


static func tone(c: Color, k: float) -> Color:
	return Color(clampf(c.r * k, 0.0, 1.0), clampf(c.g * k, 0.0, 1.0), clampf(c.b * k, 0.0, 1.0), 1.0)


# --- pixels ----------------------------------------------------------------------------------

## Fills a footprint rect (clipped to the footprint).
func fill(x: int, y: int, w: int, h: int, c: Color, part: Part = Part.NONE) -> void:
	var x0: int = maxi(x, 0)
	var y0: int = maxi(y, 0)
	var x1: int = mini(x + w, width)
	var y1: int = mini(y + h, height)
	if x1 <= x0 or y1 <= y0:
		return
	c.a = 1.0
	img.fill_rect(Rect2i(x0 + MARGIN, y0 + MARGIN, x1 - x0, y1 - y0), c)
	if part != Part.NONE:
		for yy: int in range(y0, y1):
			for xx: int in range(x0, x1):
				_part[yy * width + xx] = part


func dot(x: int, y: int, c: Color, part: Part = Part.NONE) -> void:
	if not inside(x, y):
		return
	c.a = 1.0
	img.set_pixel(x + MARGIN, y + MARGIN, c)
	if part != Part.NONE:
		_part[y * width + x] = part


func get_px(x: int, y: int) -> Color:
	return img.get_pixel(x + MARGIN, y + MARGIN)


## Darkens / lightens a footprint pixel by `k`.
func mul(x: int, y: int, k: float) -> void:
	if inside(x, y):
		img.set_pixel(x + MARGIN, y + MARGIN, tone(get_px(x, y), k))


func mix(x: int, y: int, c: Color, t: float) -> void:
	if inside(x, y):
		var m: Color = get_px(x, y).lerp(c, t)
		m.a = 1.0
		img.set_pixel(x + MARGIN, y + MARGIN, m)


func hline(x: int, y: int, w: int, c: Color, part: Part = Part.NONE) -> void:
	fill(x, y, w, 1, c, part)


func vline(x: int, y: int, h: int, c: Color, part: Part = Part.NONE) -> void:
	fill(x, y, 1, h, c, part)


## A pixel on the ground round the footprint (image may be partly transparent there); skipped on
## blocked cells and over anything already drawn there unless `over` is set.
func ground_dot(x: int, y: int, c: Color, over: bool = false) -> void:
	if inside(x, y):
		return
	var ix: int = x + MARGIN
	var iy: int = y + MARGIN
	if ix < 0 or iy < 0 or ix >= image_size.x or iy >= image_size.y:
		return
	if _blocked.has(Vector2i(floori(x / float(TILE)), floori(y / float(TILE)))):
		return
	if not over and img.get_pixel(ix, iy).a > 0.0:
		return
	img.set_pixel(ix, iy, c)


# --- walls and roofs -------------------------------------------------------------------------

## A stretch of wall in `surface`, with its own texture.
func wall(x: int, y: int, w: int, h: int, surface: Surface, c: Color) -> void:
	fill(x, y, w, h, c, Part.WALL)
	for yy: int in range(maxi(y, 0), mini(y + h, height)):
		var ry: int = yy - y
		for xx: int in range(maxi(x, 0), mini(x + w, width)):
			var rx: int = xx - x
			var k: float = 1.0
			match surface:
				Surface.SIDING:
					k = 0.84 if ry % 3 == 2 else (1.05 if ry % 3 == 0 else 1.0)
				Surface.BRICK:
					var row: int = ry / 2
					k = 0.82 if ry % 2 == 1 else 0.94 + 0.12 * hash01((rx + (row % 2) * 2) / 4, row, 1)
					if ry % 2 == 0 and (rx + (row % 2) * 2) % 4 == 0:
						k = 0.8
				Surface.RENDER:
					k = 0.96 + 0.07 * hash01(xx, yy, 2)
				Surface.CONCRETE:
					k = 0.95 + 0.08 * hash01(xx / 2, yy / 2, 3)
					if rx % 16 == 15:
						k = 0.82
				Surface.PANEL:
					k = 1.0 - 0.04 * float(ry % 12) / 12.0
					if rx % 12 == 11 or ry % 12 == 11:
						k = 0.86
					elif rx % 12 == 0 or ry % 12 == 0:
						k = 1.04
				Surface.METAL:
					k = 1.12 if rx % 3 == 0 else (0.8 if rx % 3 == 2 else 0.98)
				Surface.LOGS:
					k = 1.12 if ry % 3 == 0 else (0.6 if ry % 3 == 2 else 0.95 + 0.08 * hash01(xx / 6, yy / 3, 4))
				Surface.BOARDS:
					k = 0.7 if rx % 4 == 3 else 0.94 + 0.1 * hash01(xx / 4, 0, 5)
				Surface.STONE:
					var srow: int = ry / 3
					var block: int = (rx + int(hash01(0, srow, 6) * 5.0)) / 5
					k = 0.66 if (ry % 3 == 2 or (rx + int(hash01(0, srow, 6) * 5.0)) % 5 == 0) else 0.88 + 0.2 * hash01(block, srow, 7)
			if k != 1.0:
				img.set_pixel(xx + MARGIN, yy + MARGIN, tone(c, k))
	if surface == Surface.LOGS:  # round log ends at the corners
		for yy: int in range(y, y + h, 3):
			for xx: int in [x, x + w - 2]:
				fill(xx, yy, 2, 2, Color(0.74, 0.6, 0.42), Part.WALL)
				dot(xx + (1 if xx == x else 0), yy + 1, tone(Color(0.74, 0.6, 0.42), 0.7))


## Lit left edge, shaded right edge and a plinth: gives the facade its volume.
func edges(x: int, y: int, w: int, h: int) -> void:
	for yy: int in range(y, y + h):
		mul(x, yy, 1.14)
		mul(x + w - 1, yy, 0.78)
	for xx: int in range(x, x + w):
		mul(xx, y + h - 1, 0.7)
		mul(xx, y + h - 2, 0.86)


## Pitched roof seen from the front: a thin far slope, the ridge, the near slope in shingle
## courses and the gutter with the eave's shadow on the wall below.
func roof_gable(y0: int, y1: int, c: Color, shake: bool = false) -> void:
	var ridge: int = y0 + clampi((y1 - y0) / 6, 2, 4)
	for yy: int in range(y0, y1):
		var base: Color = c
		if yy < ridge:
			base = tone(c, 0.68 + 0.06 * (yy - y0))
			hline(0, yy, width, base, Part.ROOF)
			continue
		if yy == ridge:
			hline(0, yy, width, tone(c, 1.32), Part.ROOF)
			continue
		var t: float = float(yy - ridge) / float(maxi(y1 - ridge, 1))
		base = tone(c, 1.08 - 0.22 * t)
		hline(0, yy, width, base, Part.ROOF)
		var course: int = (yy - ridge - 1) / 3
		var r: int = (yy - ridge - 1) % 3
		for xx: int in width:
			var tab: int = 5 if not shake else 3
			if r == 2:
				dot(xx, yy, tone(base, 0.74))
			elif (xx + (course % 2) * 2) % tab == 0:
				dot(xx, yy, tone(base, 0.82))
			elif shake and hash01(xx, yy, 8) < 0.2:
				dot(xx, yy, tone(base, 0.9))
	hline(0, y1 - 1, width, tone(c, 0.55), Part.ROOF)
	hline(0, y1 - 2, width, tone(pick("trim"), 0.82), Part.TRIM)
	for yy: int in range(y0, y1):
		mul(0, yy, 0.62)
		mul(width - 1, yy, 0.62)
	for xx: int in width:  # eave shadow on the wall
		mul(xx, y1, 0.62)
		mul(xx, y1 + 1, 0.82)


## Front gable: a wall triangle rising into the roof from `base_y` to `apex_y`, trimmed.
func gable(gx: int, gw: int, apex_y: int, base_y: int, surface: Surface, c: Color) -> void:
	var cx: float = gx + gw / 2.0
	var trim: Color = pick("trim")
	var span: float = float(maxi(base_y - apex_y, 1))
	for yy: int in range(apex_y, base_y):
		var half: int = int(round((yy - apex_y + 1) / span * gw / 2.0))
		var x0: int = int(cx) - half
		wall(x0, yy, half * 2, 1, surface, c)
		dot(x0 - 1, yy, trim, Part.TRIM)
		dot(int(cx) + half, yy, trim, Part.TRIM)
		dot(int(cx) + half + 1, yy, tone(get_px(int(cx) + half + 1, yy), 0.6))
	hline(gx - 1, base_y - 1, gw + 2, tone(trim, 0.85), Part.TRIM)


## Flat roof seen at a steep angle: coping, gravel, cornice and its shadow on the wall.
func roof_flat(y0: int, y1: int, c: Color) -> void:
	fill(0, y0, width, y1 - y0, c, Part.ROOF)
	for yy: int in range(y0, y1):
		for xx: int in width:
			if hash01(xx, yy, 9) < 0.18:
				dot(xx, yy, tone(c, 0.82 + 0.3 * hash01(xx, yy, 10)))
	var trim: Color = tone(pick("trim"), 0.86)
	hline(0, y0, width, trim, Part.TRIM)
	hline(0, y0 + 1, width, tone(c, 0.7), Part.ROOF)
	hline(0, y1 - 2, width, trim, Part.TRIM)
	hline(0, y1 - 1, width, tone(c, 0.55), Part.TRIM)
	for yy: int in range(y0, y1):
		dot(0, yy, trim, Part.TRIM)
		dot(width - 1, yy, tone(trim, 0.7), Part.TRIM)
	for xx: int in width:
		mul(xx, y1, 0.66)


## Low-pitched sheet-metal roof (warehouses, sheds): ribs running down to the eave.
func roof_metal(y0: int, y1: int, c: Color) -> void:
	fill(0, y0, width, y1 - y0, c, Part.ROOF)
	for yy: int in range(y0, y1):
		var t: float = float(yy - y0) / float(maxi(y1 - y0, 1))
		for xx: int in width:
			var k: float = (1.16 if xx % 4 == 0 else (0.82 if xx % 4 == 3 else 1.0)) * (1.05 - 0.2 * t)
			dot(xx, yy, tone(c, k))
	hline(0, y0, width, tone(c, 1.3), Part.ROOF)
	hline(0, y1 - 1, width, tone(c, 0.5), Part.ROOF)
	for xx: int in width:
		mul(xx, y1, 0.64)
	for i: int in int(width / 24.0):  # translucent skylight panels
		var sx: int = 6 + i * 24 + rand(0, 6)
		fill(sx, y0 + 2, 6, maxi(y1 - y0 - 5, 2), tone(Color(0.55, 0.62, 0.6), 0.9), Part.ROOF)


## Sawtooth factory roof: north-light teeth, glazed faces toward the viewer.
func roof_sawtooth(y0: int, y1: int, c: Color) -> void:
	fill(0, y0, width, y1 - y0, tone(c, 0.6), Part.ROOF)
	var tooth: int = clampi((y1 - y0) / 2, 5, 9)
	var glass: Color = pick("glass")
	for row_y: int in range(y1 - tooth, y0 - tooth, -tooth):
		for xx: int in width:
			var u: int = xx % 14
			var top: int = row_y + (tooth - 1) - (u * (tooth - 1)) / 13
			for yy: int in range(maxi(top, y0), mini(row_y + tooth, y1)):
				dot(xx, yy, tone(c, 0.9 + 0.2 * float(u) / 14.0), Part.ROOF)
			if u == 13 or u == 0:
				for yy: int in range(maxi(row_y, y0), mini(row_y + tooth, y1)):
					dot(xx, yy, tone(glass, 1.2 if yy % 2 == 0 else 0.9), Part.GLASS)
	hline(0, y1 - 1, width, tone(c, 0.5), Part.ROOF)
	for xx: int in width:
		mul(xx, y1, 0.64)


## Horizontal floor slab / string course between storeys.
func floor_line(y: int, c: Color) -> void:
	hline(0, y, fw, tone(c, 1.12), Part.TRIM)
	for xx: int in fw:
		mul(xx, y + 1, 0.8)


## The narrow east wall (drawn last): darker, with slit windows, the roof's end above it.
func side_wall(c: Color, storey_h: int) -> void:
	var sw: int = width - fw
	if sw <= 0:
		return
	for yy: int in height:
		for i: int in sw:
			var xx: int = fw + i
			if yy < facade_top:
				dot(xx, yy, tone(get_px(xx, yy), 0.62))
			else:
				dot(xx, yy, tone(c, 0.58 - 0.04 * i), Part.WALL)
	for yy: int in range(facade_top, height):
		mul(fw, yy, 0.8)
	if storey_h > 0 and sw >= 3:
		var y: int = height - 6
		while y - 4 > facade_top + 1:
			fill(fw + 1, y - 4, 1, 4, tone(pick("glass"), 0.5), Part.GLASS)
			y -= storey_h
	for xx: int in range(fw, width):
		mul(xx, height - 1, 0.7)


# --- openings --------------------------------------------------------------------------------

## A window; `opts`: framed (bool), mullion (bool), sill (bool), state (Glass), bars (bool),
## curtain (bool). Returns the state it was painted in.
func window(x: int, y: int, w: int, h: int, opts: Dictionary = {}) -> int:
	var state: int = opts.get("state", _pick_state(opts.get("curtain", true)))
	var trim: Color = opts.get("trim", pick("trim"))
	var gx: int = x
	var gy: int = y
	var gw: int = w
	var gh: int = h
	if opts.get("framed", true) and w >= 5 and h >= 5:
		fill(x, y, w, h, trim, Part.TRIM)
		gx += 1
		gy += 1
		gw -= 2
		gh -= 2
	_glass(gx, gy, gw, gh, state)
	if opts.get("mullion", false) and state <= Glass.INTERIOR:
		if gw >= 5:
			vline(gx + gw / 2, gy, gh, trim, Part.TRIM)
		if gh >= 6:
			hline(gx, gy + gh / 2, gw, trim, Part.TRIM)
	if opts.get("bars", false):
		for xx: int in range(gx + 1, gx + gw, 2):
			vline(xx, gy, gh, tone(pick("metal"), 0.7), Part.TRIM)
	if opts.get("sill", true):
		hline(x - 1, y + h, w + 2, tone(trim, 0.9), Part.TRIM)
		for xx: int in range(x - 1, x + w + 1):
			if part_at(xx, y + h + 1) == Part.WALL:
				mul(xx, y + h + 1, 0.78)
	_windows.append(Rect2i(x, y, w, h))
	_window_state.append(state)
	return state


func _pick_state(curtains: bool) -> int:
	var d: float = look.get("decay", 0.3)
	var i: float = look.get("infection", 0.0)
	var r: float = rng.randf()
	if r < i * 0.35:
		return Glass.MEMBRANE
	r = rng.randf()
	if r < 0.08 + 0.22 * d:
		return Glass.BOARDED
	if r < 0.18 + 0.55 * d:
		return Glass.BROKEN
	r = rng.randf()
	if r < 0.36:
		return Glass.CLEAN
	if r < 0.62:
		return Glass.DARK
	if r < 0.86 and curtains:
		return Glass.CURTAIN
	return Glass.INTERIOR


func _glass(x: int, y: int, w: int, h: int, state: int) -> void:
	var g: Color = pick("glass")
	match state:
		Glass.CLEAN, Glass.CURTAIN:
			fill(x, y, w, h, g, Part.GLASS)
			hline(x, y, w, tone(g, 1.35))
			for yy: int in range(y, y + h):  # sky reflection running down to the right
				for xx: int in range(x, x + w):
					var dg: int = (xx - x) - (yy - y) - w / 3
					if dg == 0 or dg == 1:
						dot(xx, yy, tone(g, 1.7))
					elif dg == 3:
						dot(xx, yy, tone(g, 1.3))
			if state == Glass.CURTAIN:
				var cc: Color = pick("curtain")
				var cw: int = maxi(w / 3, 1)
				for xx: int in range(x, x + cw):
					vline(xx, y, h, tone(cc, 0.86 if xx % 2 == 0 else 1.0))
				if w >= 5:
					for xx: int in range(x + w - cw, x + w):
						vline(xx, y, h, tone(cc, 0.86 if xx % 2 == 0 else 1.0))
		Glass.DARK:
			fill(x, y, w, h, tone(g, 0.45), Part.GLASS)
			dot(x + w - 1, y, tone(g, 1.1))
		Glass.INTERIOR:
			fill(x, y, w, h, Color(0.07, 0.07, 0.075), Part.GLASS)
			var shelf: int = y + h * 3 / 5
			hline(x, shelf, w, Color(0.26, 0.21, 0.17))
			if h >= 5:
				fill(x + w / 3, shelf - 2, 1, 2, Color(0.24, 0.24, 0.27))
				if hash01(x, y, 12) < 0.5:
					fill(x + w - 2, y + 1, 1, h - 2, Color(0.2, 0.16, 0.14))
		Glass.BROKEN:
			fill(x, y, w, h, Color(0.04, 0.04, 0.05), Part.GLASS)
			var s: int = clampi(mini(w, h) / 2, 1, 3)
			for i: int in s:  # shards left in the frame
				hline(x, y + i, s - i, tone(g, 1.6))
				hline(x + w - (s - i), y + h - 1 - i, s - i, tone(g, 1.3))
			if w >= 4 and h >= 5:
				dot(x + w - 2, y + 1, tone(g, 1.4))
		Glass.BOARDED:
			fill(x, y, w, h, Color(0.05, 0.05, 0.05), Part.GLASS)
			var plank: Color = tone(WOOD, 0.9 + 0.2 * hash01(x, y, 13))
			if h >= 6:
				for py: int in [y + h / 4, y + h * 3 / 5]:
					hline(x - (1 if inside(x - 1, py) else 0), py, w + 1, plank, Part.TRIM)
					hline(x, py + 1, w, tone(plank, 0.7), Part.TRIM)
					dot(x + 1, py, tone(plank, 0.45))
					dot(x + w - 2, py, tone(plank, 0.45))
			else:
				for i: int in mini(w, h):
					dot(x + i, y + i, plank, Part.TRIM)
					dot(x + w - 1 - i, y + i, tone(plank, 0.85), Part.TRIM)
		Glass.MEMBRANE:
			fill(x, y, w, h, Color(0.6, 0.23, 0.26), Part.GROWTH)
			for yy: int in range(y, y + h):
				for xx: int in range(x, x + w):
					if absf(_noise.get_noise_2d(xx * 3.0, yy * 3.0)) < 0.1:
						dot(xx, yy, Color(0.36, 0.09, 0.13))
			dot(x + 1, y + 1, PUS)
		Glass.SHUTTER:
			for yy: int in range(y, y + h):
				hline(x, yy, w, tone(pick("metal"), 1.0 if (yy - y) % 2 == 0 else 0.74), Part.DOOR)


## A shut entrance at the base of the facade. Styles: wood, glass2 (chained double glass doors
## barricaded from inside), metal, roller, airlock, planks. `boarded` forces planks across.
func door(x: int, w: int, h: int, style: String, c: Color = Color(0, 0, 0, 0), boarded: int = -1) -> void:
	var y: int = height - h
	var trim: Color = pick("trim")
	if c.a == 0.0:
		c = pick("door")
	var board: bool = chance(0.15 + 0.4 * look.get("decay", 0.3)) if boarded < 0 else boarded == 1
	match style:
		"wood":
			fill(x - 1, y - 1, w + 2, h + 1, trim, Part.TRIM)
			fill(x, y, w, h, c, Part.DOOR)
			vline(x + w - 1, y, h, tone(c, 0.7))
			if h >= 9:
				fill(x + 1, y + 1, w - 2, 2, tone(pick("glass"), 0.6))
				fill(x + 1, y + 4, w - 2, h - 6, tone(c, 0.9))
			dot(x + w - 2, y + h / 2 + 1, Color(0.85, 0.76, 0.4))
		"glass2":
			var frame: Color = tone(pick("metal"), 0.7)
			fill(x - 1, y - 1, w + 2, h + 1, frame, Part.DOOR)
			_glass(x, y, w, h, Glass.DARK)
			vline(x + w / 2, y, h, frame, Part.DOOR)
			for xx: int in range(x, x + w):  # barricade piled up behind the glass
				var top: int = y + h - 2 - int(hash01(xx / 2, 0, 14) * h * 0.45)
				for yy: int in range(top, y + h):
					dot(xx, yy, tone(Color(0.24, 0.18, 0.13), 0.8 + 0.3 * hash01(xx, yy, 15)))
			for xx: int in range(x, x + w, 2):  # chain through the handles
				dot(xx, y + h / 2, Color(0.72, 0.72, 0.7))
		"metal":
			fill(x - 1, y - 1, w + 2, h + 1, tone(c, 0.6), Part.TRIM)
			fill(x, y, w, h, c, Part.DOOR)
			hline(x + 1, y + h / 2, w - 2, tone(c, 1.3))
			for xx: int in range(x, x + w):
				dot(xx, y + h - 2, HAZARD if (xx / 2) % 2 == 0 else OUTLINE)
		"roller":
			fill(x - 1, y - 1, w + 2, h + 1, tone(trim, 0.7), Part.TRIM)
			for yy: int in range(y, y + h):
				hline(x, yy, w, tone(c, 1.0 if (yy - y) % 2 == 0 else 0.76), Part.DOOR)
			hline(x, y + h - 1, w, tone(c, 0.5), Part.DOOR)
			for i: int in 3:  # dents
				dot(x + rand(1, w - 2), y + rand(1, h - 2), tone(c, 0.55))
			board = false
		"airlock":
			fill(x - 2, y - 2, w + 4, h + 2, OUTLINE, Part.TRIM)
			for yy: int in range(y - 2, y + h):
				for xx: int in [x - 2, x - 1, x + w, x + w + 1]:
					dot(xx, yy, HAZARD if ((xx + yy) / 2) % 2 == 0 else OUTLINE)
			fill(x, y, w, h, c, Part.DOOR)
			vline(x + w / 2, y, h, OUTLINE)
			fill(x + 1, y + 2, 2, 2, tone(pick("glass"), 0.8))
			fill(x + w - 3, y + 2, 2, 2, tone(pick("glass"), 0.8))
			fill(x + w / 2 - 1, y - 4, 2, 1, Color(0.95, 0.2, 0.18), Part.TRIM)
			board = false
		"planks":
			fill(x, y, w, h, tone(WOOD, 0.85), Part.DOOR)
			for xx: int in range(x, x + w):
				if (xx - x) % 3 == 2:
					vline(xx, y, h, tone(WOOD, 0.6))
			for i: int in w:  # Z brace
				dot(x + i, y + 2 + (h - 4) * i / maxi(w - 1, 1), tone(WOOD, 1.15))
	if board:
		for py: int in [y + h / 3, y + h * 2 / 3]:
			hline(x - 1, py, w + 2, tone(WOOD, 1.05), Part.TRIM)
			hline(x - 1, py + 1, w + 2, tone(WOOD, 0.7), Part.TRIM)
		if chance(0.5):  # a search mark sprayed across it
			var mx: int = x + w / 2 - 2
			for i: int in 5:
				dot(mx + i, y + 2 + i, Color(0.9, 0.42, 0.16))
				dot(mx + 4 - i, y + 2 + i, Color(0.9, 0.42, 0.16))
	hline(x - 2, height - 1, w + 4, tone(pick("concrete"), 1.1), Part.TRIM)
	_doors.append(Rect2i(x, y, w, h))


# --- signs and small details -----------------------------------------------------------------

func text(x: int, y: int, s: String, c: Color, part: Part = Part.SIGN) -> void:
	for i: int in s.length():
		var ch: String = s[i]
		for gy: int in PixelFont.GLYPH_H:
			for gx: int in PixelFont.GLYPH_W:
				if PixelFont.ink(ch, gx, gy):
					dot(x + i * PixelFont.ADVANCE + gx, y + gy, c, part)


## A sign board with centred lettering. Weathered: letters fall off (a faint ghost stays),
## one hangs askew, paint fades. `neon` draws glowing tubes on a dark board.
func signboard(x: int, y: int, w: int, h: int, label: String, bg: Color, fg: Color, neon: bool = false) -> void:
	fill(x, y, w, h, bg, Part.SIGN)
	hline(x, y, w, tone(bg, 1.25), Part.SIGN)
	hline(x, y + h - 1, w, tone(bg, 0.62), Part.SIGN)
	var d: float = look.get("decay", 0.3)
	var tw: int = PixelFont.width(label)
	if tw > w - 2:
		return
	var tx: int = x + (w - tw) / 2
	var ty: int = y + (h - PixelFont.GLYPH_H) / 2
	var askew: int = rand(0, label.length() - 1) if chance(d * 0.6) else -1
	for i: int in label.length():
		var ch: String = label.substr(i, 1)
		var col: Color = fg.lerp(bg, d * 0.35)
		var dy: int = 0
		if ch != " " and chance(d * 0.08):
			col = bg.lerp(fg, 0.4)  # fallen off: only its faded outline left on the board
		elif i == askew:
			dy = 1
		if neon:
			for gy: int in PixelFont.GLYPH_H:
				for gx: int in PixelFont.GLYPH_W:
					if PixelFont.ink(ch, gx, gy):
						for o: Vector2i in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
							var p: Vector2i = Vector2i(tx + i * PixelFont.ADVANCE + gx, ty + gy + dy) + o
							if part_at(p.x, p.y) == Part.SIGN and get_px(p.x, p.y).is_equal_approx(tone(bg, 1.0)):
								dot(p.x, p.y, bg.lerp(col, 0.3))
		text(tx + i * PixelFont.ADVANCE, ty + dy, ch, col)


func cross(x: int, y: int, s: int, c: Color, bg: Color) -> void:
	fill(x, y, s, s, bg, Part.SIGN)
	var t: int = maxi(s / 3, 1)
	fill(x + (s - t) / 2, y + 1, t, s - 2, c, Part.SIGN)
	fill(x + 1, y + (s - t) / 2, s - 2, t, c, Part.SIGN)


## Striped canvas awning over a shop window, torn in places.
func awning(x: int, y: int, w: int, h: int, c1: Color, c2: Color) -> void:
	var d: float = look.get("decay", 0.3)
	for xx: int in range(x, x + w):
		var torn: bool = hash01(xx / 4, y, 16) < d * 0.35
		var c: Color = c1 if (xx - x) / 3 % 2 == 0 else c2
		var drop: int = 2 if torn else 0
		for yy: int in range(y, y + h + drop):
			var k: float = 0.78 if yy == y else 1.0 - 0.06 * (yy - y)
			if torn and yy >= y + h:
				k = 0.7
			dot(xx, yy, tone(c, k), Part.PROP)
		if not torn and (xx - x) % 2 == 0:
			dot(xx, y + h, tone(c, 0.8), Part.PROP)
		if not torn:
			mul(xx, y + h + 1, 0.7)


func balcony(x: int, y: int, w: int, c: Color) -> void:
	hline(x, y, w, tone(c, 1.15), Part.TRIM)
	hline(x, y + 1, w, tone(c, 0.7), Part.TRIM)
	for xx: int in range(x, x + w):
		mul(xx, y + 2, 0.72)
	var rail: Color = tone(pick("metal"), 0.55)
	hline(x, y - 4, w, rail, Part.TRIM)
	for xx: int in range(x, x + w, 2):
		vline(xx, y - 3, 3, rail, Part.TRIM)
	if chance(0.3):  # a pot plant or drying laundry
		dot(x + rand(1, w - 2), y - 1, LEAF if chance(0.5) else pick("curtain"))


## Iron fire escape down one bay: a landing per storey, zigzag stairs, ladder at the bottom.
func fire_escape(x: int, w: int, y_top: int, storey_h: int, levels: int) -> void:
	var iron: Color = Color(0.13, 0.13, 0.15)
	for i: int in levels:
		var ly: int = y_top + (i + 1) * storey_h - 1
		hline(x, ly, w, iron, Part.TRIM)
		hline(x, ly - 3, w, iron, Part.TRIM)
		vline(x, ly - 3, 3, iron, Part.TRIM)
		vline(x + w - 1, ly - 3, 3, iron, Part.TRIM)
		if i < levels - 1:
			for k: int in storey_h:
				var sx: int = x + 1 + (k * (w - 2)) / storey_h if i % 2 == 0 else x + w - 2 - (k * (w - 2)) / storey_h
				dot(sx, ly + k, iron, Part.TRIM)
	var ladder_top: int = y_top + levels * storey_h
	for yy: int in range(ladder_top, height - 4):
		dot(x + 1, yy, iron, Part.TRIM)
		dot(x + 3, yy, iron, Part.TRIM)
		if yy % 2 == 0:
			dot(x + 2, yy, iron, Part.TRIM)


func ac_unit(x: int, y: int) -> void:
	var c: Color = tone(pick("metal"), 1.25)
	fill(x, y, 6, 4, c, Part.PROP)
	hline(x, y, 6, tone(c, 1.15), Part.PROP)
	fill(x + 1, y + 1, 3, 2, tone(c, 0.5), Part.PROP)
	dot(x + 2, y + 1, tone(c, 0.8))
	hline(x, y + 4, 6, tone(get_px(x, y + 4), 0.6))


func water_tank(x: int, y: int) -> void:
	var c: Color = tone(WOOD, 0.8)
	fill(x, y, 7, 6, c, Part.PROP)
	for yy: int in range(y, y + 6, 2):
		hline(x, yy, 7, tone(c, 0.7))
	fill(x - 1, y - 1, 9, 1, tone(c, 0.6), Part.PROP)
	vline(x, y + 6, 2, OUTLINE, Part.PROP)
	vline(x + 6, y + 6, 2, OUTLINE, Part.PROP)


func antenna(x: int, y: int, h: int) -> void:
	vline(x, y, h, OUTLINE, Part.PROP)
	for i: int in range(1, h / 3):
		hline(x - 1, y + i * 3, 3, OUTLINE, Part.PROP)


func chimney(x: int, y: int, w: int, h: int, c: Color) -> void:
	wall(x, y, w, h, Surface.BRICK, c)
	hline(x - 1, y, w + 2, tone(c, 1.25), Part.WALL)
	hline(x, y + 1, w, OUTLINE, Part.WALL)
	for yy: int in range(y + 1, y + h):
		mul(x + w, yy, 0.7)


## Billboard on the roof, facing the street: Sunnyseed's cheerful advert, faded and peeling.
func billboard(x: int, y: int, w: int, h: int) -> void:
	vline(x + 3, y + h, 3, OUTLINE, Part.PROP)
	vline(x + w - 4, y + h, 3, OUTLINE, Part.PROP)
	fill(x - 1, y - 1, w + 2, h + 2, OUTLINE, Part.SIGN)
	signboard(x, y, w, h, "SUNNYSEED" if w >= 38 else "SEED", Color(0.92, 0.78, 0.26), Color(0.22, 0.46, 0.2))
	for i: int in 4:  # paper peeling off in strips
		var px: int = x + rand(1, w - 3)
		fill(px, y + rand(1, h - 3), 2, rand(2, 3), Color(0.82, 0.8, 0.72), Part.SIGN)


func bush(x: int, y: int, w: int, h: int) -> void:
	for xx: int in range(x, x + w):
		var top: int = y + int(hash01(xx / 2, y, 17) * 2.0)
		for yy: int in range(top, y + h):
			var c: Color = tone(LEAF, 0.8 + 0.4 * hash01(xx, yy, 18))
			if yy == top:
				c = tone(LEAF, 1.25)
			elif yy == y + h - 1:
				c = tone(LEAF, 0.55)
			dot(xx, yy, c, Part.PROP)


func sandbags(x: int, y: int, w: int, rows: int) -> void:
	var bag: Color = Color(0.62, 0.55, 0.4)
	for r: int in rows:
		var yy: int = y - r * 2
		for xx: int in range(x + (r % 2) * 2, x + w, 4):
			fill(xx, yy, 4, 2, bag, Part.PROP)
			hline(xx, yy, 4, tone(bag, 1.2), Part.PROP)
			dot(xx + 3, yy + 1, tone(bag, 0.6), Part.PROP)


func crate(x: int, y: int, s: int) -> void:
	fill(x, y, s, s, WOOD, Part.PROP)
	hline(x, y, s, tone(WOOD, 1.25), Part.PROP)
	vline(x + s - 1, y, s, tone(WOOD, 0.6), Part.PROP)
	for i: int in s:
		dot(x + i, y + i, tone(WOOD, 0.75))


func barrel(x: int, y: int, c: Color) -> void:
	fill(x, y, 4, 5, c, Part.PROP)
	vline(x, y, 5, tone(c, 1.25), Part.PROP)
	vline(x + 3, y, 5, tone(c, 0.65), Part.PROP)
	hline(x, y + 1, 4, tone(c, 0.7), Part.PROP)
	hline(x, y + 3, 4, tone(c, 0.7), Part.PROP)


## Shopping cart seen from the side.
func cart(x: int, y: int) -> void:
	var wire: Color = Color(0.72, 0.74, 0.76)
	hline(x, y, 7, wire, Part.PROP)
	for xx: int in range(x + 1, x + 7, 2):
		vline(xx, y, 3, wire, Part.PROP)
	hline(x + 1, y + 3, 6, wire, Part.PROP)
	vline(x, y - 2, 2, wire, Part.PROP)
	dot(x + 2, y + 4, OUTLINE, Part.PROP)
	dot(x + 6, y + 4, OUTLINE, Part.PROP)


## A parked vehicle seen from the side (inside the footprint, where it collides anyway).
func vehicle(x: int, y: int, w: int, body: Color, kind: String = "car") -> void:
	var h: int = 7 if kind == "car" else 10
	var top: int = y - h
	fill(x, top + 3, w, h - 4, body, Part.PROP)
	var cab: int = w / 2 if kind == "car" else w / 3
	var cx: int = x + (w - cab) / 2 if kind == "car" else x + w - cab
	fill(cx, top, cab, 4, body, Part.PROP)
	fill(cx + 1, top + 1, cab - 2, 2, tone(pick("glass"), 0.7), Part.PROP)
	hline(x, top + 3, w, tone(body, 1.2), Part.PROP)
	hline(x, y - 2, w, tone(body, 0.6), Part.PROP)
	for wx: int in [x + 2, x + w - 5]:
		fill(wx, y - 2, 3, 2, OUTLINE, Part.PROP)
	if kind == "ambulance":
		hline(x, top + 6, w - cab, Color(0.8, 0.18, 0.16), Part.PROP)
		cross(x + 2, top + 1, 5, Color(0.8, 0.18, 0.16), body)
		fill(cx + 1, top - 1, 3, 1, Color(0.9, 0.2, 0.2), Part.PROP)
		fill(cx + 4, top - 1, 2, 1, Color(0.25, 0.45, 0.9), Part.PROP)
	elif kind == "police":
		hline(x, top + 5, w, Color(0.2, 0.3, 0.6), Part.PROP)
		fill(cx + 1, top - 1, 2, 1, Color(0.9, 0.2, 0.2), Part.PROP)
		fill(cx + 3, top - 1, 2, 1, Color(0.25, 0.45, 0.9), Part.PROP)
	for i: int in int(4 * look.get("decay", 0.3)) + 1:  # rust and dents
		dot(x + rand(0, w - 1), y - rand(3, h - 1), RUST)


func hazard(x: int, y: int, w: int, h: int) -> void:
	for yy: int in range(y, y + h):
		for xx: int in range(x, x + w):
			dot(xx, yy, HAZARD if ((xx + yy) / 2) % 2 == 0 else OUTLINE, Part.TRIM)


## Yellow warning sign with a black "!" (biohazard / danger).
func warning(x: int, y: int) -> void:
	fill(x, y, 5, 6, OUTLINE, Part.SIGN)
	fill(x + 1, y + 1, 3, 4, HAZARD, Part.SIGN)
	vline(x + 2, y + 1, 2, OUTLINE, Part.SIGN)
	dot(x + 2, y + 4, OUTLINE, Part.SIGN)


func pipe(x: int, y: int, h: int, c: Color) -> void:
	vline(x, y, h, tone(c, 1.2), Part.PROP)
	vline(x + 1, y, h, tone(c, 0.7), Part.PROP)
	for yy: int in range(y + 2, y + h, 6):
		hline(x - 1, yy, 4, tone(c, 0.5), Part.PROP)


func vent(x: int, y: int, w: int, h: int) -> void:
	var c: Color = tone(pick("metal"), 1.1)
	fill(x, y, w, h, c, Part.PROP)
	for yy: int in range(y + 1, y + h - 1, 2):
		hline(x + 1, yy, w - 2, tone(c, 0.55), Part.PROP)
	hline(x, y + h, w, tone(get_px(x, y + h), 0.6))


func flag(x: int, y: int, h: int, c: Color) -> void:
	vline(x, y, h, Color(0.8, 0.8, 0.8), Part.PROP)
	for yy: int in range(y + 1, y + 4):
		for xx: int in range(x + 1, x + 6):
			if hash01(xx, yy, 19) > 0.2 or xx < x + 4:
				dot(xx, yy, tone(c, 1.0 if yy < y + 3 else 0.75), Part.PROP)


func clock(x: int, y: int) -> void:
	fill(x + 1, y, 3, 5, Color(0.9, 0.88, 0.8), Part.SIGN)
	fill(x, y + 1, 5, 3, Color(0.9, 0.88, 0.8), Part.SIGN)
	dot(x + 2, y + 1, OUTLINE)
	dot(x + 2, y + 2, OUTLINE)
	dot(x + 3, y + 2, OUTLINE)


func lamp(x: int, y: int) -> void:
	fill(x, y, 2, 2, OUTLINE, Part.PROP)
	dot(x, y + 1, Color(0.8, 0.74, 0.5), Part.PROP)


func solar(x: int, y: int, w: int, h: int) -> void:
	fill(x, y, w, h, Color(0.14, 0.2, 0.36), Part.PROP)
	for xx: int in range(x, x + w, 3):
		vline(xx, y, h, Color(0.4, 0.48, 0.6), Part.PROP)
	hline(x, y, w, Color(0.5, 0.58, 0.7), Part.PROP)


func log_pile(x: int, y: int, w: int, rows: int) -> void:
	for r: int in rows:
		for xx: int in range(x + (r % 2), x + w - 1, 3):
			var yy: int = y - r * 3
			fill(xx, yy, 3, 3, Color(0.42, 0.3, 0.2), Part.PROP)
			dot(xx + 1, yy + 1, Color(0.76, 0.62, 0.42), Part.PROP)


func container(x: int, y: int, w: int, h: int, c: Color) -> void:
	wall(x, y, w, h, Surface.METAL, c)
	hline(x, y, w, tone(c, 1.3), Part.WALL)
	hline(x, y + h - 1, w, tone(c, 0.55), Part.WALL)
	vline(x + w / 2, y + 1, h - 2, tone(c, 0.5), Part.WALL)
	for xx: int in [x + w / 2 - 2, x + w / 2 + 2]:
		vline(xx, y + 2, h - 4, tone(c, 0.7), Part.WALL)


## A canvas tent seen from the front, its flap tied shut.
func tent(x: int, y: int, w: int, h: int, c: Color, red_cross: bool) -> void:
	for yy: int in range(y, y + h):
		var t: float = float(yy - y + 1) / h
		var half: int = maxi(int(w / 2.0 * minf(t * 1.6, 1.0)), 1)
		var cx: int = x + w / 2
		for xx: int in range(cx - half, cx + half):
			dot(xx, yy, tone(c, 1.1 if xx < cx else 0.86), Part.PROP)
	fill(x + w / 2 - 2, y + h - 6, 4, 6, tone(c, 0.6), Part.PROP)
	vline(x + w / 2, y + h - 6, 6, tone(c, 0.4), Part.PROP)
	if red_cross:
		cross(x + w / 2 - 3, y + h / 3 - 1, 7, Color(0.78, 0.18, 0.16), tone(c, 1.1))


## Concrete jersey barriers and a lowered red / white boom across the front.
func barriers(x: int, w: int) -> void:
	var c: Color = Color(0.68, 0.68, 0.66)
	for bx: int in range(x, x + w - 7, 9):
		fill(bx, height - 4, 8, 4, c, Part.PROP)
		hline(bx + 1, height - 5, 6, tone(c, 1.15), Part.PROP)
		hline(bx, height - 1, 8, tone(c, 0.6), Part.PROP)
		hline(bx + 1, height - 3, 6, Color(0.85, 0.3, 0.2), Part.PROP)


func floodlight(x: int, y: int, h: int) -> void:
	vline(x, y, h, OUTLINE, Part.PROP)
	fill(x - 2, y, 5, 2, Color(0.25, 0.25, 0.26), Part.PROP)
	hline(x - 1, y + 1, 3, Color(0.86, 0.84, 0.7), Part.PROP)


## Hanging cable sagging across the facade between two points.
func cable(x0: int, x1: int, y: int, sag: int) -> void:
	var half: float = (x1 - x0) / 2.0
	for xx: int in range(x0, x1 + 1):
		var t: float = (xx - x0 - half) / maxf(half, 1.0)
		dot(xx, y + int(sag * (1.0 - t * t)), Color(0.08, 0.08, 0.09))


# --- passes ----------------------------------------------------------------------------------

## A top corner broken away: the floors behind show through, rubble heaped below.
func _collapse() -> void:
	var left: bool = chance(0.5)
	var cw: int = int(fw * rng.randf_range(0.28, 0.42))
	var ch: int = facade_top + int((height - facade_top) * rng.randf_range(0.35, 0.5))
	var wall_c: Color = tone(pick("concrete"), 0.4)
	var st: int = maxi((height - facade_top) / maxi(storeys, 1), 8)
	for yy: int in ch:
		var reach: float = cw * (1.0 - float(yy) / ch) + 4.0 * _noise.get_noise_2d(yy * 4.0, 7.0)
		for i: int in int(maxf(reach, 0.0)):
			var xx: int = i if left else fw - 1 - i
			var c: Color = tone(wall_c, 0.8 + 0.3 * hash01(xx / 3, yy / 3, 20))
			if yy >= facade_top and (height - yy) % st == 0:
				c = tone(pick("concrete"), 1.05)  # floor slab edge
			elif yy >= facade_top and (height - yy) % st == 1:
				c = OUTLINE
			dot(xx, yy, c, Part.DARK)
		var edge: int = int(maxf(reach, 0.0))
		var ex: int = edge if left else fw - 1 - edge
		dot(ex, yy, tone(pick("concrete"), 1.2))
		if yy % 4 == 0 and yy >= facade_top:
			dot(ex + (-1 if left else 1), yy, RUST)  # rebar sticking out
	var x0: int = 0 if left else fw - cw - 4
	for xx: int in range(x0, x0 + cw + 4):  # the heap at the foot of the break
		var u: float = float(xx - x0) / (cw + 4)
		var top: int = height - 2 - int(9.0 * sin(u * PI) * (0.7 + 0.3 * hash01(xx, 0, 21)))
		for yy: int in range(top, height):
			var k: float = 0.7 + 0.5 * hash01(xx / 2, yy / 2, 22)
			dot(xx, yy, tone(pick("concrete") if hash01(xx / 2, yy / 2, 23) < 0.6 else wall_c * 2.0, k), Part.PROP)
		dot(xx, top, tone(pick("concrete"), 1.25))
		for yy: int in range(height, height + 3):
			if hash01(xx, yy, 24) < 0.3:
				ground_dot(xx, yy, tone(pick("concrete"), 0.8))


## Weathering: water stains under sills and the roof line, cracks, a hanging cable, posters,
## graffiti and the odd blood smear by a door.
func _weather() -> void:
	var d: float = look.get("decay", 0.3)
	for r: Rect2i in _windows:  # streaks under the sills
		if hash01(r.position.x, r.position.y, 25) < 0.3 + 0.5 * d:
			var span: int = rand(3, 8)
			for yy: int in range(r.end.y + 1, r.end.y + 1 + span):
				for xx: int in [r.position.x + 1, r.end.x - 2]:
					if part_at(xx, yy) == Part.WALL:
						mul(xx, yy, 0.9 - 0.02 * (r.end.y + span - yy))
	for xx: int in fw:  # grime running down from the roof line
		if hash01(xx / 2, 0, 26) < 0.25 + 0.4 * d:
			for yy: int in range(facade_top + 2, facade_top + 2 + rand(2, 7)):
				if part_at(xx, yy) == Part.WALL:
					mul(xx, yy, 0.88)
	for i: int in int(round(d * 4.0)):  # cracks
		var p: Vector2i = Vector2i(rand(2, fw - 3), rand(facade_top + 2, height - 6))
		if not _windows.is_empty() and chance(0.6):
			var r: Rect2i = _windows[rand(0, _windows.size() - 1)]
			p = Vector2i(r.end.x, r.position.y) if chance(0.5) else r.end
		for k: int in rand(6, 14):
			if part_at(p.x, p.y) == Part.WALL:
				dot(p.x, p.y, tone(get_px(p.x, p.y), 0.45))
			p += Vector2i(rand(-1, 1), 1 if chance(0.7) else -1)
	if chance(0.25 + 0.4 * d) and fw > 24:
		var y: int = facade_top + rand(2, 8)
		cable(rand(0, 6), fw - rand(1, 8), y, rand(3, 7))
	for i: int in rand(0, 2):  # torn posters by the street
		var px: int = rand(2, fw - 6)
		var py: int = height - rand(8, 12)
		if part_at(px, py) == Part.WALL and part_at(px + 3, py + 4) == Part.WALL:
			fill(px, py, 3, 4, Color(0.82, 0.8, 0.7))
			dot(px + 1, py + 1, pick("accent"))
	if chance(0.2 + 0.4 * d):  # a graffiti tag low on the wall
		var gx: int = rand(2, fw - 10)
		var gy: int = height - rand(5, 9)
		var gc: Color = [Color(0.8, 0.3, 0.5), Color(0.3, 0.6, 0.8), Color(0.9, 0.8, 0.3)][rand(0, 2)]
		for k: int in 8:
			var p: Vector2i = Vector2i(gx + k, gy + int(1.5 * sin(k * 1.3)))
			if part_at(p.x, p.y) == Part.WALL:
				dot(p.x, p.y, tone(gc, 0.85))
	for r: Rect2i in _doors:  # signs of a struggle
		if chance(0.15 + 0.35 * d):
			var bx: int = r.end.x + 1
			for k: int in 4:
				if part_at(bx + k, r.position.y + 3 + k / 2) == Part.WALL:
					dot(bx + k, r.position.y + 3 + k / 2, BLOOD)
					dot(bx + k, r.position.y + 5 + k, tone(BLOOD, 0.8))


## Lowtide: a dark tide line across the facade, green stain and algae below it.
func _flood() -> void:
	var line: int = height - rand(8, 12)
	var stain: Color = Color(0.17, 0.27, 0.22)
	for xx: int in width:
		var wobble: int = int(_noise.get_noise_2d(xx * 2.0, 3.0) * 1.5)
		for yy: int in range(line + wobble, height):
			var p: Part = part_at(xx, yy)
			if p == Part.WALL or p == Part.DOOR or p == Part.TRIM:
				mix(xx, yy, stain, 0.42 + 0.1 * float(yy - line) / 10.0)
				if hash01(xx, yy, 27) < 0.07:
					dot(xx, yy, Color(0.3, 0.46, 0.26))
			elif p == Part.GLASS:
				mix(xx, yy, Color(0.1, 0.18, 0.16), 0.5)
		mix(xx, line + wobble, Color(0.12, 0.1, 0.08), 0.6)
		mix(xx, line + wobble - 2, stain, 0.18)


## Burned out: soot plumes over a window or two, embers inside, a charred patch on the roof.
func _burn() -> void:
	var count: int = mini(rand(1, 2), _windows.size())
	for i: int in count:
		var r: Rect2i = _windows[rand(0, _windows.size() - 1)]
		fill(r.position.x + 1, r.position.y + 1, r.size.x - 2, r.size.y - 2, Color(0.12, 0.05, 0.03), Part.GLASS)
		for k: int in 3:
			dot(r.position.x + rand(1, r.size.x - 2), r.end.y - 2 - rand(0, 1), EMBER)
		fires.append(Vector2(r.position.x + r.size.x / 2.0 + MARGIN, r.position.y + r.size.y / 2.0 + MARGIN))
		for yy: int in range(maxi(r.position.y - 12, 0), r.position.y + 1):
			var spread: int = (r.position.y - yy) / 2 + r.size.x / 2
			var cx: int = r.position.x + r.size.x / 2
			for xx: int in range(cx - spread, cx + spread + 1):
				var t: float = 1.0 - float(r.position.y - yy) / 13.0
				if hash01(xx, yy, 28) < 0.85:
					mix(xx, yy, CHAR, 0.55 * t)
	for yy: int in facade_top:
		for xx: int in fw:
			var n: float = _noise.get_noise_2d(xx * 0.8 + 40.0, yy * 0.8) * 0.5 + 0.5
			if n > 0.66:
				mix(xx, yy, CHAR, clampf((n - 0.66) * 3.0, 0.0, 0.8))


## Nature taking it back: ivy climbing from the base, moss on the roof, weeds along the foot.
func _overgrow() -> void:
	var o: float = look.get("overgrowth", 0.2)
	if o <= 0.0:
		return
	for i: int in int(round(o * fw / 10.0)):
		var p: Vector2 = Vector2(rand(1, fw - 2), height - 1)
		var top: int = int(height - (height - facade_top) * o * rng.randf_range(0.5, 1.1))
		while p.y > top:
			var xx: int = int(p.x)
			var yy: int = int(p.y)
			var part: Part = part_at(xx, yy)
			if part == Part.WALL or part == Part.TRIM or part == Part.GLASS:
				dot(xx, yy, tone(LEAF, 0.7), Part.GROWTH)
				if hash01(xx, yy, 29) < 0.55:
					dot(xx + (1 if hash01(xx, yy, 30) < 0.5 else -1), yy, tone(LEAF, 1.0 + 0.3 * hash01(yy, xx, 31)), Part.GROWTH)
			p += Vector2(rng.randf_range(-0.8, 0.8), -1.0)
	for yy: int in facade_top:
		for xx: int in width:
			if part_at(xx, yy) == Part.ROOF and _noise.get_noise_2d(xx * 1.4, yy * 1.4 + 90.0) * 0.5 + 0.5 > 1.0 - o * 0.5:
				dot(xx, yy, tone(LEAF, 0.7 + 0.35 * hash01(xx, yy, 32)), Part.GROWTH)
	for xx: int in fw:
		if hash01(xx, 0, 33) < o * 0.8:
			var h: int = 1 + int(hash01(xx, 1, 34) * 3.0 * o)
			for yy: int in range(height - h, height):
				dot(xx, yy, tone(LEAF, 0.8 + 0.4 * hash01(xx, yy, 35)), Part.GROWTH)


## The Bloom: fleshy growth with veins and pustules spreading over walls and roof, tendrils
## hanging from the roof line, swollen masses along the base when it runs deep.
func _infect() -> void:
	var inf: float = look.get("infection", 0.0)
	if inf <= 0.02:
		return
	var patches: int = int(inf * 4.0) + (1 if inf > 0.12 else 0)
	for i: int in patches:
		var centre: Vector2 = Vector2(rand(0, width - 1), rand(0, height - 1))
		if i == 0 and inf > 0.6:
			centre = Vector2(rand(0, width - 1), rand(0, facade_top))  # the roof goes first
		_flesh_patch(centre, 3.0 + inf * 13.0 * rng.randf_range(0.6, 1.2))
	for i: int in int(inf * fw / 9.0) + (1 if inf > 0.15 else 0):
		var x: float = rand(1, fw - 2)
		var span: int = int(4 + inf * 24 * rng.randf_range(0.4, 1.0))
		for k: int in span:
			var yy: int = facade_top - 1 + k
			var xx: int = int(x + sin(k * 0.5 + i) * 1.2)
			dot(xx, yy, tone(FLESH, 0.9 + 0.3 * hash01(xx, yy, 36)), Part.GROWTH)
			if inf > 0.45:
				dot(xx + 1, yy, tone(FLESH, 0.7), Part.GROWTH)
		dot(int(x), facade_top - 1 + span, PUS)
	if inf > 0.5:
		for xx: int in width:
			var h: float = (inf - 0.4) * 14.0 * (_noise.get_noise_2d(xx * 1.8, 50.0) * 0.5 + 0.5)
			for yy: int in range(height - int(h), height):
				var c: Color = tone(FLESH, 0.75 + 0.45 * float(height - yy) / maxf(h, 1.0))
				if absf(_noise.get_noise_2d(xx * 3.0, yy * 3.0)) < 0.06:
					c = VEIN
				dot(xx, yy, c, Part.GROWTH)


func _flesh_patch(centre: Vector2, radius: float) -> void:
	for yy: int in range(int(centre.y - radius), int(centre.y + radius) + 1):
		for xx: int in range(int(centre.x - radius), int(centre.x + radius) + 1):
			if not inside(xx, yy):
				continue
			var d: float = Vector2(xx, yy).distance_to(centre) / radius
			var n: float = _noise.get_noise_2d(xx * 1.7, yy * 1.7) * 0.5 + 0.5
			if d < 0.5 + 0.5 * n:
				var c: Color = tone(FLESH, 0.8 + 0.35 * n)
				if absf(_noise.get_noise_2d(xx * 2.6 + 9.0, yy * 2.6)) < 0.07:
					c = VEIN
				elif hash01(xx, yy, 37) < 0.025:
					c = PUS
				elif d > 0.85:
					c = tone(FLESH, 0.6)
				dot(xx, yy, c, Part.GROWTH)


## Shadow on the ground east of the building (longer the taller it is) and a contact shadow along
## the foot of the facade.
func _shadow() -> void:
	var span: int = clampi(2 + storeys * 2, 3, MARGIN - 1)
	for yy: int in range(span / 2, height + 2):
		for i: int in span:
			var a: float = 0.36 if i < span - 2 else 0.22
			ground_dot(width + i, yy, Color(0, 0, 0, a))
	for xx: int in range(0, width + span):
		ground_dot(xx, height, Color(0, 0, 0, 0.32))
		ground_dot(xx, height + 1, Color(0, 0, 0, 0.16))

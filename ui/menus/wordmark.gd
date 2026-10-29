class_name Wordmark
extends Control
## The AMORTIA logo: chunky pixel letters (7-row glyphs, BLOCK px per glyph pixel) in bone white
## that rot to dried-blood red towards the bottom, with ragged eaten edges, a crack running
## through the word, blood dripping off the letters and a slow red glow behind. Baked to
## textures once; per frame only the glow pulses and one drip falls.

const BLOCK: int = 5
const BONE: Color = Color("#d6cdbd")
const BLOOD: Color = Color("#6d252a")
const CHARCOAL: Color = Color("#111419")
const DRIP_ROOM: int = 16
const GLOW: int = 4
const GLYPHS: Dictionary[String, Array] = {
	"A": [".###.", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
	"M": ["#.....#", "##...##", "#.#.#.#", "#..#..#", "#.....#", "#.....#", "#.....#"],
	"O": [".###.", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
	"R": ["####.", "#...#", "#...#", "####.", "#.#..", "#..#.", "#...#"],
	"T": ["#####", "..#..", "..#..", "..#..", "..#..", "..#..", "..#.."],
	"I": ["###", ".#.", ".#.", ".#.", ".#.", ".#.", "###"],
}

@export var text: String = "AMORTIA"

var _letters: ImageTexture
var _glow: ImageTexture
var _drip_from: Vector2 = Vector2.ZERO
var _time: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_bake()


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	if _letters == null:
		return
	var at: Vector2 = ((size - Vector2(_letters.get_size())) / 2.0).floor()
	var pulse: float = 0.55 + 0.45 * sin(_time * 1.3)
	draw_texture(_glow, at - Vector2(GLOW, GLOW), Color(1, 1, 1, 0.22 + 0.25 * pulse))
	draw_texture(_letters, at + Vector2(1, 2), Color(0, 0, 0, 0.8))  # drop shadow
	draw_texture(_letters, at)
	# A drop of blood slowly gathering, falling and fading under one letter.
	var t: float = fmod(_time, 5.0) / 5.0
	if _drip_from != Vector2.ZERO and t > 0.35:
		var fall: float = (t - 0.35) / 0.65
		var p: Vector2 = at + _drip_from + Vector2(0, floorf(fall * fall * 20.0))
		draw_rect(Rect2(p, Vector2(1, 2)), Color(0.55, 0.12, 0.14, 1.0 - fall))


func _bake() -> void:
	var widths: Array[int] = []
	for ch: String in text:
		widths.append((GLYPHS[ch][0] as String).length() if GLYPHS.has(ch) else 3)
	var cols: int = 0
	for w: int in widths:
		cols += w + 1
	cols -= 1
	var mask_w: int = cols * BLOCK
	var letter_h: int = 7 * BLOCK
	var img: Image = Image.create(mask_w, letter_h + DRIP_ROOM, false, Image.FORMAT_RGBA8)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 6277
	# Glyph pixel grid (block columns x 7 rows) of the whole word.
	var grid: Array[PackedByteArray] = []
	for r: int in 7:
		var row: PackedByteArray = PackedByteArray()
		row.resize(cols)
		grid.append(row)
	var col0: int = 0
	for i: int in text.length():
		var ch: String = text[i]
		if GLYPHS.has(ch):
			for r: int in 7:
				var line: String = GLYPHS[ch][r]
				for c: int in line.length():
					if line[c] == "#":
						grid[r][col0 + c] = 1
		col0 += widths[i] + 1
	var on: Callable = func(c: int, r: int) -> bool:
		return r >= 0 and r < 7 and c >= 0 and c < cols and grid[r][c] == 1
	var rot: Color = Color(0.6, 0.2, 0.2)
	for r: int in 7:
		for c: int in cols:
			if not on.call(c, r):
				continue
			for sy: int in BLOCK:
				for sx: int in BLOCK:
					var x: int = c * BLOCK + sx
					var y: int = r * BLOCK + sy
					var edge_top: bool = sy == 0 and not on.call(c, r - 1)
					var edge_bottom: bool = sy == BLOCK - 1 and not on.call(c, r + 1)
					var edge_side: bool = (sx == 0 and not on.call(c - 1, r)) or (sx == BLOCK - 1 and not on.call(c + 1, r))
					# Eaten edges: outline pixels go missing now and then.
					if (edge_top or edge_bottom or edge_side) and rng.randf() < 0.22:
						continue
					var k: float = smoothstep(0.3, 1.0, float(y) / letter_h)
					var col: Color = BONE.lerp(rot, k)
					if edge_top:
						col = col.lightened(0.15)
					elif edge_bottom or (sx == BLOCK - 1 and not on.call(c + 1, r)):
						col = col.darkened(0.4)
					if rng.randf() < 0.05:  # pits
						col = col.darkened(0.5)
					img.set_pixel(x, y, col)
	# A crack through the whole word, descending left to right.
	var cy: float = letter_h * 0.62
	for x: int in mask_w:
		cy += rng.randf_range(-0.6, 0.85) * 0.9
		cy = clampf(cy, 3.0, letter_h - 4.0)
		var y: int = int(cy)
		if img.get_pixel(x, y).a > 0.0:
			img.set_pixel(x, y, Color(0, 0, 0, 0))
			if img.get_pixel(x, y + 1).a > 0.0:
				img.set_pixel(x, y + 1, img.get_pixel(x, y + 1).darkened(0.55))
	# Blood running off the bottom of some strokes.
	var bottoms: Array[int] = []
	for c: int in cols:
		if on.call(c, 6):
			bottoms.append(c)
	for i: int in 7:
		var c: int = bottoms[rng.randi() % bottoms.size()]
		var x: int = c * BLOCK + rng.randi_range(1, BLOCK - 2)
		var length: int = rng.randi_range(3, DRIP_ROOM - 4)
		for y: int in length:
			img.set_pixel(x, letter_h + y, Color(0.5, 0.11, 0.13))
			if y < length / 3.0:
				img.set_pixel(x + 1, letter_h + y, Color(0.42, 0.09, 0.11))
		img.set_pixel(x, letter_h + length, Color(0.62, 0.16, 0.17))
		img.set_pixel(x + 1, letter_h + length, Color(0.5, 0.11, 0.13))
		if _drip_from == Vector2.ZERO:
			_drip_from = Vector2(x, letter_h + length + 1)
	_letters = ImageTexture.create_from_image(img)
	_glow = ImageTexture.create_from_image(_glow_image(img))
	custom_minimum_size = Vector2(img.get_width() + 4, img.get_height() + 2)


## Dithered dried-blood halo GLOW px around every letter pixel.
func _glow_image(letters: Image) -> Image:
	var bayer: Array[int] = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]
	var w: int = letters.get_width() + GLOW * 2
	var h: int = letters.get_height() + GLOW * 2
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	var near: Array[float] = []
	near.resize(w * h)
	near.fill(0.0)
	for y: int in letters.get_height():
		for x: int in letters.get_width():
			if letters.get_pixel(x, y).a <= 0.0 or y >= 7 * BLOCK:
				continue
			for dy: int in range(-GLOW, GLOW + 1):
				for dx: int in range(-GLOW, GLOW + 1):
					var v: float = 1.0 - Vector2(dx, dy).length() / (GLOW + 1.0)
					var i: int = (y + dy + GLOW) * w + (x + dx + GLOW)
					near[i] = maxf(near[i], v)
	for y: int in h:
		for x: int in w:
			var v: float = near[y * w + x]
			if v > bayer[(y % 4) * 4 + x % 4] / 16.0:
				img.set_pixel(x, y, Color(BLOOD.lightened(0.1), 0.55 * v + 0.2))
	return img

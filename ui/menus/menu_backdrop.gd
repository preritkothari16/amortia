class_name MenuBackdrop
extends Control
## Main menu background: a dark, dithered sky over a ruined skyline (broken roofs, a few lit
## windows, sagging power lines), a dried-blood glow behind the logo, infected veins creeping up
## from the corners and ground mist; drifting ash and red spores move over it. The still part is
## baked into one texture (rebuilt on resize), only the motes and one flickering window are
## drawn per frame. Look only, ignores the mouse.

const CHARCOAL: Color = Color("#111419")
const INFECTED: Color = Color("#29362f")
const BLOOD: Color = Color("#6d252a")
const RUST: Color = Color("#a34635")
const BONE: Color = Color("#d6cdbd")
const BAYER: Array[int] = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]
const MOTES: int = 46

## Where the glow sits (fraction of the size), so it lines up behind the wordmark.
@export var glow_center: Vector2 = Vector2(0.5, 0.26)

var _baked: ImageTexture
var _baked_size: Vector2i = Vector2i.ZERO
var _motes: Array = []  # [Vector2 position, Vector2 velocity, bool red, float phase]
var _windows: Array[Vector2] = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _time: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_rng.seed = 1213
	resized.connect(_bake)
	_bake()


func _process(delta: float) -> void:
	_time += delta
	for m: Array in _motes:
		m[0] += m[1] * delta + Vector2(sin(_time * 0.9 + m[3]) * 2.0 * delta, 0.0)
		if m[0].y < -2.0 or m[0].x > size.x + 2.0:
			m[0] = Vector2(_rng.randf_range(-20.0, size.x), size.y + 2.0)
	queue_redraw()


func _draw() -> void:
	if _baked != null:
		draw_texture_rect(_baked, Rect2(Vector2.ZERO, Vector2(_baked_size)), false)
	# One window on the skyline buzzes on and off.
	if not _windows.is_empty():
		var w: Vector2 = _windows[0]
		var on: bool = fmod(_time * 1.7, 3.0) < 2.2 and fmod(_time * 13.0, 1.0) > 0.15
		draw_rect(Rect2(w, Vector2(2, 2)), Color(RUST.lightened(0.3), 0.85) if on else Color(0.1, 0.05, 0.05))
	# Breathing glow over the baked one: a thin dithered ring pulsing in alpha.
	var pulse: float = 0.5 + 0.5 * sin(_time * 1.3)
	var c: Vector2 = size * glow_center
	draw_rect(Rect2(c - Vector2(120, 2), Vector2(240, 1)), Color(BLOOD, 0.12 + 0.1 * pulse))
	for m: Array in _motes:
		var p: Vector2 = (m[0] as Vector2).floor()
		var twinkle: float = 0.5 + 0.5 * sin(_time * 2.0 + m[3])
		draw_rect(Rect2(p, Vector2.ONE), Color(0.85, 0.3, 0.28, 0.45 + 0.45 * twinkle) if m[2] else Color(BONE, 0.18 + 0.25 * twinkle))


func _bake() -> void:
	var s: Vector2i = Vector2i(maxi(int(size.x), 1), maxi(int(size.y), 1))
	if s == _baked_size and _baked != null:
		return
	_baked_size = s
	var img: Image = Image.create(s.x, s.y, false, Image.FORMAT_RGBA8)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 4041
	var horizon: int = int(s.y * 0.7)
	var top: Color = Color(0.035, 0.04, 0.05)
	var low: Color = Color(0.13, 0.05, 0.06)
	var glow: Vector2 = Vector2(s) * glow_center
	for y: int in s.y:
		for x: int in s.x:
			# Sky: 6 dithered steps from near-black down to a dried-blood haze at the horizon.
			var t: float = clampf(float(y) / horizon, 0.0, 1.0)
			var step: float = floorf(t * 6.0 + _bayer(x, y)) / 6.0
			var col: Color = top.lerp(low, step * step)
			# Glow behind the logo, dithered too.
			var d: float = Vector2((x - glow.x) / 1.8, y - glow.y).length() / 95.0
			var g: float = clampf(1.0 - d, 0.0, 1.0)
			g = floorf(g * g * 5.0 + _bayer(x + 1, y)) / 5.0
			col = col.lerp(BLOOD, g * 0.55)
			img.set_pixel(x, y, col)
	_skyline(img, rng, horizon - 26, Color(0.075, 0.04, 0.05), 0.35)
	_skyline(img, rng, horizon, Color(0.025, 0.027, 0.033), 1.0)
	_power_line(img, rng, horizon - 4)
	_ground(img, horizon, rng)
	_veins(img, rng, Vector2i(0, s.y - 1), 1)
	_veins(img, rng, Vector2i(s.x - 1, s.y - 1), -1)
	_baked = ImageTexture.create_from_image(img)
	_motes.clear()
	for i: int in MOTES:
		_motes.append([Vector2(rng.randf() * s.x, rng.randf() * s.y),
				Vector2(rng.randf_range(1.0, 5.0), -rng.randf_range(3.0, 9.0)), rng.randf() < 0.3, rng.randf() * TAU])


func _bayer(x: int, y: int) -> float:
	return BAYER[(y % 4) * 4 + x % 4] / 16.0


## A row of ruined buildings standing on `base`: broken stepped roofs, a leaning beam, a few
## lit windows (only on the near row, `windows` = share of buildings that have any).
func _skyline(img: Image, rng: RandomNumberGenerator, base: int, colour: Color, windows: float) -> void:
	var x: int = -rng.randi_range(0, 20)
	var w_img: int = img.get_width()
	while x < w_img:
		var w: int = rng.randi_range(18, 54)
		var h: int = rng.randi_range(22, 78)
		var broken: bool = rng.randf() < 0.55
		for bx: int in w:
			# Broken roofs: the top edge steps down unevenly towards one side.
			var top: int = base - h
			if broken and bx > w * 0.5:
				top += int((bx - w * 0.5) * rng.randf_range(0.2, 1.4))
			top += rng.randi_range(0, 1)
			for y: int in range(maxi(top, 0), mini(base + 1, img.get_height())):
				_plot(img, x + bx, y, colour)
		if broken and rng.randf() < 0.6:  # a beam sticking out of the collapsed side
			var bx0: int = x + w - 2
			for i: int in rng.randi_range(6, 12):
				_plot(img, bx0 + i, base - h + 6 + int(i * 0.5), colour)
		if rng.randf() < windows:
			for i: int in rng.randi_range(1, 3):
				var wx: int = x + rng.randi_range(3, maxi(w - 5, 4))
				var wy: int = base - rng.randi_range(8, maxi(h - 10, 9))
				var lit: Color = Color(0.55, 0.22, 0.12) if rng.randf() < 0.7 else Color(0.4, 0.12, 0.12)
				for p: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
					_plot(img, wx + p.x, wy + p.y, lit)
				if _windows.is_empty() and colour.v < 0.05:
					_windows.append(Vector2(wx + 4, wy))
		x += w + rng.randi_range(-4, 10)


## Two poles with a sagging wire between them.
func _power_line(img: Image, rng: RandomNumberGenerator, base: int) -> void:
	var a: int = int(img.get_width() * 0.12)
	var b: int = int(img.get_width() * 0.42)
	var pole: Color = Color(0.02, 0.02, 0.025)
	for x0: int in [a, b]:
		for y: int in range(base - 64, base):
			_plot(img, x0, y, pole)
		for x: int in range(x0 - 5, x0 + 6):
			_plot(img, x, base - 60, pole)
	for x: int in range(a, b):
		var t: float = float(x - a) / float(b - a)
		_plot(img, x, base - 60 + int(sin(t * PI) * 14.0), pole)


## Ground below the skyline: dark with a band of dithered mist and rubble specks.
func _ground(img: Image, horizon: int, rng: RandomNumberGenerator) -> void:
	for y: int in range(horizon, img.get_height()):
		for x: int in img.get_width():
			var mist: float = clampf(1.0 - absf(y - horizon - 6) / 14.0, 0.0, 1.0)
			var col: Color = Color(0.03, 0.03, 0.035)
			if mist * 0.32 > _bayer(x, y):
				col = Color(0.12, 0.1, 0.11)
			img.set_pixel(x, y, col)
	for i: int in 80:
		_plot(img, rng.randi_range(0, img.get_width() - 1), rng.randi_range(horizon + 4, img.get_height() - 1), Color(0.14, 0.12, 0.12))


## Branching infected veins growing in from a bottom corner (dx = +1 right, -1 left).
func _veins(img: Image, rng: RandomNumberGenerator, start: Vector2i, dx: int) -> void:
	for branch: int in 5:
		var p: Vector2 = Vector2(start)
		var dir: Vector2 = Vector2(dx * rng.randf_range(0.4, 1.0), -rng.randf_range(0.5, 1.0)).normalized()
		for i: int in rng.randi_range(40, 90):
			var c: Vector2i = Vector2i(p.floor())
			_plot(img, c.x, c.y, BLOOD if i % 7 != 0 else BLOOD.lightened(0.25))
			_plot(img, c.x + 1, c.y, INFECTED)
			if rng.randf() < 0.04:  # a bloom on the vein
				for q: Vector2i in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
					_plot(img, c.x + q.x, c.y + q.y, Color(0.6, 0.16, 0.18))
				_plot(img, c.x, c.y, Color(0.9, 0.36, 0.3))
			dir = dir.rotated(rng.randf_range(-0.35, 0.35))
			p += dir


func _plot(img: Image, x: int, y: int, colour: Color) -> void:
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		img.set_pixel(x, y, colour)

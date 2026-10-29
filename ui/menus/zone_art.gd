class_name ZoneArt
extends RefCounted
## Small pixel-art vignettes for the Level Select zone cards, drawn in code (1 px = 1 viewport
## px, nearest filtering): Maple Hollow's grey suburb, Lowtide's flooded street, Greywood's
## black-green pines, Sunnyseed Labs going from sterile white to flesh. Seeded, cached.

const SIZE: Vector2i = Vector2i(102, 38)

static var _cache: Dictionary = {}


static func texture(zone: int) -> Texture2D:
	if not _cache.has(zone):
		_cache[zone] = ImageTexture.create_from_image(bake(zone))
	return _cache[zone]


static func bake(zone: int) -> Image:
	var img: Image = Image.create(SIZE.x, SIZE.y, false, Image.FORMAT_RGBA8)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 900 + zone
	match zone:
		0: _maple(img, rng)
		1: _lowtide(img, rng)
		2: _greywood(img, rng)
		_: _labs(img, rng)
	# A dark frame line and the bottom fade into the card.
	for x: int in SIZE.x:
		img.set_pixel(x, SIZE.y - 1, Color(0, 0, 0, 1))
	return img


static func _sky(img: Image, top: Color, bottom: Color) -> void:
	for y: int in SIZE.y:
		img.fill_rect(Rect2i(0, y, SIZE.x, 1), top.lerp(bottom, float(y) / SIZE.y))


static func _rect(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	var r: Rect2i = Rect2i(x, y, w, h).intersection(Rect2i(Vector2i.ZERO, SIZE))
	if r.size.x > 0 and r.size.y > 0:
		img.fill_rect(r, c)


static func _px(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < SIZE.x and y < SIZE.y:
		img.set_pixel(x, y, c)


## A gabled house: walls, roof triangle, windows (some lit, some dark / boarded).
static func _house(img: Image, rng: RandomNumberGenerator, x: int, ground: int, w: int, h: int, wall: Color, roof: Color) -> void:
	_rect(img, x, ground - h, w, h, wall)
	var apex: int = ground - h - w / 2
	for y: int in range(apex, ground - h):
		var half: int = int(float(y - apex + 1) / (ground - h - apex) * (w / 2 + 1))
		_rect(img, x + w / 2 - half, y, half * 2, 1, roof)
	for i: int in range(0, w - 4, 6):
		var lit: bool = rng.randf() < 0.2
		_rect(img, x + 2 + i, ground - h + 3, 3, 3, Color(0.85, 0.6, 0.3) if lit else Color(0.05, 0.05, 0.06))
	_rect(img, x + w / 2 - 1, ground - 5, 3, 5, Color(0.08, 0.06, 0.05))


static func _maple(img: Image, rng: RandomNumberGenerator) -> void:
	_sky(img, Color("#2a2f37"), Color("#5a6069"))
	var ground: int = 31
	for i: int in 3:  # far houses in the fog
		_house(img, rng, 4 + i * 38 + rng.randi_range(-3, 3), ground - 4, 22, 9, Color("#3e444d"), Color("#343941"))
	_house(img, rng, 10, ground, 30, 13, Color("#8b939c"), Color("#4a3a37"))
	_house(img, rng, 62, ground, 34, 15, Color("#7d858f"), Color("#3c4048"))
	_rect(img, 0, ground, SIZE.x, SIZE.y - ground, Color("#262a2f"))
	for x: int in range(0, SIZE.x, 3):  # picket fence
		if rng.randf() > 0.15:
			_rect(img, x, ground - 3, 1, 4, Color("#b6b9b5"))
	_rect(img, 0, ground - 2, SIZE.x, 1, Color("#9a9d99"))
	_rect(img, 46, ground - 22, 1, 22, Color("#1c1c1e"))  # leaning utility pole
	_rect(img, 43, ground - 21, 7, 1, Color("#1c1c1e"))
	for x: int in range(46, SIZE.x):
		_px(img, x, ground - 20 + int(pow(float(x - 76) / 30.0, 2.0) * 3.0), Color(0.07, 0.07, 0.08))
	for i: int in 40:  # ash
		_px(img, rng.randi_range(0, SIZE.x - 1), rng.randi_range(0, ground - 6), Color(0.75, 0.75, 0.75, 0.45))


static func _lowtide(img: Image, rng: RandomNumberGenerator) -> void:
	_sky(img, Color("#0e2226"), Color("#2d5552"))
	var water: int = 26
	for i: int in 4:  # half-sunk blocks
		var w: int = rng.randi_range(18, 26)
		var x: int = i * 28 + rng.randi_range(-2, 2)
		var h: int = rng.randi_range(14, 22)
		var wall: Color = [Color("#4f6f6e"), Color("#5f7f78"), Color("#3e5a5c"), Color("#6c7c72")][i]
		_rect(img, x, water - h, w, h, wall)
		for wy: int in range(water - h + 3, water - 2, 5):
			for wx: int in range(x + 2, x + w - 3, 5):
				_rect(img, wx, wy, 2, 3, Color(0.04, 0.08, 0.09) if rng.randf() < 0.8 else Color(0.5, 0.85, 0.8))
	_rect(img, 60, 8, 22, 5, Color("#0b1415"))  # neon sign, half lit
	for x: int in range(62, 80):
		if x % 4 != 3 and x < 74:
			_px(img, x, 10, Color("#ff5aa8"))
	_rect(img, 0, water, SIZE.x, SIZE.y - water, Color("#173a3b"))
	for y: int in range(water, SIZE.y - 1):  # ripples and reflections
		for x: int in SIZE.x:
			if (x + y * 3) % 9 == 0:
				_px(img, x, y, Color("#3f7f78"))
			elif (x * 7 + y) % 23 == 0:
				_px(img, x, y, Color(0.6, 0.85, 0.8, 0.6))
	for i: int in 30:  # rain
		var x: int = rng.randi_range(0, SIZE.x - 1)
		var y: int = rng.randi_range(0, water - 3)
		_px(img, x, y, Color(0.7, 0.85, 0.85, 0.35))
		_px(img, x, y + 1, Color(0.7, 0.85, 0.85, 0.2))


static func _pine(img: Image, x: int, ground: int, h: int, c: Color) -> void:
	for y: int in h:
		var half: int = int(float(y) / h * h * 0.32) + 1
		if y % 4 == 3:
			half = maxi(half - 1, 1)
		_rect(img, x - half, ground - h + y, half * 2 + 1, 1, c)
	_rect(img, x, ground - 2, 1, 2, Color("#120e0a"))


static func _greywood(img: Image, rng: RandomNumberGenerator) -> void:
	_sky(img, Color("#0a120c"), Color("#34503a"))
	var ground: int = 33
	for i: int in 14:  # far pines
		_pine(img, rng.randi_range(0, SIZE.x), ground - 3, rng.randi_range(14, 20), Color("#24392a"))
	_rect(img, 0, 18, SIZE.x, 6, Color(0.45, 0.55, 0.47, 0.3))  # fog band
	_rect(img, 66, ground - 10, 20, 10, Color("#5a4630"))  # a cabin
	for y: int in range(ground - 10, ground, 3):
		_rect(img, 66, y, 20, 1, Color("#3c2e1f"))
	for y: int in range(ground - 17, ground - 10):
		var half: int = (y - (ground - 17)) * 12 / 7
		_rect(img, 76 - half, y, half * 2, 1, Color("#2f2a22"))
	_rect(img, 73, ground - 6, 4, 6, Color("#0c0907"))
	_rect(img, 80, ground - 8, 3, 3, Color(0.9, 0.6, 0.3))
	for i: int in 7:  # near pines
		_pine(img, rng.randi_range(0, SIZE.x), ground + 2, rng.randi_range(22, 34), Color("#0e1a10"))
	_rect(img, 0, ground, SIZE.x, SIZE.y - ground, Color("#0a100a"))
	for i: int in 9:  # fireflies
		_px(img, rng.randi_range(0, SIZE.x - 1), rng.randi_range(8, ground), Color(0.85, 0.95, 0.5))


static func _labs(img: Image, rng: RandomNumberGenerator) -> void:
	_sky(img, Color("#2f3035"), Color("#5c5a5e"))
	var ground: int = 31
	_rect(img, 8, 6, 64, ground - 6, Color("#e6e8ea"))  # the white block
	_rect(img, 8, 6, 64, 2, Color("#ffffff"))
	for y: int in range(10, ground - 6, 6):
		_rect(img, 10, y, 60, 3, Color("#4b6f78"))
		for x: int in range(10, 70, 6):
			_px(img, x, y, Color("#c9cfd3"))
	_rect(img, 34, ground - 7, 10, 7, Color("#8a9096"))
	for x: int in range(8, 72):  # hazard stripe
		_px(img, x, ground - 1, Color("#e6b52a") if (x / 2) % 2 == 0 else Color("#111111"))
	_rect(img, 78, 14, 22, ground - 14, Color("#cfd3d6"))  # second wing
	for y: int in range(17, ground - 2, 5):
		_rect(img, 80, y, 18, 2, Color("#4b6f78"))
	# The flesh spreading in from the right: veins and swollen masses over the white.
	for y: int in SIZE.y:
		for x: int in SIZE.x:
			var reach: float = 64.0 + 10.0 * sin(y * 0.5) + 6.0 * sin(y * 1.7 + 1.0)
			if x > reach:
				var t: float = clampf((x - reach) / 20.0, 0.0, 1.0)
				var c: Color = img.get_pixel(x, y).lerp(Color("#7a1f27"), 0.5 + 0.4 * t)
				if (x * 3 + y * 5) % 11 == 0:
					c = Color("#d2474f")
				img.set_pixel(x, y, c)
	for i: int in 6:  # tendrils creeping left
		var y: float = rng.randf_range(4, ground)
		var x: float = rng.randf_range(62, 74)
		for k: int in rng.randi_range(8, 16):
			_px(img, int(x), int(y), Color("#9e2a33"))
			x -= 1.0
			y += rng.randf_range(-0.8, 0.8)
	_rect(img, 0, ground, SIZE.x, SIZE.y - ground, Color("#2b2b2e"))
	for i: int in 5:
		_px(img, rng.randi_range(70, SIZE.x - 1), rng.randi_range(ground, SIZE.y - 2), Color("#b8343c"))

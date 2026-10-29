class_name BuildingArchetypes
extends RefCounted
## The building library: how each type is laid out on its footprint with FacadeBuilder's
## primitives (front facade, storeys, entrance, signage, props). A type reads by its structure
## first - proportions, roof, storey count, openings - and by its sign second. INFO holds the
## footprint sizes (cells, min and max) a type fits; data/architecture.tres says which types
## stand in which district.

## Type -> [min size, max size] in cells.
const INFO: Dictionary[StringName, Array] = {
	&"house": [Vector2i(4, 4), Vector2i(10, 6)],
	&"garage": [Vector2i(2, 2), Vector2i(6, 3)],
	&"apartment": [Vector2i(4, 4), Vector2i(12, 12)],
	&"shop": [Vector2i(4, 3), Vector2i(10, 6)],
	&"pharmacy": [Vector2i(4, 3), Vector2i(8, 6)],
	&"supermarket": [Vector2i(5, 3), Vector2i(12, 8)],
	&"mall": [Vector2i(7, 4), Vector2i(16, 10)],
	&"office": [Vector2i(4, 4), Vector2i(12, 12)],
	&"tower": [Vector2i(4, 4), Vector2i(12, 12)],
	&"town_hall": [Vector2i(5, 4), Vector2i(12, 10)],
	&"clinic": [Vector2i(4, 3), Vector2i(8, 6)],
	&"hospital": [Vector2i(5, 4), Vector2i(16, 12)],
	&"school": [Vector2i(5, 4), Vector2i(14, 8)],
	&"police": [Vector2i(4, 4), Vector2i(10, 8)],
	&"fire_station": [Vector2i(4, 4), Vector2i(10, 8)],
	&"checkpoint": [Vector2i(4, 3), Vector2i(10, 8)],
	&"warehouse": [Vector2i(4, 3), Vector2i(14, 8)],
	&"factory": [Vector2i(5, 4), Vector2i(14, 10)],
	&"hotel": [Vector2i(4, 4), Vector2i(12, 12)],
	&"fish_market": [Vector2i(4, 3), Vector2i(12, 6)],
	&"harbor_office": [Vector2i(4, 4), Vector2i(10, 8)],
	&"rescue_station": [Vector2i(4, 3), Vector2i(10, 6)],
	&"cabin": [Vector2i(3, 3), Vector2i(6, 5)],
	&"lodge": [Vector2i(5, 4), Vector2i(10, 7)],
	&"ranger_station": [Vector2i(4, 4), Vector2i(8, 6)],
	&"visitor_center": [Vector2i(5, 4), Vector2i(10, 7)],
	&"sawmill": [Vector2i(4, 3), Vector2i(12, 7)],
	&"field_lab": [Vector2i(4, 3), Vector2i(8, 6)],
	&"medical_station": [Vector2i(4, 3), Vector2i(8, 6)],
	&"utility": [Vector2i(3, 3), Vector2i(8, 6)],
	&"security": [Vector2i(4, 3), Vector2i(10, 8)],
	&"lab": [Vector2i(4, 4), Vector2i(12, 10)],
	&"lab_tower": [Vector2i(4, 4), Vector2i(12, 12)],
	&"containment": [Vector2i(4, 4), Vector2i(12, 10)],
	&"processing": [Vector2i(5, 4), Vector2i(14, 10)],
	&"research_complex": [Vector2i(4, 4), Vector2i(16, 12)],
	&"admin": [Vector2i(4, 4), Vector2i(12, 10)],
}

## Shop signs per zone (Maple Hollow, Lowtide, Greywood, Sunnyseed Labs).
const SHOP_NAMES: Array = [
	["MARKET", "GROCERY", "DELI", "DINER", "BAKERY", "HARDWARE", "LAUNDRY", "BOOKS", "24/7"],
	["BAIT", "SURF", "CAFE", "NOODLES", "DIVE", "ICE", "BAR"],
	["GENERAL", "SUPPLY", "BAIT", "TRAIL"],
	["CAFE", "STORE"],
]


static func fits(id: StringName, size: Vector2i) -> bool:
	if not INFO.has(id):
		return false
	var lo: Vector2i = INFO[id][0]
	var hi: Vector2i = INFO[id][1]
	return size.x >= lo.x and size.y >= lo.y and size.x <= hi.x and size.y <= hi.y


## A type for a footprint none of the district's types fit.
static func fallback(size: Vector2i) -> StringName:
	for id: StringName in [&"warehouse", &"utility", &"garage", &"apartment"]:
		if fits(id, size):
			return id
	return &"utility"


static func paint(b: FacadeBuilder, id: StringName) -> void:
	match id:
		&"house": _house(b, "house")
		&"cabin": _house(b, "cabin")
		&"lodge": _house(b, "lodge")
		&"ranger_station": _house(b, "ranger")
		&"garage": _garage(b)
		&"apartment": _apartment(b, false)
		&"hotel": _apartment(b, true)
		&"shop": _shop(b, "")
		&"pharmacy": _shop(b, "pharmacy")
		&"supermarket": _supermarket(b, false)
		&"mall": _supermarket(b, true)
		&"office": _office(b, "")
		&"admin": _office(b, "admin")
		&"tower": _tower(b)
		&"town_hall": _town_hall(b)
		&"clinic": _clinic(b)
		&"hospital": _hospital(b)
		&"school": _school(b)
		&"police": _police(b)
		&"harbor_office": _police(b, "harbor")
		&"fire_station": _fire_station(b, false)
		&"rescue_station": _fire_station(b, true)
		&"checkpoint": _compound(b, "checkpoint")
		&"security": _compound(b, "security")
		&"medical_station": _compound(b, "medical")
		&"field_lab": _compound(b, "field_lab")
		&"warehouse": _warehouse(b, "warehouse")
		&"fish_market": _warehouse(b, "fish")
		&"sawmill": _warehouse(b, "sawmill")
		&"factory": _factory(b, false)
		&"processing": _factory(b, true)
		&"visitor_center": _visitor_center(b)
		&"utility": _utility(b)
		&"lab": _lab(b)
		&"lab_tower": _lab_tower(b, false)
		&"research_complex": _lab_tower(b, true)
		&"containment": _containment(b)
		_: _house(b, "house")


# --- helpers ---------------------------------------------------------------------------------

## `n` centres spread evenly over [x0, x1).
static func _spread(x0: int, x1: int, n: int) -> Array[int]:
	var out: Array[int] = []
	for i: int in n:
		out.append(x0 + int((i + 0.5) * (x1 - x0) / float(n)))
	return out


## Window centres stepping out from `centre` by `step` within the facade; `skip` leaves the
## centre itself free (a door below).
static func _around(fw: int, centre: int, step: int, skip: bool) -> Array[int]:
	var out: Array[int] = []
	if not skip:
		out.append(centre)
	for k: int in range(1, 8):
		for c: int in [centre - k * step, centre + k * step]:
			if c >= 7 and c <= fw - 8:
				out.append(c)
	return out


## Roof strip, wall and storey count of a flat-roofed block. Returns the upper storey count;
## the ground floor is the bottom `ground` px.
static func _frame(b: FacadeBuilder, storey_h: int, ground: int, cap_min: int, max_n: int, mat: FacadeBuilder.Surface, wall_c: Color) -> int:
	var n: int = clampi((b.height - cap_min - ground) / storey_h, 0, max_n)
	var cap: int = b.height - ground - n * storey_h
	b.begin(cap, n + 1)
	b.wall(0, cap, b.width, b.height - cap, mat, wall_c)
	b.roof_flat(0, cap, b.pick("flat"))
	_setback(b, wall_c, mat, mat != FacadeBuilder.Surface.CONCRETE or b.archetype == &"office")
	return n


## A deep footprint under a low front: the upper block set back behind the front's roof, so the
## building shows height instead of a wide flat roof. Window rows (or vents), its own coping, and
## its shadow on the lower roof.
static func _setback(b: FacadeBuilder, wall_c: Color, mat: FacadeBuilder.Surface, windows: bool) -> void:
	var top_y: int = 2
	var base: int = b.facade_top - 3
	if base - top_y < 11:
		return
	var sw: int = int(b.fw * b.rng.randf_range(0.58, 0.82))
	var sx: int = b.rand(2, maxi(b.fw - sw - 2, 2))
	b.wall(sx, top_y + 2, sw, base - top_y - 2, mat, FacadeBuilder.tone(wall_c, 0.9))
	b.hline(sx - 1, top_y, sw + 2, FacadeBuilder.tone(b.pick("trim"), 0.86), FacadeBuilder.Part.TRIM)
	b.hline(sx - 1, top_y + 1, sw + 2, FacadeBuilder.tone(b.pick("flat"), 0.7), FacadeBuilder.Part.ROOF)
	var yy: int = base - 8
	while yy >= top_y + 4:
		if windows:
			for c: int in _spread(sx + 2, sx + sw - 2, maxi(sw / 12, 1)):
				b.window(c - 3, yy, 7, 5, {"sill": false, "curtain": false})
		else:
			for c: int in _spread(sx + 2, sx + sw - 2, maxi(sw / 16, 1)):
				b.vent(c - 3, yy + 1, 6, 3)
		yy -= 9
	b.edges(sx, top_y + 2, sw, base - top_y - 2)
	for y: int in range(top_y + 2, base + 1):
		b.mul(sx + sw, y, 0.62)
		b.mul(sx + sw + 1, y, 0.8)
	for x: int in range(sx, sx + sw + 2):
		b.mul(x, base, 0.62)
	b.storeys += 1


## AC boxes, vents, a water tank or an antenna standing on a flat roof.
static func _roof_clutter(b: FacadeBuilder, tank: bool) -> void:
	var cap: int = b.facade_top
	if cap < 7:
		return
	for i: int in maxi(1, b.fw / 24):
		var x: int = b.rand(3, maxi(b.fw - 11, 4))
		match b.rand(0, 3):
			0:
				b.ac_unit(x, cap - 6)
			1:
				b.vent(x, cap - 5, 5, 3)
			2:
				if tank and cap >= 11:
					b.water_tank(x, cap - 10)
				else:
					b.ac_unit(x, cap - 6)
			_:
				b.antenna(x + 2, 1, cap - 3)


## Sunnyseed's logo: a smiling yellow seed with a green sprout.
static func _logo(b: FacadeBuilder, x: int, y: int) -> void:
	var sun: Color = Color(0.95, 0.8, 0.26)
	b.fill(x + 1, y + 2, 5, 5, sun, FacadeBuilder.Part.SIGN)
	b.fill(x, y + 3, 7, 3, sun, FacadeBuilder.Part.SIGN)
	b.dot(x + 2, y + 4, FacadeBuilder.OUTLINE)
	b.dot(x + 4, y + 4, FacadeBuilder.OUTLINE)
	b.hline(x + 2, y + 6, 3, FacadeBuilder.tone(sun, 0.6))
	b.dot(x + 3, y + 1, Color(0.36, 0.66, 0.3), FacadeBuilder.Part.SIGN)
	b.dot(x + 2, y, Color(0.42, 0.74, 0.34), FacadeBuilder.Part.SIGN)
	b.dot(x + 4, y, Color(0.42, 0.74, 0.34), FacadeBuilder.Part.SIGN)


## The longest label from `options` that fits `w` px.
static func _label(options: Array, w: int) -> String:
	for s: String in options:
		if PixelFont.width(s) <= w - 4:
			return s
	return ""


## A shop window: shelves and stock behind dirty glass, smashed in, or boarded with plywood.
static func _display(b: FacadeBuilder, x: int, y: int, w: int, h: int, stock: bool) -> void:
	if w < 3:
		return
	var d: float = b.look.get("decay", 0.3)
	var frame: Color = FacadeBuilder.tone(b.pick("metal"), 0.6)
	b.fill(x - 1, y - 1, w + 2, h + 1, frame, FacadeBuilder.Part.TRIM)
	var roll: float = b.rng.randf()
	if roll < 0.1 + 0.25 * d:
		var ply: Color = Color(0.62, 0.5, 0.34)
		b.fill(x, y, w, h, ply, FacadeBuilder.Part.TRIM)
		for xx: int in range(x + 9, x + w, 10):
			b.vline(xx, y, h, FacadeBuilder.tone(ply, 0.7))
		b.hline(x, y, w, FacadeBuilder.tone(ply, 1.15))
		return
	var g: Color = FacadeBuilder.tone(b.pick("glass"), 0.5)
	b.fill(x, y, w, h, g, FacadeBuilder.Part.GLASS)
	if stock:
		for yy: int in range(y + 2, y + h - 1, 3):
			b.hline(x, yy, w, Color(0.3, 0.26, 0.2))
			for xx: int in range(x, x + w):
				if b.hash01(xx, yy, 40) < 0.55:
					var c: Color = [Color(0.6, 0.3, 0.26), Color(0.7, 0.62, 0.36), Color(0.34, 0.5, 0.42), Color(0.5, 0.5, 0.56)][int(b.hash01(xx, yy, 41) * 3.99)]
					b.dot(xx, yy - 1, FacadeBuilder.tone(c, 0.7))
	for i: int in range(0, w + h, 9):  # reflections
		for k: int in 2:
			var xx: int = x + i + k
			for yy: int in range(y, y + h):
				var sx: int = xx - (yy - y)
				if sx >= x and sx < x + w:
					b.mix(sx, yy, Color(0.7, 0.8, 0.85), 0.25)
	if roll < 0.25 + 0.6 * d:  # smashed in: a jagged hole, glass on the pavement
		var cx: float = x + w * b.rng.randf_range(0.3, 0.7)
		var r: float = minf(w, h) * b.rng.randf_range(0.35, 0.6)
		for yy: int in range(y, y + h):
			for xx: int in range(x, x + w):
				var dd: float = Vector2(xx - cx, (yy - (y + h * 0.5)) * 1.4).length()
				if dd < r * (0.7 + 0.5 * b.hash01(xx / 2, yy / 2, 42)):
					b.dot(xx, yy, Color(0.03, 0.03, 0.04))
				elif dd < r * 1.15 and b.hash01(xx, yy, 43) < 0.3:
					b.dot(xx, yy, Color(0.62, 0.72, 0.76))
		for k: int in 6:
			b.ground_dot(x + b.rand(0, w - 1), b.height + b.rand(0, 3), Color(0.66, 0.76, 0.8))
	for xx: int in range(x + 13, x + w - 3, 14):
		b.vline(xx, y, h, frame, FacadeBuilder.Part.TRIM)


static func _ground_line(b: FacadeBuilder, c: Color) -> void:
	b.fill(0, b.height - 2, b.fw, 2, FacadeBuilder.tone(c, 0.72), FacadeBuilder.Part.WALL)


# --- residential -----------------------------------------------------------------------------

## Pitched-roof house types: suburban house, log cabin, forest lodge, ranger station.
static func _house(b: FacadeBuilder, kind: String) -> void:
	var w: int = b.width
	var h: int = b.height
	var logs: bool = kind == "cabin" or kind == "lodge"
	var cap: int = clampi(int(h * 0.42), 20, 34)
	b.begin(cap, 1 if kind == "cabin" else 2)
	var fw: int = b.fw
	var mat: FacadeBuilder.Surface = FacadeBuilder.Surface.LOGS if logs else (FacadeBuilder.Surface.BOARDS if kind == "ranger" else FacadeBuilder.Surface.SIDING)
	var wall_c: Color = b.pick("logs") if logs else b.pick("siding")
	if kind == "ranger":
		wall_c = Color(0.36, 0.44, 0.32)
	var roof_c: Color = b.pick("roof")
	b.wall(0, cap, w, h - cap, mat, wall_c)
	if kind == "ranger":
		roof_c = Color(0.28, 0.38, 0.28)
	b.roof_gable(0, cap, roof_c, logs)
	var gw: int = clampi(int(fw * 0.44) / 2 * 2, 22, 46)
	var left: bool = b.chance(0.5)
	var gx: int = 3 if left else fw - gw - 3
	if kind == "lodge":
		gw = clampi(int(fw * 0.6) / 2 * 2, 30, 64)
		gx = (fw - gw) / 2
	var apex: int = clampi(cap / 5, 2, 7)
	b.gable(gx, gw, apex, cap, mat, wall_c)
	var dc: int = gx + gw / 2
	if kind == "lodge":  # exposed timber truss in the big gable
		for yy: int in range(apex + 4, cap - 1):
			var half: int = int((yy - apex) / float(cap - apex) * gw / 2.0)
			b.dot(dc - half / 2, yy, FacadeBuilder.tone(FacadeBuilder.WOOD, 0.6))
			b.dot(dc + half / 2, yy, FacadeBuilder.tone(FacadeBuilder.WOOD, 0.6))
		b.vline(dc, apex + 3, cap - apex - 4, FacadeBuilder.tone(FacadeBuilder.WOOD, 0.6))
	if cap - apex >= 13:
		b.window(dc - 2, cap - 9, 5, 5, {"sill": false, "curtain": false})
	if kind != "ranger":
		var stone: bool = logs or b.zone == 2
		var chx: int = fw - 12 if left else 6
		if stone:
			b.wall(chx, 1, 6, maxi(cap - 8, 6), FacadeBuilder.Surface.STONE, Color(0.52, 0.5, 0.46))
			b.hline(chx, 1, 6, FacadeBuilder.OUTLINE)
		else:
			b.chimney(chx, 1, 5, maxi(cap - 8, 6), b.pick("brick"))
	else:
		b.antenna(fw - 8, 1, cap - 2)
	# Windows: an upper storey under the eaves, the ground floor with shutters.
	var top_y: int = cap + 3
	var low_y: int = h - 14
	if b.storeys >= 2:
		for c: int in _around(fw, dc, 20, false):
			b.window(c - 3, top_y, 7, 8, {"mullion": true})
		if kind == "lodge":
			b.balcony(3, top_y + 11, fw - 6, FacadeBuilder.WOOD)
	else:
		low_y = h - 15
	var shutter: Color = b.pick("door")
	for c: int in _around(fw, dc, 18, true):
		if absi(c - dc) < 12:
			continue
		b.window(c - 4, low_y, 8, 9, {"mullion": true})
		if not logs:
			b.vline(c - 5, low_y, 9, shutter, FacadeBuilder.Part.TRIM)
			b.vline(c + 4, low_y, 9, shutter, FacadeBuilder.Part.TRIM)
	_ground_line(b, wall_c if not logs else Color(0.5, 0.5, 0.46))
	b.edges(0, cap, fw, h - cap)
	# Porch over the door (cabins: right across the front).
	var px: int = dc - 9
	var pw: int = 18
	if kind == "cabin":
		px = 2
		pw = fw - 4
	b.fill(px, h - 19, pw, 3, roof_c, FacadeBuilder.Part.ROOF)
	b.hline(px, h - 19, pw, FacadeBuilder.tone(roof_c, 1.3), FacadeBuilder.Part.ROOF)
	for xx: int in range(px, px + pw):
		b.mul(xx, h - 16, 0.6)
	var post: Color = FacadeBuilder.WOOD if logs or kind == "ranger" else b.pick("trim")
	for xx: int in [px + 1, px + pw - 2]:
		b.vline(xx, h - 16, 14, post, FacadeBuilder.Part.TRIM)
	b.hline(px, h - 2, pw, FacadeBuilder.tone(FacadeBuilder.WOOD, 0.8), FacadeBuilder.Part.TRIM)
	b.door(dc - 3, 7, 13, "planks" if logs else "wood")
	if kind == "lodge":
		b.signboard(dc - 12, h - 27, 24, 7, "LODGE", Color(0.34, 0.22, 0.14), Color(0.88, 0.74, 0.32))
	if kind == "ranger":
		b.signboard(dc - 14, h - 27, 28, 7, "RANGER", Color(0.36, 0.25, 0.15), Color(0.9, 0.76, 0.34))
		b.fill(dc - 18, h - 27, 3, 7, Color(0.3, 0.5, 0.28), FacadeBuilder.Part.SIGN)
		b.flag(fw - 6 if left else 3, cap + 1, 14, Color(0.3, 0.46, 0.3))
	if kind == "house" and fw >= 90:  # attached garage on the far side
		var gdx: int = fw - 30 if left else 4
		b.door(gdx, 26, 14, "roller", FacadeBuilder.tone(b.pick("trim"), 0.82))
	if logs:
		b.log_pile(fw - 14 if left else 3, h - 4, 11, 2)
	else:
		for i: int in b.rand(1, 2):
			var bx: int = b.rand(2, fw - 12)
			if absi(bx + 4 - dc) > 10:
				b.bush(bx, h - 6, b.rand(6, 9), 6)
	b.side_wall(wall_c, 15)


static func _garage(b: FacadeBuilder) -> void:
	var cap: int = clampi(int(b.height * 0.35), 8, 14)
	b.begin(cap, 1)
	var wall_c: Color = b.pick("siding")
	b.wall(0, cap, b.width, b.height - cap, FacadeBuilder.Surface.SIDING, wall_c)
	b.roof_metal(0, cap, b.pick("metal"))
	var n: int = 2 if b.fw >= 60 else 1
	var dw: int = mini((b.fw - 6) / n - 4, 26)
	for i: int in n:
		var c: int = _spread(0, b.fw, n)[i]
		b.door(c - dw / 2, dw, b.height - cap - 5, "roller", FacadeBuilder.tone(b.pick("trim"), 0.8))
	b.edges(0, cap, b.fw, b.height - cap)
	b.side_wall(wall_c, 0)


## Apartment block (balconies, fire escape) or a hotel (balcony at every window, blade sign).
static func _apartment(b: FacadeBuilder, hotel: bool) -> void:
	var st: int = 13
	var mat: FacadeBuilder.Surface = FacadeBuilder.Surface.RENDER if hotel or b.chance(0.4) else FacadeBuilder.Surface.BRICK
	var wall_c: Color = b.pick("render") if mat == FacadeBuilder.Surface.RENDER else b.pick("brick")
	var n: int = _frame(b, st, 15, 7, 7, mat, wall_c)
	var fw: int = b.fw
	var h: int = b.height
	_roof_clutter(b, true)
	var bay: int = 13
	var nb: int = maxi(2, (fw - 4) / bay)
	var x0: int = (fw - nb * bay) / 2
	var fe: int = -1
	if not hotel and fw >= 56 and b.chance(0.65):
		fe = nb - 1 if b.chance(0.5) else 0
	for s: int in n:
		var sy: int = b.facade_top + s * st
		if s > 0 and mat == FacadeBuilder.Surface.RENDER:
			b.floor_line(sy - 1, wall_c)
		for k: int in nb:
			var bx: int = x0 + k * bay
			b.window(bx + 3, sy + 2, 7, 8, {"mullion": not hotel})
			if k == fe:
				continue
			if hotel or ((k + s) % 2 == 0 and b.chance(0.6)):
				b.balcony(bx + 1, sy + st - 2, bay - 2, FacadeBuilder.tone(wall_c, 1.1))
			elif b.chance(0.18):  # a window AC box
				b.fill(bx + 5, sy + 11, 3, 2, Color(0.72, 0.72, 0.7), FacadeBuilder.Part.PROP)
	if fe >= 0:
		b.fire_escape(x0 + fe * bay + 1, bay - 2, b.facade_top, st, n)
	var mid: int = x0 + (nb / 2) * bay + bay / 2
	for k: int in nb:
		var c: int = x0 + k * bay + bay / 2
		if absi(c - mid) < 4 or k == fe:
			continue
		b.window(c - 3, h - 12, 7, 6, {"bars": not hotel, "curtain": false})
	_ground_line(b, wall_c)
	b.edges(0, b.facade_top, fw, h - b.facade_top)
	b.fill(mid - 8, h - 16, 16, 2, FacadeBuilder.tone(b.pick("concrete"), 1.15), FacadeBuilder.Part.TRIM)
	for xx: int in range(mid - 8, mid + 8):
		b.mul(xx, h - 14, 0.65)
	b.door(mid - 4, 8, 12, "glass2" if hotel or b.chance(0.5) else "wood")
	if hotel:
		var label: String = "HOTEL" if b.chance(0.6) else "MOTEL"
		var neon: bool = b.zone == 1
		var bx: int = fw - 6 if b.chance(0.5) else 1
		var top: int = b.facade_top + 2
		var bg: Color = Color(0.08, 0.08, 0.1) if neon else b.pick("accent")
		var fg: Color = b.pick("accent") if neon else Color(0.95, 0.92, 0.84)
		if neon and fg.is_equal_approx(bg):
			fg = Color(0.94, 0.3, 0.58)
		if top + label.length() * 6 < h - 16:
			b.fill(bx, top, 5, label.length() * 6 + 1, bg, FacadeBuilder.Part.SIGN)
			for i: int in label.length():
				b.text(bx + 1, top + 1 + i * 6, label[i], fg)
	elif b.chance(0.5):
		b.barrel(fw - 7 if fe != nb - 1 else 3, h - 5, Color(0.24, 0.36, 0.28))
	b.side_wall(wall_c, st)


# --- commercial ------------------------------------------------------------------------------

## A shop with a flat above: sign fascia, striped awning, display windows, chained glass doors.
static func _shop(b: FacadeBuilder, kind: String) -> void:
	var ground: int = 25
	var mat: FacadeBuilder.Surface = FacadeBuilder.Surface.BRICK if b.chance(0.6) else FacadeBuilder.Surface.RENDER
	var wall_c: Color = b.pick("brick") if mat == FacadeBuilder.Surface.BRICK else b.pick("render")
	var upper: int = _frame(b, 13, ground, 9, 2, mat, wall_c)
	var fw: int = b.fw
	var h: int = b.height
	_roof_clutter(b, false)
	if b.facade_top >= 15 and fw >= 40 and b.zone == 0 and b.chance(0.35):
		b.billboard(fw / 2 - 20, 2, 40, b.facade_top - 7)
	for s: int in upper:
		var sy: int = b.facade_top + s * 13
		var centres: Array[int] = _spread(3, fw - 3, maxi(fw / 16, 2))
		for i: int in centres.size():
			if kind == "pharmacy" and i == centres.size() - 1:
				continue
			b.window(centres[i] - 3, sy + 3, 6, 8, {"mullion": true})
	var sy2: int = h - ground
	var neon: bool = b.zone == 1
	var bg: Color = b.pick("accent")
	var fg: Color = Color(0.95, 0.92, 0.84)
	var label: String = _label(SHOP_NAMES[b.zone].slice(b.rand(0, SHOP_NAMES[b.zone].size() - 1)) + SHOP_NAMES[b.zone], fw - 4)
	if kind == "pharmacy":
		bg = Color(0.92, 0.94, 0.92)
		fg = Color(0.2, 0.56, 0.32)
		label = _label(["PHARMACY", "DRUGS", "RX"], fw - 4)
		neon = false
	if neon:
		fg = bg
		bg = Color(0.08, 0.09, 0.11)
	b.signboard(2, sy2, fw - 4, 7, label, bg, fg, neon)
	if not neon:
		b.awning(2, sy2 + 7, fw - 4, 3, b.pick("accent") if kind != "pharmacy" else fg, b.pick("trim"))
	var dw: int = 8
	var dx: int = (fw - dw) / 2 if b.chance(0.5) else fw - dw - 5
	_display(b, 3, h - 14, dx - 5, 12, true)
	_display(b, dx + dw + 2, h - 14, fw - 3 - (dx + dw + 2), 12, true)
	b.door(dx, dw, 13, "glass2")
	_ground_line(b, wall_c)
	b.edges(0, b.facade_top, fw, h - b.facade_top)
	if kind == "pharmacy" and upper > 0:
		b.fill(fw - 12, b.facade_top + 2, 11, 11, FacadeBuilder.OUTLINE, FacadeBuilder.Part.SIGN)
		b.cross(fw - 11, b.facade_top + 3, 9, Color(0.3, 0.72, 0.38), Color(0.12, 0.16, 0.14))
	elif b.chance(0.5):
		b.cart(dx + dw + 3 if dx + dw + 12 < fw else 4, h - 6)
	b.side_wall(wall_c, 13)


## Supermarket (one tall storey, wide glass front, big sign, carts) or a shopping mall (glass
## atrium entrance between store-fronted wings).
static func _supermarket(b: FacadeBuilder, mall: bool) -> void:
	var h: int = b.height
	var face: int = mini(h - 10, 38 if mall else 34)
	b.begin(h - face, 2)
	var fw: int = b.fw
	var wall_c: Color = b.pick("render")
	b.wall(0, b.facade_top, b.width, face, FacadeBuilder.Surface.CONCRETE if mall else FacadeBuilder.Surface.RENDER, wall_c)
	b.roof_flat(0, b.facade_top, b.pick("flat"))
	_setback(b, wall_c, FacadeBuilder.Surface.METAL if not mall else FacadeBuilder.Surface.CONCRETE, mall)
	_roof_clutter(b, false)
	var top: int = b.facade_top + 2
	var red: Color = Color(0.74, 0.2, 0.18) if b.zone != 1 else Color(0.2, 0.5, 0.62)
	if mall:
		var aw: int = clampi(fw / 3, 22, 40)
		var ax: int = (fw - aw) / 2
		b.signboard(ax, top, aw, 9, _label(["MALL", "PLAZA"], aw), red, Color(0.96, 0.92, 0.84))
		var wing_signs: Array = ["SHOES", "TOYS", "GIFTS", "MUSIC", "SPORT", "FOOD"]
		for side: int in 2:
			var x0: int = 2 if side == 0 else ax + aw + 2
			var x1: int = ax - 2 if side == 0 else fw - 2
			var n: int = maxi(1, (x1 - x0) / 26)
			for i: int in n:
				var sx: int = x0 + i * (x1 - x0) / n
				var sw: int = (x1 - x0) / n - 2
				b.signboard(sx, top + 4, sw, 7, _label([wing_signs[b.rand(0, wing_signs.size() - 1)]], sw), b.pick("accent"), Color(0.95, 0.92, 0.84))
				_display(b, sx + 1, top + 13, sw - 2, h - top - 16, true)
		for yy: int in range(top + 10, h - 1):  # glass atrium
			b.hline(ax + 1, yy, aw - 2, FacadeBuilder.tone(b.pick("glass"), 1.0 if (yy / 4) % 2 == 0 else 0.86), FacadeBuilder.Part.GLASS)
		for xx: int in range(ax + 4, ax + aw - 2, 6):
			b.vline(xx, top + 10, h - top - 11, FacadeBuilder.tone(b.pick("metal"), 1.2), FacadeBuilder.Part.TRIM)
		b.door(ax + aw / 2 - 6, 12, 12, "glass2")
	else:
		var label: String = _label(["SUPERMARKET", "FOOD MART", "MARKET", "FOOD"], fw - 6)
		b.signboard(3, top, fw - 6, 9, label, red, Color(0.96, 0.92, 0.84))
		b.hline(2, top + 10, fw - 4, FacadeBuilder.tone(wall_c, 0.6), FacadeBuilder.Part.TRIM)
		var dx: int = fw / 2 - 6 + b.rand(-1, 1) * fw / 5
		_display(b, 3, top + 13, dx - 5, h - top - 16, true)
		_display(b, dx + 14, top + 13, fw - 3 - (dx + 14), h - top - 16, true)
		b.door(dx, 12, h - top - 15, "glass2")
		for i: int in b.rand(1, 3):
			b.cart(b.rand(3, fw - 10), h - 6)
		for i: int in 2:  # sale posters left in the glass
			var px: int = b.rand(4, fw - 9)
			if b.part_at(px, top + 15) == FacadeBuilder.Part.GLASS:
				b.fill(px, top + 14, 4, 3, Color(0.86, 0.3, 0.24))
	_ground_line(b, wall_c)
	b.edges(0, b.facade_top, fw, face)
	b.side_wall(wall_c, 0)


## Office block: concrete grid, ribbon windows, recessed lobby under a corporate name plate.
## `admin`: the Labs' administration building (white panels, Sunnyseed branding).
static func _office(b: FacadeBuilder, kind: String) -> void:
	var st: int = 12
	var labs: bool = kind == "admin"
	var mat: FacadeBuilder.Surface = FacadeBuilder.Surface.PANEL if labs else FacadeBuilder.Surface.CONCRETE
	var wall_c: Color = b.pick("render") if labs else b.pick("concrete")
	var n: int = _frame(b, st, 22, 6, 8, mat, wall_c)
	var fw: int = b.fw
	var h: int = b.height
	_roof_clutter(b, false)
	var g: Color = b.pick("glass")
	for s: int in n:
		var sy: int = b.facade_top + s * st
		for xx: int in range(2, fw - 2):
			var pane: int = (xx - 2) / 4
			var state: float = b.hash01(pane, s, 44)
			var d: float = b.look.get("decay", 0.3)
			var c: Color = FacadeBuilder.tone(g, 1.15 - 0.04 * ((xx + sy) % 9))
			if state < 0.15 + 0.4 * d:
				c = Color(0.04, 0.04, 0.05)
			elif state < 0.3 + 0.4 * d:
				c = FacadeBuilder.tone(g, 0.5)
			for yy: int in range(sy + 3, sy + 9):
				b.dot(xx, yy, c, FacadeBuilder.Part.GLASS)
			if (xx - 2) % 4 == 3:
				b.vline(xx, sy + 3, 6, FacadeBuilder.tone(wall_c, 0.8), FacadeBuilder.Part.TRIM)
		b.hline(2, sy + 9, fw - 4, FacadeBuilder.tone(wall_c, 1.15), FacadeBuilder.Part.TRIM)
		b.floor_line(sy + st - 1, wall_c)
	for xx: int in range(1, fw - 1, 16):  # pilasters
		b.vline(xx, b.facade_top, h - b.facade_top - 2, FacadeBuilder.tone(wall_c, 1.15), FacadeBuilder.Part.WALL)
		b.vline(xx + 1, b.facade_top, h - b.facade_top - 2, FacadeBuilder.tone(wall_c, 0.86), FacadeBuilder.Part.WALL)
	var lw: int = clampi(int(fw * 0.46), 20, 44)
	var lx: int = (fw - lw) / 2
	var plate: Color = FacadeBuilder.tone(b.pick("metal"), 0.5) if not labs else Color(0.95, 0.96, 0.97)
	var names: Array = ["SUNNYSEED", "MAPLE TRUST", "INSURANCE", "BANK", "OFFICE"]
	if b.zone == 1:
		names = ["HARBOR BANK", "SHIPPING", "BANK", "OFFICE"]
	if labs:
		names = ["SUNNYSEED", "ADMIN"]
	b.signboard(lx - 2, h - 22, lw + 4, 7, _label(names, lw + 4), plate, Color(0.92, 0.8, 0.36) if not labs else Color(0.3, 0.5, 0.26))
	b.fill(lx, h - 15, lw, 15, Color(0.1, 0.1, 0.11), FacadeBuilder.Part.DARK)
	b.hline(lx, h - 15, lw, Color(0.04, 0.04, 0.05))
	for xx: int in [lx, lx + lw - 2]:
		b.fill(xx, h - 15, 2, 15, FacadeBuilder.tone(wall_c, 1.1), FacadeBuilder.Part.WALL)
	b.door(lx + lw / 2 - 6, 12, 11, "glass2")
	for side: int in 2:
		var wx: int = 3 if side == 0 else lx + lw + 3
		var ww: int = lx - 6 if side == 0 else fw - 3 - wx
		if ww >= 4:
			_display(b, wx, h - 14, ww, 11, false)
	if labs:
		_logo(b, lx - 10 if lx >= 12 else fw - 9, h - 31)
		b.flag(fw - 5, b.facade_top + 1, 12, Color(0.95, 0.8, 0.26))
	b.edges(0, b.facade_top, fw, h - b.facade_top)
	b.side_wall(wall_c, st)


## Skyscraper: a lobby podium, a glass curtain-wall tower set back from it reaching to the top
## of the footprint, the darker towers behind it at the sides.
static func _tower(b: FacadeBuilder) -> void:
	var w: int = b.width
	var h: int = b.height
	var podium: int = 20
	var pt: int = h - podium
	b.begin(4, (h - 4) / 6)
	var fw: int = b.fw
	var tw: int = clampi(int(fw * 0.62) / 2 * 2, 24, fw - 8)
	var tx: int = (fw - tw) / 2
	var back: Color = FacadeBuilder.tone(b.pick("concrete"), 0.6)
	b.wall(0, 0, w, pt - 5, FacadeBuilder.Surface.CONCRETE, back)  # the city behind, in shadow
	for yy: int in range(3, pt - 6, 6):
		for xx: int in range(1, w - 1, 4):
			if b.hash01(xx, yy, 45) < 0.5:
				b.fill(xx, yy, 2, 3, FacadeBuilder.tone(back, 0.55), FacadeBuilder.Part.GLASS)
	var flat: Color = b.pick("flat")
	b.fill(0, pt - 5, w, 5, flat, FacadeBuilder.Part.ROOF)
	b.hline(0, pt - 5, w, FacadeBuilder.tone(b.pick("trim"), 0.8), FacadeBuilder.Part.TRIM)
	b.ac_unit(2, pt - 5)
	b.ac_unit(fw - 8, pt - 5)
	b.wall(0, pt, w, podium, FacadeBuilder.Surface.CONCRETE, b.pick("concrete"))
	var g: Color = b.pick("glass")
	var d: float = b.look.get("decay", 0.3)
	for yy: int in range(0, pt):
		for xx: int in range(tx, tx + tw):
			var u: int = xx - tx
			var c: Color = FacadeBuilder.tone(g, 0.95 + 0.25 * float((u + yy) % 23 < 6))
			if u % 4 == 0 or yy % 6 == 0:
				c = FacadeBuilder.tone(b.pick("metal"), 1.05)
			else:
				var pane: float = b.hash01(u / 4, yy / 6, 46)
				if pane < 0.08 + 0.3 * d:
					c = Color(0.04, 0.04, 0.05)
				elif pane < 0.14 + 0.35 * d:
					c = FacadeBuilder.tone(g, 0.45)
			b.dot(xx, yy, c, FacadeBuilder.Part.GLASS)
	b.fill(tx - 1, 0, tw + 2, 3, FacadeBuilder.tone(b.pick("trim"), 0.85), FacadeBuilder.Part.TRIM)
	b.hline(tx, 3, tw, FacadeBuilder.tone(g, 0.4))
	b.vline(tx - 1, 3, pt - 3, FacadeBuilder.tone(b.pick("metal"), 1.25), FacadeBuilder.Part.TRIM)
	b.vline(tx + tw, 3, pt - 3, FacadeBuilder.tone(b.pick("metal"), 0.6), FacadeBuilder.Part.TRIM)
	for yy: int in range(0, pt):  # the tower's shadow on the towers behind
		for i: int in 3:
			if b.part_at(tx + tw + 1 + i, yy) != FacadeBuilder.Part.GLASS or yy > pt - 6:
				b.mul(tx + tw + 1 + i, yy, 0.7)
	b.antenna(tx + tw / 2, 0, 3)
	var lx: int = tx + 2
	var lw: int = tw - 4
	b.signboard(lx, pt + 1, lw, 7, _label(["SUNNYSEED", "TOWER", "PLAZA"], lw), Color(0.12, 0.13, 0.15), Color(0.9, 0.8, 0.4))
	_display(b, 3, pt + 9, tx - 4, 9, false)
	_display(b, tx + tw + 2, pt + 9, fw - 3 - (tx + tw + 2), 9, false)
	b.fill(lx, pt + 8, lw, 12, Color(0.1, 0.1, 0.11), FacadeBuilder.Part.DARK)
	b.door(tx + tw / 2 - 6, 12, 10, "glass2")
	_ground_line(b, b.pick("concrete"))
	b.side_wall(back, 6)


## Town hall: stone front, columned portico under a pediment with a clock, flag on the roof.
static func _town_hall(b: FacadeBuilder) -> void:
	var stone: Color = b.pick("render")
	var n: int = _frame(b, 14, 18, 14, 2, FacadeBuilder.Surface.STONE, stone)
	var fw: int = b.fw
	var h: int = b.height
	var pw: int = clampi(int(fw * 0.5) / 2 * 2, 24, 50)
	var px: int = (fw - pw) / 2
	b.gable(px, pw, 2, b.facade_top + 2, FacadeBuilder.Surface.RENDER, FacadeBuilder.tone(stone, 1.1))
	b.clock(px + pw / 2 - 2, b.facade_top - 8)
	b.flag(fw - 8, 1, b.facade_top - 2, b.pick("accent"))
	b.signboard(px, b.facade_top + 2, pw, 7, _label(["TOWN HALL", "CIVIC", "HALL"], pw), FacadeBuilder.tone(stone, 1.15), Color(0.2, 0.2, 0.22))
	for s: int in n:
		var sy: int = b.facade_top + 10 + s * 14
		for c: int in _spread(3, px - 2, maxi((px - 2) / 12, 1)) + _spread(px + pw + 2, fw - 3, maxi((fw - px - pw - 2) / 12, 1)):
			b.window(c - 3, sy, 6, 10, {"mullion": true})
	for c: int in _spread(px, px + pw, maxi(pw / 9, 3)):  # the portico's columns
		b.fill(c - 1, b.facade_top + 10, 3, h - b.facade_top - 13, FacadeBuilder.tone(stone, 1.25), FacadeBuilder.Part.TRIM)
		b.vline(c + 1, b.facade_top + 10, h - b.facade_top - 13, FacadeBuilder.tone(stone, 0.8), FacadeBuilder.Part.TRIM)
	b.door(px + pw / 2 - 5, 10, 14, "wood")
	for i: int in 3:  # steps
		b.hline(px - 2 + i, h - 3 + i, pw + 4 - i * 2, FacadeBuilder.tone(stone, 1.2 - i * 0.12), FacadeBuilder.Part.TRIM)
	b.edges(0, b.facade_top, fw, h - b.facade_top)
	b.side_wall(stone, 14)


# --- civic / emergency -----------------------------------------------------------------------

static func _clinic(b: FacadeBuilder) -> void:
	var labs: bool = b.zone == 3
	var wall_c: Color = Color(0.86, 0.88, 0.88) if not labs else b.pick("render")
	var n: int = _frame(b, 12, 18, 8, 2, FacadeBuilder.Surface.PANEL if labs else FacadeBuilder.Surface.RENDER, wall_c)
	var fw: int = b.fw
	var h: int = b.height
	_roof_clutter(b, false)
	var teal: Color = Color(0.3, 0.56, 0.6)
	for s: int in n:
		var sy: int = b.facade_top + s * 12
		b.hline(0, sy + 10, fw, teal, FacadeBuilder.Part.TRIM)
		for c: int in _spread(3, fw - 14, maxi((fw - 17) / 13, 2)):
			b.window(c - 4, sy + 2, 9, 6, {"curtain": false})
	b.fill(fw - 13, b.facade_top + 1, 11, 11, Color(0.95, 0.95, 0.95), FacadeBuilder.Part.SIGN)
	b.cross(fw - 12, b.facade_top + 2, 9, Color(0.8, 0.16, 0.15), Color(0.95, 0.95, 0.95))
	b.signboard(3, h - 18, fw - 6, 7, _label(["MEDICAL CLINIC", "CLINIC", "MEDIC"], fw - 6), Color(0.95, 0.95, 0.95), Color(0.75, 0.16, 0.15))
	var dx: int = fw / 2 - 5
	_display(b, 3, h - 10, dx - 5, 8, false)
	_display(b, dx + 12, h - 10, fw - 15 - dx, 8, false)
	b.door(dx, 10, 10, "glass2")
	for i: int in 6:  # wheelchair ramp rail
		b.dot(dx + 11 + i, h - 2 - i / 2, FacadeBuilder.tone(b.pick("metal"), 1.2))
	_ground_line(b, wall_c)
	b.edges(0, b.facade_top, fw, h - b.facade_top)
	b.side_wall(wall_c, 12)


## Hospital: pale storeys of window bands, a red cross, the EMERGENCY canopy over sliding doors
## and an ambulance left under it.
static func _hospital(b: FacadeBuilder) -> void:
	var wall_c: Color = Color(0.84, 0.86, 0.86) if b.zone != 3 else b.pick("render")
	var n: int = _frame(b, 12, 22, 9, 6, FacadeBuilder.Surface.RENDER, wall_c)
	var fw: int = b.fw
	var h: int = b.height
	var top: int = b.facade_top
	if top >= 9:  # letters standing on the roof edge
		var label: String = _label(["HOSPITAL", "MEDICAL"], fw)
		var tx: int = (fw - PixelFont.width(label)) / 2
		b.text(tx, top - 7, label, Color(0.82, 0.18, 0.16))
		b.hline(tx - 1, top - 2, PixelFont.width(label) + 2, FacadeBuilder.OUTLINE, FacadeBuilder.Part.PROP)
	var teal: Color = Color(0.32, 0.56, 0.62)
	var cx: int = fw / 2
	for s: int in n:
		var sy: int = top + s * 12
		b.hline(0, sy, fw, teal, FacadeBuilder.Part.TRIM)
		for c: int in _spread(3, fw - 3, maxi((fw - 6) / 14, 2)):
			if s == 0 and absi(c - cx) < 8 and n >= 2:
				continue
			b.window(c - 5, sy + 3, 10, 6, {"curtain": false, "mullion": true})
	if n >= 2:
		b.fill(cx - 6, top + 1, 13, 13, Color(0.95, 0.95, 0.95), FacadeBuilder.Part.SIGN)
		b.cross(cx - 5, top + 2, 11, Color(0.82, 0.16, 0.15), Color(0.95, 0.95, 0.95))
	var cw: int = clampi(int(fw * 0.6), 34, 70)
	var cl: int = 3 if b.chance(0.5) else fw - cw - 3
	b.fill(cl, h - 22, cw, 6, Color(0.92, 0.92, 0.92), FacadeBuilder.Part.TRIM)
	b.signboard(cl + 1, h - 22, cw - 2, 6, _label(["EMERGENCY", "ER"], cw - 2), Color(0.92, 0.92, 0.92), Color(0.82, 0.16, 0.15))
	for xx: int in range(cl, cl + cw):
		b.mul(xx, h - 16, 0.55)
		b.mul(xx, h - 15, 0.75)
	b.vline(cl + 1, h - 16, 15, Color(0.8, 0.8, 0.8), FacadeBuilder.Part.TRIM)
	b.vline(cl + cw - 2, h - 16, 15, Color(0.8, 0.8, 0.8), FacadeBuilder.Part.TRIM)
	var door_x: int = cl + cw - 18 if cl < fw / 2 else cl + 6
	b.door(door_x, 12, 12, "glass2")
	var amb_x: int = cl + 3 if cl < fw / 2 else cl + cw - 25
	b.vehicle(amb_x, h, 22, Color(0.92, 0.92, 0.9), "ambulance")
	for c: int in _spread(3, fw - 3, maxi((fw - 6) / 14, 2)):
		if c < cl - 4 or c > cl + cw + 4:
			b.window(c - 4, h - 14, 8, 8, {"curtain": false})
	_ground_line(b, wall_c)
	b.edges(0, top, fw, h - top)
	b.side_wall(wall_c, 12)


## School: brick, rows of big many-paned windows, a central entrance bay with the name and a
## clock in its gable, a flagpole.
static func _school(b: FacadeBuilder) -> void:
	var brick: Color = b.pick("brick")
	var n: int = _frame(b, 15, 18, 12, 2, FacadeBuilder.Surface.BRICK, brick)
	var fw: int = b.fw
	var h: int = b.height
	var bay_w: int = 20
	var bx: int = fw / 2 - bay_w / 2
	var trim: Color = b.pick("trim")
	b.gable(bx - 2, bay_w + 4, 2, b.facade_top + 1, FacadeBuilder.Surface.BRICK, FacadeBuilder.tone(brick, 1.12))
	b.clock(bx + bay_w / 2 - 2, b.facade_top - 8)
	b.wall(bx, b.facade_top, bay_w, h - b.facade_top, FacadeBuilder.Surface.BRICK, FacadeBuilder.tone(brick, 1.12))
	b.vline(bx - 1, b.facade_top, h - b.facade_top, FacadeBuilder.tone(brick, 0.6), FacadeBuilder.Part.WALL)
	b.vline(bx + bay_w, b.facade_top, h - b.facade_top, FacadeBuilder.tone(brick, 0.6), FacadeBuilder.Part.WALL)
	for s: int in n:
		var sy: int = b.facade_top + s * 15
		b.hline(0, sy + 13, fw, FacadeBuilder.tone(trim, 0.86), FacadeBuilder.Part.TRIM)
		for c: int in _spread(3, bx - 2, maxi((bx - 2) / 13, 1)) + _spread(bx + bay_w + 2, fw - 3, maxi((fw - bx - bay_w - 2) / 13, 1)):
			var st: int = b.window(c - 5, sy + 2, 10, 10, {"mullion": true, "curtain": false})
			if st <= FacadeBuilder.Glass.INTERIOR:
				b.vline(c - 3, sy + 3, 8, trim, FacadeBuilder.Part.TRIM)
				b.vline(c + 2, sy + 3, 8, trim, FacadeBuilder.Part.TRIM)
		if s < n - 1 or n == 1:
			b.window(bx + bay_w / 2 - 4, sy + 2, 8, 10, {"mullion": true, "curtain": false})
	b.signboard(bx, h - 20, bay_w, 7, _label(["SCHOOL", "HIGH"], bay_w), FacadeBuilder.tone(trim, 0.9), Color(0.2, 0.2, 0.24))
	b.door(bx + bay_w / 2 - 5, 10, 12, "wood", Color(0.22, 0.32, 0.5))
	for c: int in _spread(3, bx - 2, maxi((bx - 2) / 13, 1)) + _spread(bx + bay_w + 2, fw - 3, maxi((fw - bx - bay_w - 2) / 13, 1)):
		b.window(c - 5, h - 15, 10, 10, {"mullion": true, "curtain": false})
	b.flag(4 if b.chance(0.5) else fw - 9, b.facade_top - 4, h - b.facade_top + 2, Color(0.2, 0.34, 0.62))
	_ground_line(b, brick)
	b.edges(0, b.facade_top, fw, h - b.facade_top)
	b.side_wall(brick, 15)


## Police station (blue band, barred windows, blue lamp, cruiser) or the harbour office
## (lookout room on the roof, lifebuoys).
static func _police(b: FacadeBuilder, kind: String = "police") -> void:
	var harbor: bool = kind == "harbor"
	var wall_c: Color = b.pick("concrete") if not harbor else b.pick("render")
	var n: int = _frame(b, 13, 22, 9 if not harbor else 16, 3, FacadeBuilder.Surface.CONCRETE if not harbor else FacadeBuilder.Surface.RENDER, wall_c)
	var fw: int = b.fw
	var h: int = b.height
	var top: int = b.facade_top
	if harbor and top >= 14:  # lookout room on the roof
		var lw: int = 22
		var lx: int = (fw - lw) / 2
		b.wall(lx, 3, lw, top - 4, FacadeBuilder.Surface.RENDER, wall_c)
		b.fill(lx, 1, lw, 2, b.pick("roof"), FacadeBuilder.Part.ROOF)
		for xx: int in range(lx + 2, lx + lw - 2, 5):
			b.window(xx, 5, 4, top - 9, {"sill": false, "framed": false, "curtain": false})
		b.flag(lx + lw + 3, 1, top - 2, Color(0.2, 0.4, 0.66))
	else:
		_roof_clutter(b, false)
		b.antenna(fw - 6, 0, top)
	for s: int in n:
		var sy: int = top + s * 13
		for c: int in _spread(3, fw - 3, maxi((fw - 6) / 12, 2)):
			b.window(c - 3, sy + 2, 7, 8, {"bars": not harbor, "curtain": false})
	var band: Color = Color(0.18, 0.28, 0.56) if not harbor else Color(0.2, 0.42, 0.58)
	b.signboard(0, h - 22, fw, 7, _label(["POLICE"] if not harbor else ["HARBOR MASTER", "HARBOR"], fw), band, Color(0.95, 0.95, 0.95))
	var dx: int = fw / 2 - 5
	b.door(dx, 10, 12, "glass2" if harbor else "metal", b.pick("metal"))
	if not harbor:
		b.fill(dx + 12, h - 14, 2, 3, Color(0.3, 0.5, 0.95), FacadeBuilder.Part.PROP)
		b.vehicle(dx + 15 if dx + 35 < fw else 2, h, 18, Color(0.88, 0.88, 0.88), "police")
		b.sandbags(2, h - 2, 12, 2)
	else:
		for xx: int in [6, fw - 10]:  # lifebuoys
			b.fill(xx, h - 13, 4, 4, Color(0.92, 0.42, 0.18), FacadeBuilder.Part.PROP)
			b.fill(xx + 1, h - 12, 2, 2, FacadeBuilder.tone(wall_c, 0.7))
	for c: int in _spread(3, fw - 3, maxi((fw - 6) / 12, 2)):
		if absi(c - fw / 2) > 9 and b.part_at(c, h - 9) == FacadeBuilder.Part.WALL:
			b.window(c - 3, h - 13, 7, 7, {"bars": not harbor, "curtain": false})
	_ground_line(b, wall_c)
	b.edges(0, top, fw, h - top)
	b.side_wall(wall_c, 13)


## Fire station (red brick, two red bay doors, hose tower) or a coastal rescue station
## (red / white bands, boat shed door, beacon).
static func _fire_station(b: FacadeBuilder, rescue: bool) -> void:
	var w: int = b.width
	var h: int = b.height
	var wall_c: Color = b.pick("brick") if not rescue else Color(0.86, 0.86, 0.84)
	var cap: int = clampi(int(h * 0.3), 10, 22)
	b.begin(cap, 2)
	var fw: int = b.fw
	b.wall(0, cap, w, h - cap, FacadeBuilder.Surface.BRICK if not rescue else FacadeBuilder.Surface.SIDING, wall_c)
	b.roof_flat(0, cap, b.pick("flat"))
	var tower_w: int = 12
	var tx: int = fw - tower_w - 1 if b.chance(0.5) else 1
	if not rescue:  # hose drying tower rising through the roof
		b.wall(tx, 0, tower_w, h, FacadeBuilder.Surface.BRICK, FacadeBuilder.tone(wall_c, 0.92))
		b.hline(tx - 1, 0, tower_w + 2, FacadeBuilder.tone(b.pick("trim"), 0.9), FacadeBuilder.Part.TRIM)
		for yy: int in range(4, h - 22, 9):
			b.window(tx + 4, yy, 4, 6, {"sill": false, "curtain": false})
		for xx: int in range(tx, tx + tower_w):
			b.mul(xx, 1, 0.7)
	else:
		b.fill(fw / 2 - 1, cap - 6, 3, 4, Color(0.95, 0.5, 0.15), FacadeBuilder.Part.PROP)
		for yy: int in range(cap + 3, h - 20, 6):
			b.hline(0, yy, fw, Color(0.78, 0.2, 0.18), FacadeBuilder.Part.TRIM)
	var x0: int = 2 if (tx > fw / 2 or rescue) else tower_w + 3
	var x1: int = (tx - 2) if (tx > fw / 2 and not rescue) else fw - 2
	b.signboard(x0, cap + 2, x1 - x0, 7, _label(["FIRE STATION", "FIRE"] if not rescue else ["COAST RESCUE", "RESCUE"], x1 - x0), Color(0.76, 0.18, 0.16), Color(0.96, 0.92, 0.84))
	var n: int = 2 if x1 - x0 >= 44 else 1
	var dh: int = mini(h - cap - 14, 20)
	for i: int in n:
		var c: int = _spread(x0, x1, n)[i]
		var dw: int = mini((x1 - x0) / n - 4, 22)
		b.door(c - dw / 2, dw, dh, "roller", Color(0.74, 0.18, 0.16) if not rescue else b.pick("metal"))
		b.text(c - 3, h - dh - 7, "0%d" % (i + 1), FacadeBuilder.tone(b.pick("trim"), 0.9))
	if rescue:
		for xx: int in [x0 + 1, x1 - 5]:
			b.fill(xx, cap + 11, 4, 4, Color(0.92, 0.42, 0.18), FacadeBuilder.Part.PROP)
		b.sandbags(x0, h - 2, 14, 2)
	_ground_line(b, wall_c)
	b.edges(0, cap, fw, h - cap)
	b.side_wall(wall_c, 12)


## Fenced compounds: an evacuation checkpoint (containers, razor wire, a medical tent, guard
## cabin, sandbags, barriers), the Labs security gate, a forest medical station or a Sunnyseed
## field lab (prefab modules, solar panels, dish).
static func _compound(b: FacadeBuilder, kind: String) -> void:
	var w: int = b.width
	var h: int = b.height
	var back: int = clampi(int(h * 0.42), 14, 30)
	b.begin(back, 2)
	var fw: int = b.fw
	var labs: bool = kind == "security"
	var olive: Color = Color(0.4, 0.44, 0.32)
	var ground_c: Color = FacadeBuilder.tone(b.pick("concrete"), 0.62)
	b.fill(0, 0, w, h, ground_c, FacadeBuilder.Part.WALL)
	for y: int in h:
		for x: int in w:
			if b.hash01(x, y, 48) < 0.2:
				b.dot(x, y, FacadeBuilder.tone(ground_c, 0.8 + 0.3 * b.hash01(y, x, 49)))
	if kind == "checkpoint" or labs:
		var x: int = 0
		while x < w:  # stacked containers along the back
			var cw: int = mini(b.rand(18, 26), w - x)
			var cc: Color = [Color(0.56, 0.3, 0.22), Color(0.3, 0.42, 0.5), Color(0.42, 0.46, 0.34), Color(0.7, 0.6, 0.34)][b.rand(0, 3)]
			if labs:
				cc = [Color(0.82, 0.84, 0.86), Color(0.7, 0.74, 0.78)][b.rand(0, 1)]
			b.container(x, 2, cw, back / 2, cc)
			b.container(x + b.rand(-3, 3), back / 2 + 1, cw, back - back / 2 - 1, FacadeBuilder.tone(cc, 0.85))
			x += cw
		for xx: int in w:  # razor wire coiled along the top
			b.dot(xx, int(1 + sin(xx * 1.1)), Color(0.7, 0.72, 0.74))
			if xx % 3 == 0:
				b.dot(xx, 2, Color(0.5, 0.52, 0.55))
		b.floodlight(fw - 4, 1, back + 6)
	else:
		var mw: int = clampi(fw / 2, 22, 40)
		var white: Color = Color(0.82, 0.84, 0.84) if kind == "field_lab" else Color(0.74, 0.76, 0.7)
		for i: int in 2:
			var mx: int = 2 + i * (mw + 2)
			if mx + mw > fw - 1:
				break
			b.wall(mx, 4, mw, back + 8, FacadeBuilder.Surface.PANEL, white)
			b.fill(mx, 2, mw, 2, FacadeBuilder.tone(white, 0.7), FacadeBuilder.Part.ROOF)
			if kind == "field_lab":
				b.solar(mx + 2, 0, mw - 4, 3)
			for c: int in _spread(mx + 2, mx + mw - 2, maxi(mw / 12, 1)):
				b.window(c - 3, 9, 6, 4, {"sill": false, "curtain": false, "bars": kind == "field_lab"})
		if kind == "field_lab":
			b.antenna(fw - 5, 0, back)
			b.fill(fw - 10, 3, 4, 3, Color(0.86, 0.86, 0.86), FacadeBuilder.Part.PROP)
	var front: int = h - back
	var cab_w: int = clampi(fw / 3, 16, 30)
	var cab_x: int = 2 if b.chance(0.5) else fw - cab_w - 2
	if kind == "medical" or kind == "checkpoint":
		var tw: int = clampi(fw / 3, 18, 30)
		var tx: int = fw - tw - 3 if cab_x < fw / 2 else 3
		b.tent(tx, back - 2, tw, front - 4, Color(0.8, 0.8, 0.74) if kind == "medical" else olive, true)
	var cab_c: Color = Color(0.9, 0.92, 0.94) if labs else (olive if kind == "checkpoint" else Color(0.78, 0.8, 0.78))
	b.wall(cab_x, back + 2, cab_w, front - 6, FacadeBuilder.Surface.PANEL, cab_c)
	b.fill(cab_x - 1, back, cab_w + 2, 2, FacadeBuilder.tone(cab_c, 0.6), FacadeBuilder.Part.ROOF)
	b.window(cab_x + 2, back + 5, cab_w - 9, 5, {"sill": false, "curtain": false})
	b.door(cab_x + cab_w - 6, 5, front - 8, "metal", FacadeBuilder.tone(cab_c, 0.8))
	var label: String = {"checkpoint": "QUARANTINE", "security": "SECURITY", "medical": "MEDIC", "field_lab": "FIELD LAB"}[kind]
	var sx: int = cab_x + cab_w + 3 if cab_x < fw / 2 else 3
	var sw: int = mini(PixelFont.width(label) + 4, fw - sx - 2)
	if kind == "field_lab":
		_logo(b, sx, back + 3)
		b.signboard(sx + 9, back + 3, sw, 7, _label([label, "LAB"], sw), Color(0.95, 0.95, 0.95), Color(0.3, 0.5, 0.26))
		b.warning(sx, h - 9)
	elif kind == "medical":
		b.crate(sx, h - 6, 5)
		b.crate(sx + 6, h - 6, 5)
		b.barrel(sx + 13, h - 5, Color(0.36, 0.42, 0.3))
	else:
		b.signboard(sx, back + 2, sw, 7, _label([label, "STOP"], sw), FacadeBuilder.HAZARD if not labs else Color(0.95, 0.95, 0.95), FacadeBuilder.OUTLINE)
		if labs:
			_logo(b, sx + sw + 2, back + 2)
	_fence(b, labs)
	if kind == "checkpoint":
		b.sandbags(2, h - 2, fw / 2 - 4, 3)
		b.barriers(fw / 2 + 2, fw / 2 - 4)
	elif labs:
		b.barriers(2, fw - 4)
		for xx: int in range(2, fw - 2):  # boom gate
			b.dot(xx, h - 8, Color(0.85, 0.2, 0.18) if (xx / 3) % 2 == 0 else Color(0.95, 0.95, 0.95), FacadeBuilder.Part.PROP)
	b.side_wall(ground_c, 0)


## Chain-link (Labs: steel palisade) fence along the front of a compound, wire on top.
static func _fence(b: FacadeBuilder, labs: bool) -> void:
	var top: int = b.height - 9
	var post: Color = Color(0.3, 0.31, 0.33) if not labs else Color(0.82, 0.84, 0.86)
	for x: int in b.width:
		for y: int in range(top, b.height - 1):
			if labs:
				if x % 3 == 0:
					b.dot(x, y, post if x % 6 == 0 else FacadeBuilder.tone(post, 0.8), FacadeBuilder.Part.TRIM)
			elif (x + y) % 3 == 0 or (x - y) % 3 == 0:
				b.mix(x, y, Color(0.62, 0.64, 0.66), 0.6)
		if x % 10 == 0:
			b.vline(x, top - 2, b.height - top + 2, post, FacadeBuilder.Part.TRIM)
		b.dot(x, top, FacadeBuilder.tone(post, 1.2), FacadeBuilder.Part.TRIM)
		if x % 2 == 0:
			b.dot(x, top - 2 - (x / 2) % 2, Color(0.72, 0.74, 0.76))


# --- industrial ------------------------------------------------------------------------------

## Warehouse (corrugated walls, loading doors, high strip windows), fish market (shuttered
## stalls, crates of fish, nets) or a sawmill (board walls, log piles).
static func _warehouse(b: FacadeBuilder, kind: String) -> void:
	var w: int = b.width
	var h: int = b.height
	var cap: int = clampi(int(h * 0.32), 12, 26)
	b.begin(cap, 2)
	var fw: int = b.fw
	var wall_c: Color = b.pick("metal")
	var mat: FacadeBuilder.Surface = FacadeBuilder.Surface.METAL
	if kind == "fish":
		wall_c = b.pick("siding")
		mat = FacadeBuilder.Surface.BOARDS
	elif kind == "sawmill":
		wall_c = FacadeBuilder.tone(FacadeBuilder.WOOD, 0.9)
		mat = FacadeBuilder.Surface.BOARDS
	b.wall(0, cap, w, h - cap, mat, wall_c)
	b.roof_metal(0, cap, b.pick("roof") if kind != "sawmill" else Color(0.4, 0.42, 0.42))
	for xx: int in range(4, fw - 4, 9):
		b.window(xx, cap + 3, 5, 3, {"sill": false, "framed": false, "curtain": false})
	var label: String = ""
	match kind:
		"fish":
			label = _label(["FISH MARKET", "FISH", "SEAFOOD"], fw - 6)
			b.signboard(3, cap + 8, fw - 6, 7, label, Color(0.2, 0.42, 0.56), Color(0.95, 0.95, 0.92))
			var n: int = maxi(2, (fw - 6) / 16)
			for i: int in n:
				var c: int = _spread(3, fw - 3, n)[i]
				b.window(c - 6, cap + 17, 12, h - cap - 20, {"state": FacadeBuilder.Glass.SHUTTER, "sill": false, "curtain": false})
			for i: int in b.rand(2, 3):
				var cx: int = b.rand(3, fw - 9)
				b.crate(cx, h - 6, 6)
				b.dot(cx + 2, h - 6, Color(0.7, 0.8, 0.86))
				b.dot(cx + 3, h - 6, Color(0.6, 0.66, 0.7))
			for yy: int in range(cap + 1, cap + 7):  # a net hung to dry
				for xx: int in range(fw - 18, fw - 4):
					if (xx + yy) % 3 == 0 or (xx - yy) % 3 == 0:
						b.dot(xx, yy, Color(0.16, 0.2, 0.2))
			for i: int in 20:  # gulls
				b.dot(b.rand(0, fw), b.rand(1, cap - 3), Color(0.9, 0.9, 0.88))
		"sawmill":
			b.signboard(3, cap + 8, fw - 6, 7, _label(["SAWMILL", "LUMBER", "MILL"], fw - 6), Color(0.3, 0.2, 0.12), Color(0.9, 0.76, 0.36))
			b.door(fw / 2 - 11, 22, h - cap - 20, "roller", Color(0.44, 0.4, 0.34))
			b.log_pile(2, h - 4, fw / 2 - 14, 3)
			b.log_pile(fw / 2 + 13, h - 4, fw / 2 - 16, 2)
			b.pipe(fw - 8, 0, cap + 4, Color(0.4, 0.4, 0.42))
		_:
			label = _label(["FREIGHT", "STORAGE", "DEPOT"], fw / 2)
			var n: int = 2 if fw >= 70 else 1
			var dw: int = mini((fw - 8) / n - 6, 26)
			for i: int in n:
				var c: int = _spread(2, fw - 2, n)[i]
				b.door(c - dw / 2, dw, h - cap - 14, "roller", FacadeBuilder.tone(b.pick("trim"), 0.75))
				b.fill(c - dw / 2 - 2, h - 3, dw + 4, 3, FacadeBuilder.tone(b.pick("concrete"), 1.1), FacadeBuilder.Part.TRIM)
				b.fill(c - dw / 2 - 2, h - 7, 2, 3, FacadeBuilder.OUTLINE, FacadeBuilder.Part.PROP)
				b.fill(c + dw / 2, h - 7, 2, 3, FacadeBuilder.OUTLINE, FacadeBuilder.Part.PROP)
			b.text(4, cap + 7, "%02d" % b.rand(1, 40), FacadeBuilder.tone(b.pick("trim"), 0.9))
			if fw >= 56:
				b.signboard(fw - PixelFont.width(label) - 8, cap + 7, PixelFont.width(label) + 4, 7, label, FacadeBuilder.tone(wall_c, 0.6), b.pick("trim"))
			b.barrel(2, h - 6, b.pick("accent"))
			b.crate(fw - 8, h - 7, 6)
	b.edges(0, cap, fw, h - cap)
	b.side_wall(wall_c, 0)


## Factory (sawtooth roof, tall windows, smokestack, tanks, pipes) or the Labs' processing plant.
static func _factory(b: FacadeBuilder, labs: bool) -> void:
	var w: int = b.width
	var h: int = b.height
	var cap: int = clampi(int(h * 0.32), 12, 24)
	b.begin(cap, 3)
	var fw: int = b.fw
	var wall_c: Color = b.pick("brick") if not labs else b.pick("render")
	b.wall(0, cap, w, h - cap, FacadeBuilder.Surface.BRICK if not labs else FacadeBuilder.Surface.PANEL, wall_c)
	b.roof_sawtooth(0, cap, b.pick("roof"))
	var sx: int = fw - 12 if b.chance(0.5) else 3
	var tank_x: int = 3 if sx > fw / 2 else fw - 15
	for c: int in _spread(14 if sx < fw / 2 else 4, (fw - 15) if sx > fw / 2 else fw - 4, maxi((fw - 20) / 10, 2)):
		if absi(c - (tank_x + 6)) > 9:
			b.window(c - 3, cap + 4, 6, 13, {"mullion": true, "curtain": false})
	var pipe_c: Color = Color(0.52, 0.42, 0.3) if not labs else Color(0.7, 0.74, 0.78)
	b.hline(0, cap + 20, fw, FacadeBuilder.tone(pipe_c, 1.15), FacadeBuilder.Part.PROP)
	b.hline(0, cap + 21, fw, FacadeBuilder.tone(pipe_c, 0.7), FacadeBuilder.Part.PROP)
	b.fill(tank_x, h - 20, 12, 18, FacadeBuilder.tone(pipe_c, 1.05), FacadeBuilder.Part.PROP)
	b.vline(tank_x, h - 20, 18, FacadeBuilder.tone(pipe_c, 1.3), FacadeBuilder.Part.PROP)
	b.vline(tank_x + 11, h - 20, 18, FacadeBuilder.tone(pipe_c, 0.65), FacadeBuilder.Part.PROP)
	for yy: int in [h - 16, h - 9]:
		b.hline(tank_x, yy, 12, FacadeBuilder.tone(pipe_c, 0.6), FacadeBuilder.Part.PROP)
	b.hline(tank_x + 1, h - 21, 10, FacadeBuilder.tone(pipe_c, 1.25), FacadeBuilder.Part.PROP)
	for yy: int in h:  # smokestack
		var band: bool = (yy / 6) % 2 == 0 and yy < 14
		var c: Color = (Color(0.72, 0.22, 0.2) if not labs else FacadeBuilder.HAZARD) if band else FacadeBuilder.tone(wall_c, 0.85)
		b.hline(sx, yy, 8, c, FacadeBuilder.Part.WALL)
		b.dot(sx, yy, FacadeBuilder.tone(c, 1.25))
		b.dot(sx + 7, yy, FacadeBuilder.tone(c, 0.6))
	b.hline(sx, 0, 8, FacadeBuilder.OUTLINE, FacadeBuilder.Part.WALL)
	if labs:
		b.signboard(fw / 2 - 22, h - 12, 44, 7, _label(["PROCESSING", "PLANT 2"], 44), Color(0.95, 0.95, 0.95), FacadeBuilder.OUTLINE)
		b.hazard(0, h - 4, fw, 2)
		b.warning(fw / 2 - 30, h - 13)
	else:
		b.door(fw / 2 - 6, 12, 12, "roller", b.pick("metal"))
	b.edges(0, cap, fw, h - cap)
	b.side_wall(wall_c, 0)


## Utility block: windowless concrete, transformer cabinets with cooling fins, danger signs.
static func _utility(b: FacadeBuilder) -> void:
	var wall_c: Color = b.pick("concrete")
	b.begin(clampi(int(b.height * 0.3), 8, 16), 1)
	b.wall(0, b.facade_top, b.width, b.height - b.facade_top, FacadeBuilder.Surface.CONCRETE, wall_c)
	b.roof_flat(0, b.facade_top, b.pick("flat"))
	var fw: int = b.fw
	var h: int = b.height
	b.vent(4, b.facade_top - 5, 6, 3)
	for i: int in maxi(1, (fw - 16) / 16):
		var x: int = 4 + i * 16
		var c: Color = Color(0.46, 0.5, 0.46)
		b.fill(x, h - 16, 12, 14, c, FacadeBuilder.Part.PROP)
		for xx: int in range(x + 1, x + 11, 2):
			b.vline(xx, h - 14, 10, FacadeBuilder.tone(c, 0.65), FacadeBuilder.Part.PROP)
		b.hline(x, h - 16, 12, FacadeBuilder.tone(c, 1.25), FacadeBuilder.Part.PROP)
	for c: int in _spread(4, fw - 4, maxi((fw - 8) / 14, 1)):
		b.vent(c - 4, b.facade_top + 4, 8, 5)
	var label: String = _label(["PUMP STATION", "PUMP", "POWER"] if b.zone != 2 else ["GENERATOR", "POWER"], fw - 20)
	b.signboard(4, b.facade_top + 12, PixelFont.width(label) + 4, 7, label, Color(0.92, 0.9, 0.84), FacadeBuilder.OUTLINE)
	b.warning(fw - 12, b.facade_top + 12)
	b.door(fw - 10, 7, 12, "metal", b.pick("metal"))
	b.pipe(2, b.facade_top, h - b.facade_top - 2, Color(0.5, 0.48, 0.44))
	b.edges(0, b.facade_top, fw, h - b.facade_top)
	b.side_wall(wall_c, 0)


## Forest visitor centre: timber wings round a tall A-frame of glass, the trail's mascot sign.
static func _visitor_center(b: FacadeBuilder) -> void:
	var w: int = b.width
	var h: int = b.height
	var cap: int = clampi(int(h * 0.36), 16, 30)
	b.begin(cap, 2)
	var fw: int = b.fw
	var wall_c: Color = b.pick("siding")
	b.wall(0, cap, w, h - cap, FacadeBuilder.Surface.BOARDS, wall_c)
	b.roof_gable(0, cap, b.pick("roof"), true)
	var aw: int = clampi(int(fw * 0.42) / 2 * 2, 24, 44)
	var ax: int = (fw - aw) / 2
	var g: Color = b.pick("glass")
	for yy: int in range(1, h - 2):  # the A-frame's glass front
		var half: int = int(minf((yy + 1) / float(cap) , 1.0) * aw / 2.0)
		for xx: int in range(ax + aw / 2 - half, ax + aw / 2 + half):
			var c: Color = FacadeBuilder.tone(g, 1.0 + 0.3 * float((xx + yy) % 13 < 3))
			if (xx - ax) % 6 == 0 or yy % 7 == 0:
				c = FacadeBuilder.tone(FacadeBuilder.WOOD, 0.8)
			b.dot(xx, yy, c, FacadeBuilder.Part.GLASS)
		b.dot(ax + aw / 2 - half - 1, yy, FacadeBuilder.tone(FacadeBuilder.WOOD, 1.1), FacadeBuilder.Part.TRIM)
		b.dot(ax + aw / 2 + half, yy, FacadeBuilder.tone(FacadeBuilder.WOOD, 0.6), FacadeBuilder.Part.TRIM)
	for c: int in _spread(3, ax - 2, maxi((ax - 2) / 12, 1)) + _spread(ax + aw + 2, fw - 3, maxi((fw - ax - aw - 2) / 12, 1)):
		b.window(c - 3, cap + 6, 7, 8, {"curtain": false})
	b.door(ax + aw / 2 - 5, 10, 11, "glass2")
	b.signboard(2, h - 13, ax - 4, 7, _label(["VISITORS", "INFO", "TRAIL"], ax - 4), Color(0.36, 0.25, 0.15), Color(0.9, 0.76, 0.34))
	var mx: int = ax + aw + 3
	if mx + 10 < fw:  # Sprouty, the cheerful trail mascot, on a post
		b.vline(mx + 3, h - 6, 6, FacadeBuilder.WOOD, FacadeBuilder.Part.PROP)
		_logo(b, mx, h - 14)
	b.edges(0, cap, fw, h - cap)
	b.side_wall(wall_c, 14)


# --- Sunnyseed Labs --------------------------------------------------------------------------

## Research wing: white panels, reinforced window slots, airlock entrance, biohazard warning,
## roof ventilation, pipes and the company logo.
static func _lab(b: FacadeBuilder) -> void:
	var wall_c: Color = b.pick("render")
	var n: int = _frame(b, 13, 20, 10, 2, FacadeBuilder.Surface.PANEL, wall_c)
	var fw: int = b.fw
	var h: int = b.height
	var top: int = b.facade_top
	for i: int in maxi(1, fw / 20):  # big ventilation fans and ducts
		var x: int = 4 + i * 20
		if x + 9 > fw:
			break
		b.fill(x, top - 7, 9, 5, FacadeBuilder.tone(b.pick("metal"), 1.15), FacadeBuilder.Part.PROP)
		b.fill(x + 2, top - 6, 5, 3, FacadeBuilder.tone(b.pick("metal"), 0.45), FacadeBuilder.Part.PROP)
		b.dot(x + 4, top - 5, FacadeBuilder.tone(b.pick("metal"), 1.3))
	for s: int in n:
		var sy: int = top + s * 13
		for c: int in _spread(3, fw - 3, maxi((fw - 6) / 14, 2)):
			b.window(c - 5, sy + 4, 10, 5, {"curtain": false, "bars": true})
		b.hline(0, sy + 12, fw, FacadeBuilder.tone(wall_c, 0.82), FacadeBuilder.Part.TRIM)
	b.hline(0, h - 20, fw, Color(0.42, 0.7, 0.34), FacadeBuilder.Part.TRIM)
	b.signboard(2, h - 19, fw - 4, 7, _label(["SUNNYSEED", "LAB B", "R-2"], fw - 14), wall_c, Color(0.3, 0.5, 0.26))
	_logo(b, 3, h - 19)
	var dx: int = fw / 2 - 5
	b.door(dx, 10, 11, "airlock", b.pick("door"))
	b.warning(dx - 9, h - 10)
	b.pipe(fw - 6, top, h - top - 2, Color(0.66, 0.7, 0.74))
	b.hazard(0, h - 2, fw, 2)
	b.edges(0, top, fw, h - top)
	b.side_wall(wall_c, 13)


## Laboratory tower (tinted glazing bands between white fins), or the Central Research Complex
## landmark (a glazed atrium up the middle, the logo and name on the roof line).
static func _lab_tower(b: FacadeBuilder, complex: bool) -> void:
	var wall_c: Color = b.pick("render")
	var n: int = _frame(b, 11, 18, 10 if complex else 6, 8, FacadeBuilder.Surface.PANEL, wall_c)
	var fw: int = b.fw
	var h: int = b.height
	var top: int = b.facade_top
	var tint: Color = Color(0.3, 0.5, 0.52)
	var d: float = b.look.get("decay", 0.3)
	var aw: int = clampi(fw / 3, 14, 30) if complex else 0
	var ax: int = (fw - aw) / 2
	for s: int in n:
		var sy: int = top + s * 11
		for xx: int in range(2, fw - 2):
			if complex and xx >= ax and xx < ax + aw:
				continue
			var c: Color = FacadeBuilder.tone(tint, 1.0 + 0.25 * float((xx + sy) % 11 < 3))
			var pane: float = b.hash01(xx / 5, s, 47)
			if pane < 0.06 + 0.3 * d:
				c = Color(0.04, 0.04, 0.05)
			for yy: int in range(sy + 3, sy + 9):
				b.dot(xx, yy, c, FacadeBuilder.Part.GLASS)
		b.floor_line(sy + 10, wall_c)
	for xx: int in range(2, fw - 2, 6):
		if not (complex and xx >= ax and xx < ax + aw):
			b.vline(xx, top, h - top - 18, FacadeBuilder.tone(wall_c, 1.08), FacadeBuilder.Part.WALL)
	if complex:
		for yy: int in range(top, h - 2):  # the atrium
			for xx: int in range(ax, ax + aw):
				var c: Color = FacadeBuilder.tone(b.pick("glass"), 1.0 + 0.3 * float((xx - yy) % 17 < 4))
				if (xx - ax) % 5 == 0 or (yy - top) % 8 == 0:
					c = FacadeBuilder.tone(b.pick("metal"), 1.2)
				b.dot(xx, yy, c, FacadeBuilder.Part.GLASS)
		if top >= 10:
			_logo(b, fw / 2 - 3, 1)
			var label: String = _label(["SUNNYSEED"], fw)
			if PixelFont.width(label) < fw / 2 - 8:
				b.text(4, top - 7, label, Color(0.36, 0.62, 0.3))
		b.door(ax + aw / 2 - 6, 12, 12, "airlock", b.pick("door"))
	else:
		_roof_clutter(b, false)
		for i: int in 2:
			b.pipe(4 + i * (fw - 12), 0, top, Color(0.7, 0.72, 0.75))
		b.signboard(fw / 2 - 12, h - 18, 24, 7, "R+D", wall_c, Color(0.3, 0.5, 0.26))
		b.door(fw / 2 - 5, 10, 10, "airlock", b.pick("door"))
	b.hazard(0, h - 2, fw, 2)
	b.edges(0, top, fw, h - top)
	b.side_wall(wall_c, 11)


## Containment block: a windowless monolith, blast door, hazard bands, red warning lights.
static func _containment(b: FacadeBuilder) -> void:
	var wall_c: Color = FacadeBuilder.tone(b.pick("concrete"), 1.05)
	_frame(b, 14, 24, 9, 4, FacadeBuilder.Surface.CONCRETE, wall_c)
	var fw: int = b.fw
	var h: int = b.height
	var top: int = b.facade_top
	for i: int in maxi(1, fw / 22):
		b.vent(4 + i * 22, top - 6, 10, 4)
	for xx: int in range(3, fw - 3, 12):  # grilles where windows would be
		b.vent(xx, top + 5, 6, 4)
	b.hazard(0, top + 1, 3, h - top - 1)
	b.hazard(fw - 3, top + 1, 3, h - top - 1)
	b.hazard(0, h - 5, fw, 3)
	var dw: int = mini(16, fw - 16)
	var dx: int = fw / 2 - dw / 2
	b.door(dx, dw, 14, "airlock", FacadeBuilder.tone(b.pick("metal"), 0.9))
	for xx: int in [dx - 6, dx + dw + 4]:
		b.fill(xx, h - 20, 2, 2, Color(0.95, 0.18, 0.15), FacadeBuilder.Part.PROP)
	var label: String = _label(["CONTAINMENT", "CONTAIN", "C-3"], fw - 8)
	b.text((fw - PixelFont.width(label)) / 2, h - 24, label, FacadeBuilder.tone(wall_c, 0.45))
	b.warning(dx - 12, h - 13)
	b.edges(0, top, fw, h - top)
	b.side_wall(wall_c, 14)

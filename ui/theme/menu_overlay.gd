class_name MenuOverlay
extends Control
## Backdrop of the in-game overlays (Pause, Wave Report, Downed): darkens the game, a vignette
## closing in from the edges, slow smoke drifting across and, for `pulse` > 0, a dark-red
## heartbeat in the vignette (Downed). Cheap: a few gradient textures moved each frame.
## Fills its parent and stops the mouse (the HUD and the game don't get clicks).

@export var shade: Color = Color(0.02, 0.02, 0.03, 0.72)
@export var vignette: Color = Color(0.0, 0.0, 0.0, 0.85)
## 0 = no heartbeat; 1 = full (Downed).
@export var pulse: float = 0.0

var _time: float = 0.0
var _edge: GradientTexture2D
var _puff: GradientTexture2D
## Smoke puffs: [position 0..1, drift speed px/s, radius px, alpha].
var _puffs: Array = []


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_edge = _radial([Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(1, 1, 1, 1)], [0.0, 0.45, 1.0])
	_puff = _radial([Color(1, 1, 1, 1), Color(1, 1, 1, 0)], [0.0, 1.0])
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 41
	for i: int in 7:
		_puffs.append([Vector2(rng.randf(), rng.randf_range(0.2, 1.0)), rng.randf_range(2.0, 5.0),
			rng.randf_range(50.0, 110.0), rng.randf_range(0.04, 0.08)])


func _radial(colours: Array, offsets: Array) -> GradientTexture2D:
	var g: Gradient = Gradient.new()
	g.colors = PackedColorArray(colours)
	g.offsets = PackedFloat32Array(offsets)
	var t: GradientTexture2D = GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 64
	t.height = 64
	return t


func _process(delta: float) -> void:
	if is_visible_in_tree():
		_time += delta
		queue_redraw()


func _draw() -> void:
	var s: Vector2 = size
	draw_rect(Rect2(Vector2.ZERO, s), shade)
	for p: Array in _puffs:
		var base: Vector2 = p[0]
		var r: float = p[2]
		var x: float = fposmod(base.x * (s.x + 2.0 * r) + _time * p[1], s.x + 2.0 * r) - r
		var y: float = base.y * s.y + sin(_time * 0.3 + base.x * 6.0) * 4.0
		draw_texture_rect(_puff, Rect2(x - r, y - r * 0.5, r * 2.0, r), false, Color(0.55, 0.5, 0.48, p[3]))
	var beat: float = 0.0
	if pulse > 0.0:
		var t: float = fmod(_time, 1.6)  # lub-dub
		beat = maxf(exp(-pow((t - 0.1) * 14.0, 2.0)), 0.7 * exp(-pow((t - 0.38) * 14.0, 2.0))) * pulse
	var edge: Color = vignette.lerp(Color(0.35, 0.02, 0.04, vignette.a), 0.35 * pulse + 0.4 * beat)
	draw_texture_rect(_edge, Rect2(-s.x * 0.15, -s.y * 0.3, s.x * 1.3, s.y * 1.6), false, edge)
	if pulse > 0.0:
		draw_rect(Rect2(Vector2.ZERO, s), Color(0.4, 0.0, 0.03, 0.06 * beat))

class_name TitleGlitch
extends Control
## Every few seconds, for a tenth of a second, its Label parent's text tears: a red and a steel
## copy shifted sideways and a dark slice through it. Rare and short, so the title stays readable.

const EVERY: Vector2 = Vector2(2.6, 4.5)
const LASTS: float = 0.12

var _next: float = 1.2
var _left: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _shift: float = 1.0
var _slice: float = 0.5


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_rng.seed = 7


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	if _left > 0.0:
		_left -= delta
		if _left <= 0.0:
			_next = _rng.randf_range(EVERY.x, EVERY.y)
		queue_redraw()
		return
	_next -= delta
	if _next <= 0.0:
		_left = LASTS
		_shift = 1.0 if _rng.randf() < 0.5 else -1.0
		_slice = _rng.randf_range(0.3, 0.7)
		queue_redraw()


func _draw() -> void:
	if _left <= 0.0:
		return
	var l: Label = get_parent() as Label
	if l == null:
		return
	var font: Font = l.get_theme_font(&"font")
	var fs: int = l.get_theme_font_size(&"font_size")
	var w: float = font.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var x: float = roundf((size.x - w) / 2.0) if l.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER else 0.0
	var base: float = roundf((size.y - font.get_height(fs)) / 2.0 + font.get_ascent(fs))
	draw_string(font, Vector2(x + 2.0 * _shift, base), l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(MenuStyle.CRIMSON, 0.7))
	draw_string(font, Vector2(x - _shift, base), l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(MenuStyle.STEEL, 0.55))
	draw_rect(Rect2(0, roundf(size.y * _slice), size.x, 1), Color(0, 0, 0, 0.8))

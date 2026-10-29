class_name MenuStyle
extends RefCounted
## The one look of every menu and overlay (main menu, Level Select, Settings, Pause, Wave Report,
## Downed, Safehouse): palette, fonts, the shared Theme, panels and small factories, so screens
## don't each restyle their own buttons.
##
## Sharp text: the game lays out in 480 x 270 and is integer-scaled (canvas_items). With font
## oversampling off (the HUD keeps its look, see test_render_settings) a font is rasterised at
## its nominal 7-16 px and every glyph texel is then blown up x2-x4 with nearest filtering: grey
## anti-aliasing blocks, smeared at small sizes. Menu text instead uses copies of the same font
## with the same metrics (layouts don't move): body text an MSDF copy (drawn from a distance
## field at whatever size it lands on screen), headings an emboldened copy rasterised at the
## window's integer scale (MSDF shows notches when emboldened), re-rasterised when that changes.

const BODY: int = 8
const SMALL: int = 7
const SECTION: int = 10
const HEADING: int = 12
const TITLE: int = 16

## Palette: charcoal / navy surfaces, bone text, blood-red accents, rust hover, steel borders.
const INK: Color = Color("#0a0b0e")
const CHARCOAL: Color = Color("#14161b")
const NAVY: Color = Color("#171d27")
const RAISED: Color = Color("#232833")
const STEEL: Color = Color("#4b515c")
const BONE: Color = Color("#e3dccd")
const MUTED: Color = Color("#a39d92")
const DIM: Color = Color("#6f6b64")
const BLOOD: Color = Color("#6d252a")
const CRIMSON: Color = Color("#a3282d")
const RUST: Color = Color("#b4503c")
## Readable red for text and highlights on the dark surfaces (contrast >= 4.5).
const EMBER: Color = Color("#de6a52")
const AMBER: Color = Color("#d9a441")
const SICK: Color = Color("#8fbf7a")

## Zone accents, Maple Hollow / Lowtide / Greywood / Sunnyseed Labs.
const ZONE_ACCENT: Array[Color] = [Color("#9aa4b0"), Color("#3fb0a3"), Color("#6f9a52"), Color("#e9e4dc")]
const ZONE_DARK: Array[Color] = [Color("#1b1f25"), Color("#0f2427"), Color("#0f1a10"), Color("#262629")]
## Sunnyseed turns from sterile white to flesh; used by the Labs card.
const FLESH: Color = Color("#b8343c")

static var _body: Font
static var _heading: Font
static var _heading_base: FontFile
static var _theme: Theme


## The UI font: an MSDF copy of the default font (crisp at any integer scale).
static func body_font() -> Font:
	if _body == null:
		var f: FontFile = (ThemeDB.fallback_font as FontFile).duplicate(true)
		f.multichannel_signed_distance_field = true
		f.msdf_pixel_range = 16
		f.msdf_size = 48
		_body = f
	return _body


## Headings: the same face, heavier and letter-spaced.
static func heading_font() -> Font:
	if _heading == null:
		_heading_base = (ThemeDB.fallback_font as FontFile).duplicate(true)
		var v: FontVariation = FontVariation.new()
		v.base_font = _heading_base
		v.variation_embolden = 0.6
		v.spacing_glyph = 1
		_heading = v
		var tree: SceneTree = Engine.get_main_loop() as SceneTree
		if tree != null and tree.root != null:
			tree.root.size_changed.connect(_match_window_scale)
		_match_window_scale()
	return _heading


## Rasterises the heading font at the window's integer scale (x2 at 720p, x3 at 810p, x4 at 1080p).
static func _match_window_scale() -> void:
	if _heading_base == null:
		return
	var win: Vector2i = DisplayServer.window_get_size() if DisplayServer.get_name() != "headless" else Vector2i(480, 270)
	var k: float = maxf(1.0, floorf(minf(win.x / 480.0, win.y / 270.0)))
	if _heading_base.oversampling != k:
		_heading_base.oversampling = k


## The shared menu Theme (built once).
static func theme() -> Theme:
	if _theme != null:
		return _theme
	var t: Theme = Theme.new()
	t.default_font = body_font()
	t.default_font_size = BODY
	_palette(t)
	t.set_color("font_color", "Label", BONE)
	t.set_constant("line_spacing", "Label", 0)
	_label_variant(t, "TitleLabel", TITLE, BONE, true)
	_label_variant(t, "HeadingLabel", HEADING, BONE, true)
	_label_variant(t, "SectionLabel", BODY, EMBER, true)
	_label_variant(t, "MutedLabel", BODY, MUTED, false)
	_label_variant(t, "HintLabel", SMALL, DIM, false)
	_label_variant(t, "AccentLabel", BODY, EMBER, false)
	_label_variant(t, "GoodLabel", BODY, SICK, false)
	_label_variant(t, "AmberLabel", BODY, AMBER, false)
	buttons(t)
	t.set_stylebox("panel", "PanelContainer", panel_box(CHARCOAL, STEEL, 6))
	t.set_type_variation("MenuPanel", "PanelContainer")
	t.set_stylebox("panel", "MenuPanel", panel_box(Color(CHARCOAL, 0.96), STEEL, 8))
	t.set_type_variation("CardPanel", "PanelContainer")
	t.set_stylebox("panel", "CardPanel", panel_box(Color(NAVY, 0.92), Color(STEEL, 0.55), 4))
	t.set_type_variation("ChipPanel", "PanelContainer")
	var chip: StyleBoxFlat = panel_box(Color(RAISED, 0.9), Color(STEEL, 0.6), 0)
	chip.content_margin_left = 4
	chip.content_margin_right = 4
	chip.content_margin_top = 1
	chip.content_margin_bottom = 1
	t.set_stylebox("panel", "ChipPanel", chip)
	t.set_constant("separation", "VBoxContainer", 3)
	t.set_constant("separation", "HBoxContainer", 4)
	toggles(t)
	t.set_stylebox("panel", "TooltipPanel", panel_box(Color(INK, 0.96), RUST, 3))
	t.set_color("font_color", "TooltipLabel", BONE)
	t.set_font_size("font_size", "TooltipLabel", BODY)
	_theme = t
	return t


## The between-wave screens keep their generated theme (ui/theme/ui_theme.tres, same palette,
## built by tools/build_ui_theme.gd); this gives it the crisp fonts at run time.
static func with_fonts(t: Theme) -> Theme:
	if t == null:
		return t
	t.default_font = body_font()
	for type: String in ["TitleLabel", "DangerTitleLabel", "SectionLabel", "PrimaryButton"]:
		t.set_font(&"font", type, heading_font())
	return t


static func _palette(t: Theme) -> void:
	for entry: Array in [["panel", CHARCOAL], ["card", NAVY], ["text", BONE], ["muted", MUTED],
			["accent", EMBER], ["danger", EMBER], ["raised", RAISED], ["border", STEEL], ["blood", BLOOD]]:
		t.set_color(entry[0], "Palette", entry[1])


static func _label_variant(t: Theme, name: String, size: int, color: Color, heading: bool) -> void:
	t.set_type_variation(name, "Label")
	t.set_font_size("font_size", name, size)
	t.set_color("font_color", name, color)
	if heading:
		t.set_font("font", name, heading_font())


# --- boxes ------------------------------------------------------------------------------------

## Worn metal plate: dark fill, a steel rim lit on top and shadowed below, square corners, a
## hard drop shadow. `margin` = content margin.
static func panel_box(fill: Color, rim: Color, margin: int) -> StyleBoxFlat:
	var b: StyleBoxFlat = StyleBoxFlat.new()
	b.bg_color = fill
	b.border_color = rim
	b.border_width_top = 1
	b.border_width_bottom = 1
	b.border_width_left = 1
	b.border_width_right = 1
	b.border_blend = false
	b.set_content_margin_all(margin)
	b.shadow_color = Color(0, 0, 0, 0.5)
	b.shadow_size = 0
	b.shadow_offset = Vector2(2, 2)
	b.anti_aliasing = false
	return b


## Button plates: a dried-blood bar on the left that ButtonFx widens and lights on hover / focus.
static func button_box(fill: Color, bar: Color, rim: Color) -> StyleBoxFlat:
	var b: StyleBoxFlat = StyleBoxFlat.new()
	b.bg_color = fill
	b.border_color = rim
	b.border_width_left = 2
	b.border_width_top = 1
	b.border_width_bottom = 1
	b.border_width_right = 1
	b.content_margin_left = 10.0
	b.content_margin_right = 10.0
	b.content_margin_top = 2.0
	b.content_margin_bottom = 2.0
	b.anti_aliasing = false
	b.set_meta("bar", bar)
	return b


## Button, CheckBox and the Primary / Tertiary variations used by the report screens.
static func buttons(t: Theme) -> void:
	t.set_font_size("font_size", "Button", BODY)
	_button_type(t, "Button", Color(CHARCOAL, 0.94), Color(STEEL, 0.55), BONE.darkened(0.12))
	t.set_type_variation("PrimaryButton", "Button")
	_button_type(t, "PrimaryButton", Color(BLOOD, 0.95), CRIMSON, BONE)
	t.set_font_size("font_size", "PrimaryButton", SECTION)
	t.set_type_variation("TertiaryButton", "Button")
	_button_type(t, "TertiaryButton", Color(0, 0, 0, 0), Color(0, 0, 0, 0), MUTED)
	t.set_type_variation("TileButton", "Button")
	_button_type(t, "TileButton", Color(INK, 0.55), Color(STEEL, 0.35), BONE.darkened(0.08))
	var tile: StyleBoxFlat = t.get_stylebox("normal", "TileButton")
	tile.border_width_left = 1


static func _button_type(t: Theme, type: String, fill: Color, rim: Color, fg: Color) -> void:
	var normal: StyleBoxFlat = button_box(fill, BLOOD, rim)
	normal.border_color = rim
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = Color(0.2, 0.075, 0.08, 0.96) if fill.a > 0.0 else Color(RAISED, 0.7)
	hover.border_color = RUST
	var pressed: StyleBoxFlat = normal.duplicate()
	pressed.bg_color = Color(0.32, 0.09, 0.1, 0.98)
	pressed.border_color = EMBER
	var disabled: StyleBoxFlat = normal.duplicate()
	disabled.bg_color = Color(fill, fill.a * 0.5)
	disabled.border_color = Color(rim, rim.a * 0.4)
	var focus: StyleBoxFlat = StyleBoxFlat.new()
	focus.draw_center = false
	focus.border_color = Color(EMBER, 0.9)
	focus.set_border_width_all(1)
	focus.border_width_left = 2
	focus.anti_aliasing = false
	t.set_stylebox("normal", type, normal)
	t.set_stylebox("hover", type, hover)
	t.set_stylebox("pressed", type, pressed)
	t.set_stylebox("hover_pressed", type, pressed)
	t.set_stylebox("disabled", type, disabled)
	t.set_stylebox("focus", type, focus)
	t.set_color("font_color", type, fg)
	for state: String in ["font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
		t.set_color(state, type, Color.WHITE if type != "TertiaryButton" else BONE)
	t.set_color("font_disabled_color", type, Color(DIM, 0.8))
	t.set_color("font_outline_color", type, Color(0, 0, 0, 0.85))
	t.set_constant("outline_size", type, 0)
	t.set_constant("h_separation", type, 4)


## Pixel toggles for CheckBox / CheckButton: a steel square, filled crimson with a bone tick when on.
static func toggles(t: Theme) -> void:
	var off: ImageTexture = ImageTexture.create_from_image(_box_icon(false))
	var on: ImageTexture = ImageTexture.create_from_image(_box_icon(true))
	for type: String in ["CheckBox", "CheckButton"]:
		_button_type(t, type, Color(CHARCOAL, 0.94), Color(STEEL, 0.55), BONE.darkened(0.12))
		t.set_icon("unchecked", type, off)
		t.set_icon("checked", type, on)
		t.set_icon("unchecked_disabled", type, off)
		t.set_icon("checked_disabled", type, on)
		t.set_icon("unchecked_mirrored", type, off)
		t.set_icon("checked_mirrored", type, on)
		t.set_icon("checked_disabled_mirrored", type, on)
		t.set_icon("unchecked_disabled_mirrored", type, off)


static func _box_icon(checked: bool) -> Image:
	var img: Image = Image.create(8, 8, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	img.fill_rect(Rect2i(0, 0, 8, 8), STEEL)
	img.fill_rect(Rect2i(1, 1, 6, 6), CRIMSON if checked else INK)
	if checked:
		for p: Vector2i in [Vector2i(2, 4), Vector2i(3, 5), Vector2i(4, 4), Vector2i(5, 3), Vector2i(5, 2)]:
			img.set_pixelv(p, BONE)
	return img


# --- factories --------------------------------------------------------------------------------

static func label(parent: Node, text: String, variation: StringName = &"", center: bool = false) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.theme_type_variation = variation
	if center:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(l)
	return l


## A menu button with the animated blood bar / chevron (ButtonFx).
static func button(parent: Node, text: String, action: Callable, width: float = 128.0, variation: StringName = &"") -> Button:
	var b: Button = Button.new()
	b.text = text
	b.theme_type_variation = variation
	b.custom_minimum_size = Vector2(width, 16)
	b.focus_mode = Control.FOCUS_ALL
	if action.is_valid():
		b.pressed.connect(action)
	parent.add_child(b)
	decorate(b)
	return b


## Adds the hover / focus animation to any button (idempotent).
static func decorate(b: BaseButton) -> void:
	if b.get_node_or_null("Fx") != null:
		return
	var fx: ButtonFx = ButtonFx.new()
	fx.name = "Fx"
	b.add_child(fx)


## A heading with a blood rule under it (title of a page or panel).
static func heading(parent: Node, text: String, variation: StringName = &"HeadingLabel", rule_width: float = 64.0) -> VBoxContainer:
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 1)
	parent.add_child(box)
	label(box, text, variation, true)
	var rule: RuleLine = RuleLine.new()
	rule.custom_minimum_size = Vector2(rule_width, 3)
	rule.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(rule)
	return box


## Fades and lifts `node` in (panels, pages); returns the tween.
static func enter(node: CanvasItem, lift: float = 6.0, seconds: float = 0.22, delay: float = 0.0) -> Tween:
	node.modulate.a = 0.0
	var tw: Tween = node.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "modulate:a", 1.0, seconds).set_delay(delay)
	if node is Control and lift != 0.0 and not ((node as Control).get_parent() is Container):
		var c: Control = node
		var y: float = c.position.y
		c.position.y = y + lift
		tw.tween_property(c, "position:y", y, seconds).set_delay(delay)
	return tw


## First visible, enabled focusable button under `root` (to give focus to).
static func first_button(root: Node) -> Button:
	for n: Node in root.find_children("*", "BaseButton", true, false):
		var b: BaseButton = n
		if b is Button and b.is_visible_in_tree() and not b.disabled and b.focus_mode != Control.FOCUS_NONE:
			return b
	return null


## Key reminder in the footer: "KEY action   KEY action ...".
static func key_hints(parent: Node, pairs: Array) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	parent.add_child(row)
	for pair: Array in pairs:
		var item: HBoxContainer = HBoxContainer.new()
		item.add_theme_constant_override("separation", 3)
		row.add_child(item)
		var key: PanelContainer = PanelContainer.new()
		key.theme_type_variation = &"ChipPanel"
		item.add_child(key)
		var k: Label = label(key, pair[0], &"HintLabel")
		k.add_theme_color_override("font_color", BONE.darkened(0.15))
		label(item, pair[1], &"HintLabel")
	return row

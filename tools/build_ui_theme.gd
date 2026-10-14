extends SceneTree
## Builds ui/theme/ui_theme.tres: the one Theme for the between-wave screens (Wave Report,
## Downed). Run headless:  godot --headless --path . -s res://tools/build_ui_theme.gd
##
## Sizes are viewport pixels. The 480 x 270 viewport is integer-scaled: x2 at 1280 x 720 and
## 1366 x 768, x4 at 1920 x 1080. So the 8 px grid is SPACE = 4 viewport px, and font sizes
## 16 / 10 / 8 / 7 are 32 / 20 / 16 / 14 px at 720p (title / section / body / minimum).

const OUT: String = "res://ui/theme/ui_theme.tres"

const PANEL: Color = Color("#16181d")
const CARD: Color = Color("#1f2229")
const TEXT: Color = Color("#e8e6e3")
const MUTED: Color = Color("#9aa0a6")
const ACCENT: Color = Color("#e8b84a")
const UP: Color = Color("#ff8a4c")      # stronger enemies
const DOWN: Color = Color("#5aa9e6")    # weaker enemies
const DANGER: Color = Color("#e5534b")
const RAISED: Color = Color("#2a2e37")  # chips, buttons, bar tracks (between card and text)
const BORDER: Color = Color("#2f343e")

const SPACE: int = 4
const TITLE: int = 16
const SECTION: int = 10
const BODY: int = 8
const SMALL: int = 7


func _initialize() -> void:
	var t: Theme = Theme.new()
	t.default_font_size = BODY

	# Palette: custom controls (bars, sparkline) read colours from here.
	for entry: Array in [["panel", PANEL], ["card", CARD], ["text", TEXT], ["muted", MUTED],
			["accent", ACCENT], ["up", UP], ["down", DOWN], ["danger", DANGER], ["raised", RAISED],
			["border", BORDER]]:
		t.set_color(entry[0], "Palette", entry[1])
	t.set_constant("space", "Palette", SPACE)

	# Labels.
	t.set_color("font_color", "Label", TEXT)
	t.set_font_size("font_size", "Label", BODY)
	t.set_constant("line_spacing", "Label", 0)
	_label_variant(t, "TitleLabel", TITLE, TEXT)
	_label_variant(t, "DangerTitleLabel", TITLE, DANGER)
	_label_variant(t, "SectionLabel", SECTION, TEXT)
	_label_variant(t, "MutedLabel", BODY, MUTED)
	_label_variant(t, "AccentLabel", BODY, ACCENT)
	_label_variant(t, "SmallLabel", SMALL, MUTED)
	_label_variant(t, "SmallTextLabel", SMALL, TEXT)
	_label_variant(t, "UpLabel", SMALL, PANEL)    # text on an orange pill
	_label_variant(t, "DownLabel", SMALL, PANEL)  # text on a blue pill
	_label_variant(t, "BadgeLabel", SMALL, PANEL)

	# Panels.
	t.set_stylebox("panel", "PanelContainer", _box(CARD, 0, SPACE))
	t.set_type_variation("ReportPanel", "PanelContainer")
	var panel: StyleBoxFlat = _box(PANEL, 2, 2 * SPACE)
	panel.border_color = BORDER
	panel.set_border_width_all(1)
	t.set_stylebox("panel", "ReportPanel", panel)
	t.set_type_variation("Card", "PanelContainer")
	t.set_stylebox("panel", "Card", _box(CARD, 2, SPACE))
	t.set_type_variation("Chip", "PanelContainer")
	t.set_stylebox("panel", "Chip", _box(RAISED, 6, 0, SPACE, 1))
	t.set_type_variation("AccentChip", "PanelContainer")
	t.set_stylebox("panel", "AccentChip", _box(ACCENT.darkened(0.55), 6, 0, SPACE, 1))
	t.set_type_variation("UpPill", "PanelContainer")
	t.set_stylebox("panel", "UpPill", _box(UP, 6, 0, 3, 0))
	t.set_type_variation("DownPill", "PanelContainer")
	t.set_stylebox("panel", "DownPill", _box(DOWN, 6, 0, 3, 0))
	t.set_type_variation("SamePill", "PanelContainer")
	t.set_stylebox("panel", "SamePill", _box(RAISED, 6, 0, 3, 0))
	t.set_type_variation("Badge", "PanelContainer")
	t.set_stylebox("panel", "Badge", _box(ACCENT, 6, 0, 3, 0))

	# Containers: the 8 px grid.
	t.set_constant("separation", "VBoxContainer", SPACE)
	t.set_constant("separation", "HBoxContainer", SPACE)
	t.set_constant("h_separation", "GridContainer", SPACE)
	t.set_constant("v_separation", "GridContainer", 1)
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		t.set_constant(side, "MarginContainer", 2 * SPACE)

	# Buttons: secondary (default), primary, tertiary; focus ring in the accent colour.
	t.set_font_size("font_size", "Button", BODY)
	_button(t, "Button", RAISED, TEXT)
	t.set_type_variation("PrimaryButton", "Button")
	_button(t, "PrimaryButton", ACCENT, PANEL)
	t.set_font_size("font_size", "PrimaryButton", SECTION)
	t.set_type_variation("TertiaryButton", "Button")
	_button(t, "TertiaryButton", Color(0, 0, 0, 0), MUTED)

	# Tooltips.
	t.set_stylebox("panel", "TooltipPanel", _box(RAISED, 2, SPACE))
	t.set_color("font_color", "TooltipLabel", TEXT)
	t.set_font_size("font_size", "TooltipLabel", BODY)

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT.get_base_dir()))
	var err: Error = ResourceSaver.save(t, OUT)
	print("ui theme -> %s (%s)" % [OUT, error_string(err)])
	quit(0 if err == OK else 1)


func _label_variant(t: Theme, name: String, size: int, color: Color) -> void:
	t.set_type_variation(name, "Label")
	t.set_font_size("font_size", name, size)
	t.set_color("font_color", name, color)


func _button(t: Theme, type: String, bg: Color, fg: Color) -> void:
	var normal: StyleBoxFlat = _box(bg, 2, 0, 2 * SPACE, 2)
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = bg.lightened(0.12) if bg.a > 0.0 else Color(RAISED, 0.6)
	var pressed: StyleBoxFlat = normal.duplicate()
	pressed.bg_color = bg.darkened(0.15) if bg.a > 0.0 else RAISED
	var disabled: StyleBoxFlat = normal.duplicate()
	disabled.bg_color = Color(bg, bg.a * 0.4)
	var focus: StyleBoxFlat = StyleBoxFlat.new()
	focus.draw_center = false
	focus.border_color = ACCENT if type != "PrimaryButton" else TEXT
	focus.set_border_width_all(1)
	focus.set_corner_radius_all(3)
	focus.set_expand_margin_all(2)
	t.set_stylebox("normal", type, normal)
	t.set_stylebox("hover", type, hover)
	t.set_stylebox("pressed", type, pressed)
	t.set_stylebox("disabled", type, disabled)
	t.set_stylebox("focus", type, focus)
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		t.set_color(state, type, fg if type != "TertiaryButton" or state == "font_color" else TEXT)
	t.set_color("font_disabled_color", type, Color(fg, 0.5))


## Flat box: colour, corner radius, all-round content margin (or horizontal / vertical).
func _box(color: Color, radius: int, margin: int, h: int = -1, v: int = -1) -> StyleBoxFlat:
	var b: StyleBoxFlat = StyleBoxFlat.new()
	b.bg_color = color
	b.set_corner_radius_all(radius)
	b.content_margin_left = margin if h < 0 else h
	b.content_margin_right = margin if h < 0 else h
	b.content_margin_top = margin if v < 0 else v
	b.content_margin_bottom = margin if v < 0 else v
	return b

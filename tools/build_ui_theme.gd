extends SceneTree
## Builds ui/theme/ui_theme.tres: the Theme of the between-wave screens (Wave Report, Downed),
## in MenuStyle's palette and with its button plates, so they match the other menus. Fonts are
## not saved here (the crisp MSDF font is made at run time: MenuStyle.with_fonts).
## Run headless:  godot --headless --path . -s res://tools/build_ui_theme.gd
##
## Sizes are viewport pixels. The 480 x 270 viewport is integer-scaled: x2 at 1280 x 720 and
## 1366 x 768, x4 at 1920 x 1080. So the 8 px grid is SPACE = 4 viewport px, and font sizes
## 16 / 10 / 8 / 7 are 32 / 20 / 16 / 14 px at 720p (title / section / body / minimum).

const OUT: String = "res://ui/theme/ui_theme.tres"

const PANEL: Color = MenuStyle.CHARCOAL
const CARD: Color = MenuStyle.NAVY
const TEXT: Color = MenuStyle.BONE
const MUTED: Color = MenuStyle.MUTED
const ACCENT: Color = MenuStyle.EMBER
const UP: Color = Color("#e0703f")      # stronger enemies
const DOWN: Color = Color("#6f9cc0")    # weaker enemies
const DANGER: Color = MenuStyle.EMBER
const RAISED: Color = MenuStyle.RAISED  # chips, bar tracks (between card and text)
const BORDER: Color = MenuStyle.STEEL

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
	var panel: StyleBoxFlat = MenuStyle.panel_box(Color(PANEL, 0.97), Color(BORDER, 0.8), 2 * SPACE)
	panel.border_width_top = 2
	panel.border_color = BORDER
	t.set_stylebox("panel", "ReportPanel", panel)
	t.set_type_variation("Card", "PanelContainer")
	t.set_stylebox("panel", "Card", MenuStyle.panel_box(Color(CARD, 0.92), Color(BORDER, 0.45), SPACE))
	t.set_type_variation("Chip", "PanelContainer")
	t.set_stylebox("panel", "Chip", _box(RAISED, 0, 0, SPACE, 1))
	t.set_type_variation("AccentChip", "PanelContainer")
	t.set_stylebox("panel", "AccentChip", _box(MenuStyle.BLOOD.darkened(0.2), 0, 0, SPACE, 1))
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

	# Buttons: secondary (default), primary (blood plate), tertiary - MenuStyle's plates.
	MenuStyle.buttons(t)

	# Tooltips.
	t.set_stylebox("panel", "TooltipPanel", MenuStyle.panel_box(Color(MenuStyle.INK, 0.96), MenuStyle.RUST, SPACE))
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

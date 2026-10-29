class_name LevelSelect
extends VBoxContainer
## Level Select page of the main menu (test scenarios: jump right before a campaign moment;
## nothing is saved - DebugScenarios). Four zone cards side by side, each with its own colour
## and a small pixel vignette (ZoneArt), its levels as rows; a detail strip names the level under
## the cursor (title, objective, waves, challenges); the campaign transitions and the Endless
## loop below. The actions are the main menu's (it passes them in), so nothing about launching
## changed.

const OBJECTIVE_NAMES: Array[String] = ["Survive", "Hold the point", "Escort", "Purge nests", "Extract", "Stealth", "Apex boss"]
const CARD_WIDTH: float = 110.0

## Callables from the main menu: scenario(dict), level(zone 1-4, level index), endless(), back().
var on_scenario: Callable
var on_level: Callable
var on_endless: Callable
var on_back: Callable

var first_button: Button
var last_wave: CheckBox
var _detail_title: Label
var _detail_info: Label
var _cards: Array[PanelContainer] = []


func _ready() -> void:
	add_theme_constant_override("separation", 4)
	var header: HBoxContainer = HBoxContainer.new()
	header.custom_minimum_size = Vector2(462, 0)
	header.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	add_child(header)
	var back: Button = MenuStyle.button(header, "Back", func() -> void: on_back.call(), 70.0)
	back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var head: VBoxContainer = MenuStyle.heading(header, "LEVEL SELECT", &"TitleLabel", 110.0)
	head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var spacer: Control = Control.new()  # balances the Back button so the title stays centred
	spacer.custom_minimum_size = Vector2(70, 0)
	header.add_child(spacer)

	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(row)
	var zones: Array[ZoneConfig] = GameState.campaign().zones
	for z: int in zones.size():
		row.add_child(_zone_card(z, zones[z]))

	var strip: PanelContainer = PanelContainer.new()
	strip.theme_type_variation = &"CardPanel"
	strip.custom_minimum_size = Vector2(462, 0)
	strip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	add_child(strip)
	var strip_row: HBoxContainer = HBoxContainer.new()
	strip_row.add_theme_constant_override("separation", 6)
	strip.add_child(strip_row)
	var text: VBoxContainer = VBoxContainer.new()
	text.add_theme_constant_override("separation", 0)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	strip_row.add_child(text)
	_detail_title = MenuStyle.label(text, "", &"AccentLabel")
	_detail_info = MenuStyle.label(text, "", &"HintLabel")
	last_wave = CheckBox.new()
	last_wave.text = "Start at the last wave"
	last_wave.custom_minimum_size = Vector2(112, 16)
	last_wave.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	strip_row.add_child(last_wave)
	MenuStyle.decorate(last_wave)

	var moments: VBoxContainer = VBoxContainer.new()
	moments.add_theme_constant_override("separation", 2)
	moments.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	add_child(moments)
	MenuStyle.label(moments, "CAMPAIGN MOMENTS", &"SectionLabel")
	var grid: GridContainer = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 3)
	moments.add_child(grid)
	for scenario: Dictionary in DebugScenarios.SCENARIOS:
		var b: Button = MenuStyle.button(grid, scenario["text"], func() -> void: on_scenario.call(scenario), 150.0)
		b.mouse_entered.connect(_show_moment.bind(scenario["text"]))
		b.focus_entered.connect(_show_moment.bind(scenario["text"]))
	var endless: Button = MenuStyle.button(grid, "Endless (wave loop)", func() -> void: on_endless.call(), 150.0)
	endless.mouse_entered.connect(_show_endless)
	endless.focus_entered.connect(_show_endless)
	_show_level(0, zones[0], 0)
	_detail_info.text = "Jump in right before any moment of the campaign. Nothing is saved." + (
			"  F8 ends the current wave." if DebugKeys.enabled() else "")


func _zone_card(z: int, zone: ZoneConfig) -> PanelContainer:
	var card: PanelContainer = PanelContainer.new()
	card.custom_minimum_size = Vector2(CARD_WIDTH, 0)
	card.add_theme_stylebox_override("panel", _card_box(z, false))
	_cards.append(card)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	card.add_child(box)
	var art: TextureRect = TextureRect.new()
	art.texture = ZoneArt.texture(z)
	art.stretch_mode = TextureRect.STRETCH_KEEP
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	box.add_child(art)
	var name_row: HBoxContainer = HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 4)
	box.add_child(name_row)
	var num: Label = MenuStyle.label(name_row, "%d" % (z + 1), &"HeadingLabel")
	num.add_theme_color_override("font_color", MenuStyle.ZONE_ACCENT[z])
	var title: Label = MenuStyle.label(name_row, zone.title.to_upper(), &"SectionLabel")
	title.add_theme_color_override("font_color", MenuStyle.BONE)
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.clip_text = true  # the card keeps its width; "SUNNYSEED LABS" just fits
	for l: int in zone.levels.size():
		var level: LevelConfig = zone.levels[l]
		var apex: bool = l == zone.levels.size() - 1
		var b: Button = MenuStyle.button(box, "%s   %s" % ["APEX" if apex else "0%d" % (l + 1), _short_title(level)],
				func() -> void: on_level.call(z + 1, l), CARD_WIDTH - 8.0, &"TileButton")
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.tooltip_text = level.title
		b.add_theme_color_override("font_focus_color", MenuStyle.ZONE_ACCENT[z].lightened(0.3))
		b.add_theme_color_override("font_hover_color", MenuStyle.ZONE_ACCENT[z].lightened(0.3))
		if apex:
			b.add_theme_color_override("font_color", MenuStyle.EMBER)
		b.mouse_entered.connect(_show_level.bind(z, zone, l))
		b.focus_entered.connect(_show_level.bind(z, zone, l))
		if first_button == null:
			first_button = b
	return card


## Zone card plate: the zone's dark tone, its accent along the top, brighter rim when selected.
func _card_box(z: int, selected: bool) -> StyleBoxFlat:
	var b: StyleBoxFlat = MenuStyle.panel_box(Color(MenuStyle.ZONE_DARK[z], 0.95),
			MenuStyle.ZONE_ACCENT[z] if selected else Color(MenuStyle.STEEL, 0.5), 3)
	b.border_width_top = 2
	b.border_color = MenuStyle.ZONE_ACCENT[z] if selected else Color(MenuStyle.ZONE_ACCENT[z], 0.45)
	b.shadow_size = 2 if selected else 0
	b.shadow_color = Color(MenuStyle.ZONE_ACCENT[z], 0.18) if selected else Color(0, 0, 0, 0.5)
	return b


## "Maple Hollow 2: Hold the point" -> "Hold the point"; "Maple Hollow Apex" -> the zone's boss level.
static func _short_title(level: LevelConfig) -> String:
	var parts: PackedStringArray = level.title.split(": ", false, 1)
	if parts.size() == 2:
		return parts[1]
	return "Boss" if level.title.ends_with("Apex") else level.title


func _show_level(z: int, zone: ZoneConfig, l: int) -> void:
	var level: LevelConfig = zone.levels[l]
	_detail_title.text = level.title
	_detail_title.add_theme_color_override("font_color", MenuStyle.ZONE_ACCENT[z].lightened(0.2))
	var bits: PackedStringArray = PackedStringArray()
	bits.append(OBJECTIVE_NAMES[level.objective.type] if level.objective != null else "Survive")
	bits.append("%d wave%s" % [level.waves, "" if level.waves == 1 else "s"])
	for side: SideObjective in level.side_objectives:
		bits.append("challenge: " + side.title)
	_detail_info.text = "  ·  ".join(bits)
	for i: int in _cards.size():
		_cards[i].add_theme_stylebox_override("panel", _card_box(i, i == z))


func _show_moment(text: String) -> void:
	_detail_title.text = text
	_detail_title.add_theme_color_override("font_color", MenuStyle.EMBER)
	_detail_info.text = "Starts right before this moment of the campaign."
	for i: int in _cards.size():
		_cards[i].add_theme_stylebox_override("panel", _card_box(i, false))


func _show_endless() -> void:
	_detail_title.text = "Endless (wave loop)"
	_detail_title.add_theme_color_override("font_color", MenuStyle.EMBER)
	_detail_info.text = "The plain evolution loop on Maple Hollow: no objective, no end, nothing saved."
	for i: int in _cards.size():
		_cards[i].add_theme_stylebox_override("panel", _card_box(i, false))

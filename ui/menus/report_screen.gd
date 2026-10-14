class_name ReportScreen
extends Control
## Shared frame of the between-wave screens (Wave Report, Downed): dim full-screen backdrop,
## a panel anchored to the screen with margins (no fixed positions - containers lay it out),
## pages that swap inside the panel (overview / details / ...), slide-in motion, the Skills
## button with its points badge, and the keys: Enter = skip the motion, then the primary
## action; D = details; K = skill tree (handled by SkillTreeMenu).
##
## The node tree is built ONCE in _ready; every wave only refills it (set_* calls, pages shown
## or hidden), so nothing piles up between waves. Look: ui/theme/ui_theme.tres
## (tools/build_ui_theme.gd). Sizes are viewport px (x2 at 720p, x4 at 1080p).

const THEME_PATH: String = "res://ui/theme/ui_theme.tres"
const SLIDE_PX: float = 8.0
const SLIDE_SECONDS: float = 0.25
const BAR_SECONDS: float = 0.6
const CHIP_STAGGER: float = 0.06

## Opens the skill tree (connected by the level).
signal skills_requested

## Set by the level: unspent skill points on the Skills badge.
var player: Player

var _backdrop: ColorRect
var _frame: MarginContainer
var _panel: PanelContainer
## Pages by name; exactly one is visible.
var _pages: Dictionary = {}
var _page_box: VBoxContainer
var _current_page: String = ""
var _details_button: Button
var _skills_button: Button
var _badge: PanelContainer
var _badge_label: Label
var _pulse: Tween
var _tweens: Array[Tween] = []


func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS  # works while the game is paused
	theme = load(THEME_PATH)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_backdrop = ColorRect.new()
	_backdrop.name = "Backdrop"
	_backdrop.color = Color(get_theme_color(&"panel", &"Palette"), 0.88)
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP  # the HUD and the game don't get clicks
	add_child(_backdrop)
	_frame = MarginContainer.new()
	_frame.name = "Frame"
	_frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	_frame.resized.connect(_fit_frame, CONNECT_DEFERRED)
	_frame.minimum_size_changed.connect(_fit_frame, CONNECT_DEFERRED)
	add_child(_frame)
	_panel = PanelContainer.new()
	_panel.name = "Panel"
	_panel.theme_type_variation = &"ReportPanel"
	_frame.add_child(_panel)
	var root: VBoxContainer = VBoxContainer.new()
	root.name = "Root"
	_panel.add_child(root)
	_build_header(root)
	_page_box = VBoxContainer.new()
	_page_box.name = "Pages"
	_page_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_page_box)
	_build_pages()
	_build_footer(root)


## Keeps the frame the size of the screen. An anchored control grows when its content asks
## for more room but never shrinks back by itself (a wrapped label briefly asks for a lot
## before it knows its width), so it is put back here. Real overflow still shows (Godot keeps
## a control at least at its minimum size), and the tests check for it.
func _fit_frame() -> void:
	var slide: float = _frame.offset_top  # the slide-in moves top and bottom together
	if not is_equal_approx(_frame.offset_bottom, slide) or _frame.offset_left != 0.0 or _frame.offset_right != 0.0:
		_frame.offset_left = 0.0
		_frame.offset_right = 0.0
		_frame.offset_bottom = slide


# --- To fill in by each screen ----------------------------------------------------------

func _build_header(_root: VBoxContainer) -> void:
	pass


## Calls add_page() for each page; the first one is the default.
func _build_pages() -> void:
	pass


func _build_footer(_root: VBoxContainer) -> void:
	pass


## Enter (after the motion): Continue / Retry.
func _primary_action() -> void:
	pass


## The button Enter presses (gets the focus ring).
func _primary_button() -> Button:
	return null


# --- Opening, keys, motion --------------------------------------------------------------

## Shows the screen on its first page, plays the slide-in and focuses the primary button.
func present() -> void:
	show_page(_pages.keys()[0])
	visible = true
	_update_skills()
	_play_in()
	var primary: Button = _primary_button()
	if primary != null:
		primary.grab_focus.call_deferred()


func _process(_delta: float) -> void:
	if visible:
		_update_skills()  # points change while the skill tree is open on top


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		if not skip_motion():
			_primary_action()
	elif event.is_action_pressed("report_details"):
		get_viewport().set_input_as_handled()
		toggle_details()


## Details (D): raw data on / off.
func toggle_details() -> void:
	show_page(_pages.keys()[0] if _current_page == "details" else "details")


func show_page(page_name: String) -> void:
	_current_page = page_name
	for n: String in _pages:
		(_pages[n] as Control).visible = n == page_name
	if _details_button != null:
		_details_button.text = "Hide details (D)" if page_name == "details" else "Details (D)"


func add_page(page_name: String) -> VBoxContainer:
	var page: VBoxContainer = VBoxContainer.new()
	page.name = page_name.capitalize().replace(" ", "")
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.visible = _pages.is_empty()
	_page_box.add_child(page)
	_pages[page_name] = page
	return page


func current_page() -> String:
	return _current_page


## Jumps every running animation to its end. True if something was still moving.
func skip_motion() -> bool:
	var skipped: bool = false
	for t: Tween in _tweens:
		if t.is_valid() and t.is_running():
			t.custom_step(60.0)
			skipped = true
	_tweens.clear()
	return skipped


func is_animating() -> bool:
	for t: Tween in _tweens:
		if t.is_valid() and t.is_running():
			return true
	return false


## A tween that runs while the game is paused and that Enter can skip.
func motion() -> Tween:
	var t: Tween = create_tween()
	t.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tweens.append(t)
	return t


func _play_in() -> void:
	skip_motion()
	_frame.modulate.a = 0.0
	_frame.position.y = SLIDE_PX
	var t: Tween = motion().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(_frame, "modulate:a", 1.0, SLIDE_SECONDS)
	t.tween_property(_frame, "position:y", 0.0, SLIDE_SECONDS)


## Fills a bar from `from` to `to` (0.6 s).
func tween_bar(bar: Control, prop: String, from: float, to: float, delay: float = 0.0) -> void:
	bar.set(prop, from)
	motion().tween_property(bar, prop, to, BAR_SECONDS).set_delay(SLIDE_SECONDS * 0.5 + delay) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## Counts a number up into a label: fmt is a format string with one number (0.6 s).
func count_up(label: Label, fmt: String, to: float, from: float = 0.0) -> void:
	label.text = fmt % from
	motion().tween_method(func(v: float) -> void: label.text = fmt % v, from, to, BAR_SECONDS) \
		.set_delay(SLIDE_SECONDS * 0.5)


## Fades controls in one after the other (60 ms apart).
func stagger_in(controls: Array) -> void:
	for i: int in controls.size():
		var c: CanvasItem = controls[i]
		c.modulate.a = 0.0
		motion().tween_property(c, "modulate:a", 1.0, 0.15).set_delay(SLIDE_SECONDS * 0.5 + CHIP_STAGGER * i)


# --- Skills button + badge ----------------------------------------------------------------

func add_skills_button(parent: Container) -> void:
	_skills_button = add_button(parent, "Skills (K)", skills_requested.emit, &"")
	_badge = PanelContainer.new()
	_badge.theme_type_variation = &"Badge"
	_badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_badge_label = label(_badge, "", &"BadgeLabel")
	parent.add_child(_badge)


func _update_skills() -> void:
	if _skills_button == null:
		return
	var points: int = player.progression.skill_points if player != null else 0
	_badge.visible = points > 0
	_badge_label.text = "%d point%s" % [points, "" if points == 1 else "s"]
	_skills_button.tooltip_text = "Spend skill points (K)" if points > 0 else "Skill tree (K)"
	if points > 0 and (_pulse == null or not _pulse.is_valid()):
		_pulse = create_tween().set_loops()
		_pulse.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		_pulse.tween_property(_badge, "modulate:a", 0.45, 0.6)
		_pulse.tween_property(_badge, "modulate:a", 1.0, 0.6)
	elif points == 0 and _pulse != null and _pulse.is_valid():
		_pulse.kill()
		_badge.modulate.a = 1.0


func add_details_button(parent: Container) -> void:
	_details_button = add_button(parent, "Details (D)", toggle_details, &"TertiaryButton")


# --- Building blocks ----------------------------------------------------------------------

func label(parent: Node, text: String = "", variation: StringName = &"", wrap: bool = false) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.theme_type_variation = variation
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.custom_minimum_size.x = 8.0  # a wrapped label takes its width from the container
	parent.add_child(l)
	return l


## Button. Only the primary button takes focus, so Enter always means Continue / Retry.
func add_button(parent: Node, text: String, action: Callable, variation: StringName) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.theme_type_variation = variation
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.focus_mode = Control.FOCUS_ALL if variation == &"PrimaryButton" else Control.FOCUS_NONE
	b.pressed.connect(action)
	parent.add_child(b)
	return b


## A card with a section title; returns the card's content box.
func card(parent: Node, title: String = "", expand: bool = false) -> VBoxContainer:
	var c: PanelContainer = PanelContainer.new()
	c.theme_type_variation = &"Card"
	if expand:
		c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(c)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	c.add_child(box)
	if title != "":
		label(box, title, &"SectionLabel")
	return box


func hbox(parent: Node, expand: bool = false) -> HBoxContainer:
	var h: HBoxContainer = HBoxContainer.new()
	if expand:
		h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(h)
	return h


func vbox(parent: Node, expand_h: bool = false, separation: int = -1) -> VBoxContainer:
	var v: VBoxContainer = VBoxContainer.new()
	if expand_h:
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if separation >= 0:
		v.add_theme_constant_override("separation", separation)
	parent.add_child(v)
	return v


func spacer(parent: Node) -> Control:
	var s: Control = Control.new()
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(s)
	return s


## Removes a container's children right away (not queue_free: the old rows must not stay in
## the container until the end of the frame - that made the old report grow on wave 2).
static func clear(container: Node) -> void:
	for child: Node in container.get_children():
		container.remove_child(child)
		child.queue_free()


## Up / down / same pill for a change, e.g. "+0.4".
func delta_pill(parent: Node, text: String, delta: float, notable: bool) -> PanelContainer:
	var p: PanelContainer = PanelContainer.new()
	p.theme_type_variation = &"SamePill" if not notable else (&"UpPill" if delta > 0.0 else &"DownPill")
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.size_flags_horizontal = Control.SIZE_SHRINK_END
	label(p, text if notable else "same", &"UpLabel" if notable else &"SmallLabel")
	parent.add_child(p)
	return p

class_name ThreatIndicators
extends Control
## Screen-edge arrows (Reactive Survival V1) for things that matter but are off screen:
##   yellow / red   an enemy growing suspicious of the player (red = it sees you)
##   gold           the Escort survivor (blinks red while it is down or being hit)
## Enemies on screen show their own view cone and "?" / "!" marker (Enemy._draw_senses).

const EDGE: float = 10.0
const MIN_SUSPICION: float = 0.25

var wave_manager: WaveManager
var escort: EscortObjective


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var to_screen: Transform2D = get_viewport().get_canvas_transform()
	var rect: Rect2 = Rect2(Vector2.ZERO, get_viewport_rect().size)
	if wave_manager != null:
		for e: Enemy in wave_manager.alive:
			var s: float = e.awareness.suspicion
			if s < MIN_SUSPICION:
				continue
			var color: Color = Color(1, 0.2, 0.2) if e.awareness.state == Awareness.State.CHASE \
					else Color(1, 0.9, 0.2, 0.5 + 0.5 * s)
			_arrow(to_screen * e.global_position, rect, color)
	if escort != null and escort.state == Objective.State.ACTIVE:
		var warn: bool = escort.scared or escort.hunters() > 0
		var blink: bool = warn and int(Time.get_ticks_msec() / 250) % 2 == 0
		_arrow(to_screen * escort.survivor, rect, Color(1, 0.3, 0.3) if blink else Color(1.0, 0.85, 0.3))


## Draws a small triangle on the screen edge pointing at `point`, if it is off screen.
func _arrow(point: Vector2, rect: Rect2, color: Color) -> void:
	if rect.grow(-2.0).has_point(point):
		return
	var centre: Vector2 = rect.get_center()
	var dir: Vector2 = (point - centre).normalized()
	if dir == Vector2.ZERO:
		return
	var inner: Rect2 = rect.grow(-EDGE)
	# Scale the centre->point ray until it touches the inner rectangle.
	var tx: float = (inner.size.x * 0.5) / absf(dir.x) if dir.x != 0.0 else INF
	var ty: float = (inner.size.y * 0.5) / absf(dir.y) if dir.y != 0.0 else INF
	var tip: Vector2 = centre + dir * minf(tx, ty)
	var side: Vector2 = dir.orthogonal() * 4.0
	var back: Vector2 = tip - dir * 7.0
	draw_colored_polygon(PackedVector2Array([tip, back + side, back - side]), color)

extends GutTest
## Tests for FlankPlanner: picking a usable spot beside / behind the player.

var _s: UtilitySettings


func before_each() -> void:
	_s = UtilitySettings.new()  # 40 px away, 120 degrees from facing


## 15x15 grid, player in the centre tile (7,7) = (120,120). `walls` are blocked cells.
func _field(walls: Array[Vector2i] = []) -> FlowField:
	var rules: TerrainCosts = TerrainCosts.new()
	rules.costs = {"road": 1.0}
	rules.impassable = PackedStringArray(["wall"])
	var rows: Array[PackedStringArray] = []
	for y: int in 15:
		var row: PackedStringArray = PackedStringArray()
		for x: int in 15:
			row.append("wall" if walls.has(Vector2i(x, y)) else "road")
		rows.append(row)
	var field: FlowField = FlowField.new(TerrainGrid.from_rows(rows, rules))
	field.build(Vector2i(7, 7))
	return field


func test_flank_point_is_behind_the_players_facing() -> void:
	var player: Vector2 = Vector2(120, 120)
	var p: Vector2 = FlankPlanner.choose(player, Vector2.RIGHT, Vector2(120, 60), _field(), _s)
	assert_ne(p, Vector2.INF)
	assert_almost_eq(p.distance_to(player), 40.0, 0.01)
	assert_lt((p - player).normalized().dot(Vector2.RIGHT), -0.4, "on the far side from where the player looks")


func test_picks_the_side_nearer_the_enemy() -> void:
	var player: Vector2 = Vector2(120, 120)
	var above: Vector2 = FlankPlanner.choose(player, Vector2.RIGHT, Vector2(120, 40), _field(), _s)
	var below: Vector2 = FlankPlanner.choose(player, Vector2.RIGHT, Vector2(120, 200), _field(), _s)
	assert_lt(above.y, player.y)
	assert_gt(below.y, player.y)


func test_blocked_side_falls_back_to_the_other() -> void:
	# Wall around the upper flank point (player faces right -> upper point at about (100, 85)).
	var walls: Array[Vector2i] = []
	for x: int in range(4, 8):
		for y: int in range(3, 7):
			walls.append(Vector2i(x, y))
	var p: Vector2 = FlankPlanner.choose(Vector2(120, 120), Vector2.RIGHT, Vector2(120, 40), _field(walls), _s)
	assert_ne(p, Vector2.INF)
	assert_gt(p.y, 120.0, "had to use the lower side")


func test_no_usable_side_returns_inf() -> void:
	var walls: Array[Vector2i] = []
	for x: int in range(0, 7):
		for y: int in 15:
			walls.append(Vector2i(x, y))
	var p: Vector2 = FlankPlanner.choose(Vector2(120, 120), Vector2.RIGHT, Vector2(200, 120), _field(walls), _s)
	assert_eq(p, Vector2.INF)


func test_zero_facing_does_not_crash() -> void:
	var p: Vector2 = FlankPlanner.choose(Vector2(120, 120), Vector2.ZERO, Vector2(120, 40), _field(), _s)
	assert_ne(p, Vector2.INF)

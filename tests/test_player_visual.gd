extends GutTest
## PlayerVisual: direction maths, greybox fallback, sheet checks, and that the visual rework left
## the muzzle (bullet spawn point) exactly where it was.


func _player_in(holder: Node) -> Player:
	var p: Player = load("res://entities/player/player.tscn").instantiate()
	holder.add_child(p)
	return p


func _visual(p: Player) -> PlayerVisual:
	var v: PlayerVisual = p.get_node("Body") as PlayerVisual
	v.set_process(false)  # tests drive step() themselves
	return v


## Blank sheets of the right (or a wrong) size: only the layout is under test here, not art.
func _blank(sheet: StringName, size_override: Vector2i = Vector2i.ZERO) -> Texture2D:
	var size: Vector2i = size_override if size_override != Vector2i.ZERO else PlayerVisual.LAYOUT[sheet] * PlayerVisual.FRAME
	return ImageTexture.create_from_image(Image.create(size.x, size.y, false, Image.FORMAT_RGBA8))


func _settings_with(sheets: Array[StringName]) -> PlayerVisualSettings:
	var s: PlayerVisualSettings = (load("res://data/player_visual.tres") as PlayerVisualSettings).duplicate()
	for sheet: StringName in sheets:
		s.set(sheet, _blank(sheet))
	return s


# --- Direction maths ----------------------------------------------------------------------

func test_sector8_follows_the_sheet_row_order() -> void:
	assert_eq(PlayerVisual.sector8(0.0), 0, "E")
	assert_eq(PlayerVisual.sector8(PI / 4.0), 1, "SE")
	assert_eq(PlayerVisual.sector8(PI / 2.0), 2, "S")
	assert_eq(PlayerVisual.sector8(PI), 4, "W")
	assert_eq(PlayerVisual.sector8(-PI), 4, "W from the other side")
	assert_eq(PlayerVisual.sector8(-PI / 2.0), 6, "N")
	assert_eq(PlayerVisual.sector8(-PI / 4.0), 7, "NE")
	assert_eq(PlayerVisual.sector8(deg_to_rad(22.0)), 0)
	assert_eq(PlayerVisual.sector8(deg_to_rad(23.0)), 1)


func test_sector4_for_the_death_sheet() -> void:
	assert_eq(PlayerVisual.sector4(0.0), 0, "E")
	assert_eq(PlayerVisual.sector4(PI / 2.0), 1, "S")
	assert_eq(PlayerVisual.sector4(PI), 2, "W")
	assert_eq(PlayerVisual.sector4(-PI / 2.0), 3, "N")


func test_every_aim_uses_a_gun_arm_row_inside_its_torso_sector() -> void:
	for i: int in 720:
		var angle: float = deg_to_rad(i * 0.5 - 180.0)
		var row: int = PlayerVisual.arm_row(angle)
		var drawn: float = deg_to_rad(11.25 + 22.5 * row)
		assert_eq(PlayerVisual.sector8(drawn), PlayerVisual.sector8(angle), "aim %.1f deg" % rad_to_deg(angle))
		assert_lte(absf(angle_difference(drawn, angle)), deg_to_rad(11.25) + 0.0001, "within half a slice")


func test_gun_arm_goes_behind_him_aiming_west_through_north() -> void:
	var front: Array[int] = []
	for row: int in PlayerVisual.ARM_ANGLES:
		if PlayerVisual.arm_in_front(row):
			front.append(row)
	assert_eq(front, [0, 1, 2, 3, 4, 5, 14, 15])


func test_legs_face_the_walk_or_walk_backwards() -> void:
	assert_eq(PlayerVisual.leg_row(0.0, 0.0), Vector2i(0, 1), "walking where he aims")
	assert_eq(PlayerVisual.leg_row(PI / 2.0, 0.0), Vector2i(2, 1), "strafing: legs face the walk")
	assert_eq(PlayerVisual.leg_row(PI, 0.0), Vector2i(0, -1), "backing away: legs face the aim, stride reversed")
	assert_eq(PlayerVisual.leg_row(deg_to_rad(135.0), 0.0), Vector2i(7, -1))


func test_walk_frame_is_tied_to_distance() -> void:
	assert_eq(PlayerVisual.walk_frame(0.0, 28.0, 6), 0)
	assert_eq(PlayerVisual.walk_frame(14.0, 28.0, 6), 3, "half a stride")
	assert_eq(PlayerVisual.walk_frame(28.0, 28.0, 6), 0, "one full stride loops")
	assert_eq(PlayerVisual.walk_frame(-1.0, 28.0, 6), 5, "backwards runs the loop in reverse")


# --- Rig in the player scene ---------------------------------------------------------------

func test_muzzle_spawn_point_is_unchanged_at_any_aim() -> void:
	var holder: Node2D = Node2D.new()
	add_child_autofree(holder)
	var p: Player = _player_in(holder)
	p.global_position = Vector2(100, 50)
	await wait_physics_frames(1)
	for i: int in 16:
		var angle: float = TAU * i / 16.0 + 0.1
		p._aim_pivot.rotation = angle
		assert_almost_eq(p._muzzle.global_position, Vector2(100, 50) + Vector2(11, 0).rotated(angle), Vector2(0.001, 0.001))
	p._aim()
	assert_almost_eq(p._aim_pivot.rotation, p.aim_direction.angle(), 0.0001, "_aim turns the pivot")
	assert_eq(p.get_node("Body").rotation, 0.0, "the visual stays upright")


func test_a_shot_spawns_at_the_muzzle_and_signals_once() -> void:
	var holder: Node2D = Node2D.new()
	add_child_autofree(holder)
	var p: Player = _player_in(holder)
	await wait_physics_frames(1)
	p.global_position = Vector2.ZERO
	p.aim_direction = Vector2.DOWN
	p._aim_pivot.rotation = Vector2.DOWN.angle()
	p._cooldown_left = 0.0
	p.weapon.automatic = true  # hold-to-fire, so the test needs no input frame
	watch_signals(p)
	Input.action_press("shoot")
	p._shoot(0.0)
	Input.action_release("shoot")
	assert_signal_emit_count(p, "shot_fired", 1)
	var spawned: Array[Vector2] = []
	for c: Node in holder.get_children():
		if c is Bullet:
			spawned.append((c as Bullet).global_position)
	assert_eq(spawned.size(), 1)
	assert_almost_eq(spawned[0], Vector2(0, 11), Vector2(0.001, 0.001))


func test_without_art_the_greybox_shows_and_turns_to_the_aim() -> void:
	var holder: Node2D = Node2D.new()
	add_child_autofree(holder)
	var p: Player = _player_in(holder)
	await wait_physics_frames(1)
	var v: PlayerVisual = _visual(p)
	var s: PlayerVisualSettings = v.settings.duplicate()
	s.simple_poses = null  # no simple look either -> greybox
	v.settings = s
	v.reload_art()
	assert_false(v.has_art(), "data/player_visual.tres has no layered sheets yet")
	assert_false(v.has_simple_art())
	p.aim_direction = Vector2.UP
	v.step(0.016)
	var greybox: Node2D = p.get_node("Body/Greybox")
	assert_true(greybox.visible)
	assert_almost_eq(greybox.rotation, -PI / 2.0, 0.0001)


func test_hit_flash_and_death_grey_still_tint_the_body() -> void:
	var holder: Node2D = Node2D.new()
	add_child_autofree(holder)
	var p: Player = _player_in(holder)
	await wait_physics_frames(1)
	p.take_damage(10.0)
	assert_eq(p.get_node("Body").modulate, Color(1.0, 0.3, 0.3))
	p.take_damage(1000.0)
	assert_true(p.is_dead)
	assert_eq(p.get_node("Body").modulate, Color(0.4, 0.4, 0.4, 0.6))
	p.revive()
	assert_eq(p.get_node("Body").modulate, Color.WHITE)


func test_required_sheets_switch_to_layered_art() -> void:
	var holder: Node2D = Node2D.new()
	add_child_autofree(holder)
	var p: Player = _player_in(holder)
	await wait_physics_frames(1)
	var v: PlayerVisual = _visual(p)
	v.settings = _settings_with(PlayerVisual.REQUIRED)
	v.reload_art()
	assert_true(v.has_art())
	p.aim_direction = Vector2.from_angle(deg_to_rad(100.0))  # arm row 4, torso S, in front
	p.velocity = Vector2.ZERO
	v.step(0.016)
	assert_false(p.get_node("Body/Greybox").visible)
	var arm: Sprite2D = p.get_node("Body/GunArm/Arm")
	var torso: Sprite2D = p.get_node("Body/Torso")
	var legs: Sprite2D = p.get_node("Body/Legs")
	assert_true(arm.visible and torso.visible and legs.visible)
	assert_eq(arm.frame, 4 * 4, "row 4, rest frame")
	assert_eq(torso.frame / 4, 2, "torso row S")
	assert_gt(p.get_node("Body/GunArm").get_index(), torso.get_index(), "arm in front when aiming south")
	assert_eq(legs.offset, -PlayerVisual.PIVOT, "feet on the player's origin")
	assert_eq(legs.scale, Vector2(0.5, 0.5))
	p.shot_fired.emit()
	v.step(0.05)
	assert_eq(arm.frame, 4 * 4 + 2, "recoil plays after a shot")
	v.step(0.2)
	assert_eq(arm.frame, 4 * 4, "back to rest")
	p.aim_direction = Vector2.UP
	v.step(0.016)
	assert_lt(p.get_node("Body/GunArm").get_index(), torso.get_index(), "arm behind him aiming north")


func test_walking_advances_the_stride_with_distance() -> void:
	var holder: Node2D = Node2D.new()
	add_child_autofree(holder)
	var p: Player = _player_in(holder)
	await wait_physics_frames(1)
	var v: PlayerVisual = _visual(p)
	v.settings = _settings_with(PlayerVisual.REQUIRED)
	v.reload_art()
	p.aim_direction = Vector2.RIGHT
	p.velocity = Vector2(90, 0)
	var legs: Sprite2D = p.get_node("Body/Legs")
	v.step(0.0)
	assert_eq(legs.frame, 0, "row E, frame 0")
	v.step(14.0 / 90.0)  # half a 28 px stride
	assert_eq(legs.frame, 3)


func test_a_wrong_sized_sheet_is_ignored_and_the_greybox_stays() -> void:
	var holder: Node2D = Node2D.new()
	add_child_autofree(holder)
	var p: Player = _player_in(holder)
	await wait_physics_frames(1)
	var v: PlayerVisual = _visual(p)
	var s: PlayerVisualSettings = _settings_with(PlayerVisual.REQUIRED)
	s.gunarm = _blank(&"gunarm", Vector2i(320, 320))
	s.simple_poses = null
	v.settings = s
	v.reload_art()
	assert_false(v.has_art())
	assert_true(p.get_node("Body/Greybox").visible)


func test_layout_matches_the_art_spec() -> void:
	# Mirrors art_src/forsaken_scientist/scripts/spec.py; a change there must change both.
	assert_eq(PlayerVisual.LAYOUT.size(), 13)
	assert_eq(PlayerVisual.LAYOUT[&"gunarm"], Vector2i(4, 16))
	assert_eq(PlayerVisual.LAYOUT[&"legs_walk"], Vector2i(6, 8))
	assert_eq(PlayerVisual.LAYOUT[&"death"], Vector2i(8, 4))
	var s: PlayerVisualSettings = PlayerVisualSettings.new()
	for sheet: StringName in PlayerVisual.LAYOUT:
		assert_true(sheet in s, "settings has a slot for %s" % sheet)


# --- Simple static-pose look (deadline) ------------------------------------------------------

func test_data_uses_the_simple_look_until_the_layered_art_exists() -> void:
	var holder: Node2D = Node2D.new()
	add_child_autofree(holder)
	var p: Player = _player_in(holder)
	await wait_physics_frames(1)
	var v: PlayerVisual = _visual(p)
	assert_false(v.has_art())
	assert_true(v.has_simple_art(), "data/player_visual.tres sets simple_poses")
	assert_false(p.get_node("Body/Greybox").visible)
	var pose: Sprite2D = p.get_node("Body/Simple/Pose")
	assert_eq(pose.texture.get_size(), Vector2(320, 80), "4 poses of 80x80")
	assert_eq(pose.offset, -PlayerVisual.PIVOT, "feet on the player's origin")
	for case: Array in [[Vector2.RIGHT, 0], [Vector2.DOWN, 1], [Vector2.LEFT, 2], [Vector2.UP, 3]]:
		p.aim_direction = case[0]
		v.step(0.016)
		assert_eq(pose.frame, case[1], "pose for aim %s" % case[0])


func test_simple_look_kicks_and_flashes_on_a_shot_then_settles() -> void:
	var holder: Node2D = Node2D.new()
	add_child_autofree(holder)
	var p: Player = _player_in(holder)
	await wait_physics_frames(1)
	var v: PlayerVisual = _visual(p)
	p.aim_direction = Vector2.RIGHT
	p.velocity = Vector2.ZERO
	var pose: Sprite2D = p.get_node("Body/Simple/Pose")
	var flash: Sprite2D = p.get_node("Body/Simple/MuzzleFlash")
	p.shot_fired.emit()
	v.step(0.0)
	assert_true(flash.visible)
	assert_almost_eq(flash.global_position, p.get_node("AimPivot/Muzzle").global_position, Vector2(0.01, 0.01), "flash at the real muzzle")
	assert_lt(pose.position.x, 0.0, "recoil kicks back, away from the aim")
	for i: int in 20:
		v.step(0.02)
	assert_false(flash.visible)
	assert_eq(pose.position.x, 0.0, "recoil settled")


func test_simple_look_falls_over_on_death_and_stands_on_revive() -> void:
	var holder: Node2D = Node2D.new()
	add_child_autofree(holder)
	var p: Player = _player_in(holder)
	await wait_physics_frames(1)
	var v: PlayerVisual = _visual(p)
	var pose: Sprite2D = p.get_node("Body/Simple/Pose")
	p.take_damage(1000.0)
	for i: int in 30:
		v.step(0.02)
	assert_almost_eq(absf(pose.rotation), PI / 2.0, 0.01)
	p.revive()
	for i: int in 30:
		v.step(0.02)
	assert_almost_eq(pose.rotation, 0.0, 0.01)

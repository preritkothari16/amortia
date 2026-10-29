extends GutTest
## Bottom HUD strip (steps 67-71): compact layout that never overlaps, no minimap, no portrait, the
## player panel reads live Player data, and the camera frames the player in the middle of the view the
## strip leaves free.

const STRIP: Rect2 = Rect2(0, 0, 480, HudLayout.STRIP_HEIGHT)


# --- Layout ----------------------------------------------------------------------------

func test_boxes_fit_the_strip_and_never_overlap() -> void:
	var boxes: Array[Rect2] = HudLayout.boxes()
	for i: int in boxes.size():
		assert_true(STRIP.encloses(boxes[i]), "%s inside the strip" % boxes[i])
		for j: int in range(i + 1, boxes.size()):
			assert_false(boxes[i].intersects(boxes[j]), "%s overlaps %s" % [boxes[i], boxes[j]])


func test_left_and_centre_groups_stay_left_of_the_text_column() -> void:
	for box: Rect2 in HudLayout.boxes():
		assert_lt(box.end.x, HudLayout.RIGHT_X, "%s left of the wave / objective column" % box)
	for x: float in HudLayout.DIVIDERS:
		for box: Rect2 in HudLayout.boxes():
			assert_false(box.position.x <= x and x < box.end.x, "divider %d crosses %s" % [x, box])
	assert_lt(HudLayout.RIGHT_X + 40.0, HudLayout.CHECK_X, "wave block left of the checklist")
	assert_gt(HudLayout.check_text_width(480.0), 110.0, "room for normal objective lines")
	for baseline: float in HudLayout.CHECK_BASELINE:
		assert_lte(baseline + 2.0, HudLayout.STRIP_HEIGHT, "descenders stay on the plate")


func test_strip_is_compact() -> void:
	assert_lte(HudLayout.STRIP_HEIGHT, 28.0, "at most 28 of 270 px (about 10 %)")


func test_no_portrait_anywhere_in_the_hud() -> void:
	assert_false(ResourceLoader.exists("res://ui/hud/art/hud_portrait.png"), "portrait art removed")
	var source: String = (load("res://ui/hud/player_status.gd") as GDScript).source_code
	assert_false(source.containsn("portrait"), "no portrait code left in the status panel")


func test_camera_frames_the_player_above_the_strip() -> void:
	var main: Node = load("res://world/main.tscn").instantiate()
	main.autosave = false
	main.get_node("WaveManager").log_waves = false
	add_child_autofree(main)
	await wait_physics_frames(2)
	assert_null(main.get_node_or_null("HUD/Minimap"), "no minimap")
	var cam: Camera2D = main.get_node("Player/Camera2D")
	assert_eq(cam.position, Vector2(0, HudLayout.STRIP_HEIGHT * 0.5), "player centred in the uncovered view")
	assert_eq(cam.offset, Vector2.ZERO, "offset stays free for the hit shake")
	var bounds: Rect2 = main.current_map().get_world_rect()
	assert_eq(cam.limit_bottom, int(bounds.end.y + HudLayout.STRIP_HEIGHT), "bottom rows can scroll above the strip")


# --- Player panel ----------------------------------------------------------------------

func _status_with_player() -> PlayerStatus:
	var p: Player = load("res://entities/player/player.tscn").instantiate()
	add_child_autofree(p)
	var status: PlayerStatus = PlayerStatus.new()
	add_child_autofree(status)
	status.player = p
	return status


func test_dodge_bar_text_follows_the_cooldown() -> void:
	var status: PlayerStatus = _status_with_player()
	assert_eq(status.dodge_text(), "RDY")
	status.player._try_dodge(Vector2.RIGHT)
	assert_true(status.dodge_text().ends_with("s"), "seconds while cooling down")


func test_low_health_threshold_comes_from_data() -> void:
	var status: PlayerStatus = _status_with_player()
	var p: Player = status.player
	assert_false(status.is_low_health())
	p.health = p.stats.max_health * status.settings.low_health_ratio
	assert_true(status.is_low_health())
	p.health = 0.0
	assert_false(status.is_low_health(), "0 HP is dead, not low")


func test_spare_weapon_is_the_other_carried_one() -> void:
	var status: PlayerStatus = _status_with_player()
	assert_eq(status.spare_weapon_id(), &"", "pistol only")
	var l: PlayerLoadout = PlayerLoadout.new()
	l.owned = [&"pistol", &"shotgun"]
	l.equipped = [&"pistol", &"shotgun"]
	status.player.apply_loadout(l)
	assert_eq(status.spare_weapon_id(), &"shotgun")
	status.player.swap_weapon()
	assert_eq(status.spare_weapon_id(), &"pistol")


func test_hidden_chip_follows_concealment_and_needs_no_portrait() -> void:
	var status: PlayerStatus = _status_with_player()
	assert_true(HudLayout.HIDDEN_CHIP.position.x < HudLayout.DIVIDERS[0], "chip sits in the player status group")
	assert_true(Rect2(0, 0, 480, HudLayout.STRIP_HEIGHT).encloses(HudLayout.HIDDEN_CHIP))
	assert_false(status.player.is_concealed(), "no grid: never concealed, chip hidden")


func test_power_up_slot_shows_shield_first_then_longest_power_up() -> void:
	var status: PlayerStatus = _status_with_player()
	var p: Player = status.player
	assert_true(status.active_boost().is_empty())
	var none: Array[StatModifier] = []
	p.modifiers.add_temporary(&"haste", none, 4.0)
	p.modifiers.add_temporary(&"rapid", none, 9.0)
	var boost: Dictionary = status.active_boost()
	assert_eq(boost["id"], &"rapid")
	assert_eq(boost["text"], "9s")
	assert_eq(boost["more"], 1)
	p.add_shield(30.0, 5.0)
	boost = status.active_boost()
	assert_eq(boost["id"], &"shield")
	assert_eq(boost["more"], 2)

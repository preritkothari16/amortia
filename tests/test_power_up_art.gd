extends GutTest
## Power-up icons (step 72): every power-up in the data has a 9 x 9 HUD icon and a 15 x 15 pickup
## token, each icon has its own silhouette (readable without colour), pickups draw the token instead
## of a letter, and the HUD lists every running effect with its real time left.

var _set: PowerUpSet = load("res://data/power_up_set.tres")


func test_every_power_up_has_an_icon_and_a_token_of_the_right_size() -> void:
	for t: PowerUpType in _set.types:
		var icon: Texture2D = PowerUpArt.icon(t.id)
		var token: Texture2D = PowerUpArt.token(t.id)
		assert_not_null(icon, "%s icon" % t.id)
		assert_not_null(token, "%s token" % t.id)
		assert_eq(Vector2i(icon.get_size()), Vector2i(PowerUpArt.ICON_SIZE, PowerUpArt.ICON_SIZE), "%s icon size" % t.id)
		assert_eq(Vector2i(token.get_size()), Vector2i(PowerUpArt.TOKEN_SIZE, PowerUpArt.TOKEN_SIZE), "%s token size" % t.id)


func test_icons_have_distinct_silhouettes() -> void:
	# Compare the shapes only (which pixels are drawn), not the colours.
	var masks: Dictionary = {}
	for t: PowerUpType in _set.types:
		var img: Image = PowerUpArt.icon(t.id).get_image()
		var mask: PackedByteArray = PackedByteArray()
		for y: int in img.get_height():
			for x: int in img.get_width():
				mask.append(1 if img.get_pixel(x, y).a > 0.5 else 0)
		masks[t.id] = mask
	var ids: Array = masks.keys()
	for i: int in ids.size():
		for j: int in range(i + 1, ids.size()):
			var a: PackedByteArray = masks[ids[i]]
			var b: PackedByteArray = masks[ids[j]]
			var differ: int = 0
			for k: int in a.size():
				if a[k] != b[k]:
					differ += 1
			assert_gte(differ, 12, "%s and %s differ by %d px" % [ids[i], ids[j], differ])


func test_pickup_draws_the_token_not_a_letter() -> void:
	var pickup: PowerUpPickup = PowerUpPickup.create(_set.get_type(&"haste"), null, Vector2.ZERO, 20.0)
	add_child_autofree(pickup)
	await wait_process_frames(1)
	assert_eq(pickup.find_children("*", "Label", true, false).size(), 0, "no letter label any more")
	assert_eq(PowerUpPickup._ring_pixels().size() > 20, true, "pulsing outline ring")


func test_hud_lists_every_running_effect_shield_first() -> void:
	var p: Player = load("res://entities/player/player.tscn").instantiate()
	add_child_autofree(p)
	var status: PlayerStatus = PlayerStatus.new()
	add_child_autofree(status)
	status.player = p
	assert_eq(status.active_effects().size(), 0, "nothing running: the cell stays empty")
	var none: Array[StatModifier] = []
	p.modifiers.add_temporary(&"haste", none, 4.0)
	p.modifiers.add_temporary(&"damage", none, 9.0)
	p.add_shield(25.0, 6.0)
	var effects: Array[Dictionary] = status.active_effects()
	assert_eq(effects.map(func(e: Dictionary) -> StringName: return e["id"]), [&"shield", &"damage", &"haste"])
	assert_almost_eq(float(effects[1]["left"]), 9.0, 0.01, "real time left")
	assert_almost_eq(float(effects[1]["total"]), minf(_set.get_type(&"damage").duration, _set.max_duration), 0.01)
	assert_eq(effects[0]["text"], "25", "shield points")

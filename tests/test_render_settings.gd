extends GutTest
## Render settings the 2x-density player art depends on (see HANDOFF step 61). The game is laid out
## in a 480 x 270 viewport (world framing, HUD, menus) but drawn at the window's integer multiple
## (canvas_items), so an 80x80 frame at scale 0.5 keeps every art pixel (2x2 at 1080p, 1:1 at 720p).


func test_layout_is_still_480_by_270_with_integer_scaling() -> void:
	assert_eq(ProjectSettings.get_setting("display/window/size/viewport_width"), 480)
	assert_eq(ProjectSettings.get_setting("display/window/size/viewport_height"), 270)
	assert_eq(ProjectSettings.get_setting("display/window/stretch/scale_mode"), "integer")
	assert_eq(ProjectSettings.get_setting("display/window/stretch/scale", 1.0), 1.0,
		"stretch/scale > 1 in viewport-style scaling would shrink the render, not sharpen it")


func test_drawn_at_window_resolution_not_at_480_by_270() -> void:
	assert_eq(ProjectSettings.get_setting("display/window/stretch/mode"), "canvas_items",
		"viewport mode renders 480 x 270 and drops 3 of every 4 art pixels")


func test_text_keeps_its_pixel_look() -> void:
	assert_false(ProjectSettings.get_setting("gui/fonts/dynamic_fonts/use_oversampling"),
		"oversampling would re-rasterise HUD text at screen resolution (different look)")


func test_textures_use_nearest_filtering() -> void:
	assert_eq(ProjectSettings.get_setting("rendering/textures/canvas_textures/default_texture_filter"), 0)


func test_camera_is_unzoomed() -> void:
	var p: Node = load("res://entities/player/player.tscn").instantiate()
	var cam: Camera2D = p.get_node("Camera2D")
	assert_eq(cam.zoom, Vector2.ONE, "world framing stays 480 x 270 world px")
	assert_true(cam.position_smoothing_enabled)
	assert_eq(cam.position_smoothing_speed, 8.0)
	p.free()


func test_apex_boss_gets_a_halo_aura_and_always_on_health_bar() -> void:
	var enemy: Enemy = (load("res://entities/enemies/base_enemy.tscn") as PackedScene).instantiate() as Enemy
	enemy.stats = load("res://data/runner.tres") as EnemyStats
	add_child_autofree(enemy)
	await wait_physics_frames(2)
	enemy.make_boss(12.0, 2.0, 2.0)
	await wait_physics_frames(3)
	var body: Node = enemy.get_node("Body")
	assert_not_null(body.get_node_or_null("BossAura"), "ground ring under the boss")
	assert_not_null(body.get_node_or_null("BossHalo"), "magenta silhouette behind the sprite")
	assert_true(enemy.is_boss)

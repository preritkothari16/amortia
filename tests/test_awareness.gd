extends GutTest
## Tests for Awareness: what an enemy knows, and that it never gets live updates without sight.


func test_starts_idle_with_no_knowledge() -> void:
	var a: Awareness = Awareness.new()
	assert_eq(a.state, Awareness.State.IDLE)
	assert_eq(a.last_known, Vector2.INF)


func test_seeing_gives_chase_and_live_position() -> void:
	var a: Awareness = Awareness.new()
	a.see(Vector2(10, 10))
	assert_eq(a.state, Awareness.State.CHASE)
	a.see(Vector2(20, 10))
	assert_eq(a.last_known, Vector2(20, 10), "updates every frame while visible")


func test_losing_sight_keeps_last_seen_position() -> void:
	var a: Awareness = Awareness.new()
	a.see(Vector2(20, 10))
	a.lose_sight()
	assert_eq(a.state, Awareness.State.INVESTIGATE)
	assert_eq(a.last_known, Vector2(20, 10), "where it was last SEEN, not where it is now")
	a.lose_sight()
	assert_eq(a.last_known, Vector2(20, 10), "no further updates without sight")


func test_hearing_sets_investigation_target() -> void:
	var a: Awareness = Awareness.new()
	var v: int = a.target_version
	a.hear(Vector2(5, 5))
	assert_eq(a.state, Awareness.State.INVESTIGATE)
	assert_eq(a.last_known, Vector2(5, 5))
	assert_gt(a.target_version, v, "new target -> plan a new path")


func test_newer_noise_replaces_older() -> void:
	var a: Awareness = Awareness.new()
	a.hear(Vector2(5, 5))
	var v: int = a.target_version
	a.hear(Vector2(50, 5))
	assert_eq(a.last_known, Vector2(50, 5))
	assert_gt(a.target_version, v)


func test_noise_ignored_while_chasing() -> void:
	var a: Awareness = Awareness.new()
	a.see(Vector2(1, 1))
	a.hear(Vector2(99, 99))
	assert_eq(a.state, Awareness.State.CHASE)
	assert_eq(a.last_known, Vector2(1, 1))


func test_arrive_search_then_idle() -> void:
	var a: Awareness = Awareness.new()
	a.hear(Vector2(5, 5))
	a.arrive(2.0)
	assert_eq(a.state, Awareness.State.SEARCH)
	a.tick(1.5)
	assert_eq(a.state, Awareness.State.SEARCH)
	a.tick(0.6)
	assert_eq(a.state, Awareness.State.IDLE)
	assert_eq(a.last_known, Vector2(5, 5), "memory kept for later")


func test_noise_during_search_restarts_investigation() -> void:
	var a: Awareness = Awareness.new()
	a.hear(Vector2(5, 5))
	a.arrive(2.0)
	a.hear(Vector2(40, 40))
	assert_eq(a.state, Awareness.State.INVESTIGATE)


func test_seeing_interrupts_search() -> void:
	var a: Awareness = Awareness.new()
	a.hear(Vector2(5, 5))
	a.arrive(2.0)
	a.see(Vector2(7, 7))
	assert_eq(a.state, Awareness.State.CHASE)


func test_arrive_only_from_investigate() -> void:
	var a: Awareness = Awareness.new()
	a.arrive(2.0)
	assert_eq(a.state, Awareness.State.IDLE)
	a.see(Vector2.ONE)
	a.arrive(2.0)
	assert_eq(a.state, Awareness.State.CHASE)


func test_lead_age_and_has_lead() -> void:
	var a: Awareness = Awareness.new()
	assert_false(a.has_lead())
	a.hear(Vector2(5, 5))
	assert_true(a.has_lead())
	a.tick(1.5)
	assert_almost_eq(a.lead_age, 1.5, 0.0001)
	a.hear(Vector2(6, 6))
	assert_eq(a.lead_age, 0.0, "new information is fresh")
	a.arrive(2.0)
	assert_false(a.has_lead(), "checked leads are not leads any more")
	a.see(Vector2.ONE)
	assert_false(a.has_lead(), "seeing is better than a lead")

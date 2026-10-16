extends GutTest
## Player progression redesign: enemy budgets per zone (option C), and (added phase by phase below)
## weapons, research, resources, power-ups. Permanent research, weapon equipment and temporary
## effects are separate layers.

var _rules: GenomeRules


func before_each() -> void:
	_rules = load("res://data/genome_rules.tres")


# --- Enemy stat budget per zone (option C) ---------------------------------------------------

func test_zone_budgets_start_20_23_26_29_and_grow_one_per_wave() -> void:
	var starts: Array[int] = [20, 23, 26, 29]
	for zone: int in 4:
		assert_eq(_rules.budget_for(zone + 1, 1), starts[zone], "zone %d first wave" % (zone + 1))
		assert_eq(_rules.budget_for(zone + 1, 2), mini(starts[zone] + 1, 32))


func test_budget_is_capped_at_32() -> void:
	assert_eq(_rules.budget_for(4, 5), 32, "29 + 4 = 33 -> capped")
	assert_eq(_rules.budget_for(4, 99), 32)
	assert_eq(_rules.budget_for(9, 1), 32)


func test_zone_one_is_exactly_the_old_ramp_and_budget_for_wave_is_unchanged() -> void:
	for wave: int in range(0, 40):
		assert_eq(_rules.budget_for_wave(wave), _rules.budget_for(1, wave))
	assert_eq(_rules.budget_for(1, 1), 20)
	assert_eq(_rules.budget_for(1, 13), 32, "the old 20 -> 32 ramp is preserved in zone 1")


func test_campaign_budget_table() -> void:
	var expect: Array = [[20, 21, 22, 23, 24], [23, 24, 25, 26, 27], [26, 27, 28, 29, 30], [29, 30, 31, 32, 32]]
	for zone: int in 4:
		for wave: int in 5:
			assert_eq(_rules.budget_for(zone + 1, wave + 1), expect[zone][wave], "zone %d wave %d" % [zone + 1, wave + 1])


func test_data_file_has_the_zone_step() -> void:
	assert_eq(_rules.budget_zone_step, 3)
	assert_eq(_rules.budget_start, 20)
	assert_eq(_rules.budget_max, 32)
	assert_eq(_rules.budget_per_wave, 1)


func test_wave_manager_breeds_for_its_zone() -> void:
	var main: Node = load("res://world/main.tscn").instantiate()
	main.autosave = false
	var wm: WaveManager = main.get_node("WaveManager")
	wm.log_waves = false
	wm.spawn_seed = 3
	wm.pause_between_waves = false
	wm.zone = 3
	add_child_autofree(main)
	await wait_physics_frames(2)
	wm.end_wave()  # scores wave 1 and breeds for wave 2 of zone 3
	for g: Genome in wm.population:
		assert_true(g.spends_budget(_rules, _rules.budget_for(3, 2)), "zone 3 wave 2 = 27")
	assert_eq(wm.history[-1]["budget"], 27)


func test_save_validation_uses_the_zones_budget() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 8
	var pop: Array = []
	for i: int in 20:
		pop.append(Genome.random(rng, _rules, 26).to_dict())  # zone 3 wave 1
	var evo: Dictionary = {"next_wave": 1, "generation": 0, "population": pop, "history": []}
	var warnings: PackedStringArray = PackedStringArray()
	var ok: Dictionary = SaveGame._validate_evolution(evo, _rules, warnings, 3)
	assert_false(ok.has("error"))
	assert_eq(warnings.size() - Array(warnings).filter(func(w: String) -> bool: return w.contains("missing or invalid")).size(), 0,
			"exactly the zone-3 budget: nothing repaired")
	var warnings2: PackedStringArray = PackedStringArray()
	SaveGame._validate_evolution(evo, _rules, warnings2, 1)
	assert_gt(Array(warnings2).filter(func(w: String) -> bool: return w.begins_with("genome")).size(), 0,
			"the same genomes are over zone 1's budget and get repaired")


func test_entering_a_new_zone_seeds_its_population_at_that_zones_budget() -> void:
	GameState.start_new_campaign()
	GameState.current_zone = 2
	GameState.zone_elite[2] = []
	GameState.enter_next_zone()  # -> zone 3
	assert_eq(GameState.current_zone, 3)
	for d: Dictionary in GameState.zone_evolution[3]["population"]:
		assert_true(Genome.from_dict(d).spends_budget(_rules, 26), "zone 3 starts at 26")
	GameState.start_new_campaign()

class_name WaveHud
extends Label
## Greybox HUD text for the evolution loop: wave, generation, enemies left, last fitness,
## the current population's average genes, and the countdown between waves.

var wave_manager: WaveManager


func _process(_delta: float) -> void:
	if wave_manager == null:
		return
	var wm: WaveManager = wave_manager
	var lines: PackedStringArray = PackedStringArray()
	var status: String = "%d / %d Runners left" % [wm.alive.size(), wm.population.size()]
	if wm.intermission_left >= 0.0:
		status = "next wave in %.1f s" % wm.intermission_left
	lines.append("Wave %d  |  Generation %d  |  %s" % [wm.wave_number, wm.generation, status])
	if not wm.history.is_empty():
		var last: Dictionary = wm.history[-1]
		lines.append("last wave fitness: best %.2f  mean %.2f" % [last["best_fitness"], last["mean_fitness"]])
	if not wm.population.is_empty() and wm.population[0] != null:
		var m: Dictionary = WaveManager.gene_means(wm.population)
		lines.append("avg genes  spd %.1f  hp %.1f  vis %.1f  |  agg %.2f  fla %.2f  pat %.2f" % [
			m["speed"], m["health"], m["vision"], m["aggression"], m["flanking"], m["patience"]])
	text = "\n".join(lines)

class_name SurviveObjective
extends Objective
## Survive (GDD 8.2): last the level's waves. A wave is done when all its enemies are dead -
## the WaveManager's normal rule - so this objective only reports progress.
## Objective fitness: none (O = 0); pure evolution pressure from D, P and S.


func hud_text() -> String:
	return "Survive" if state == State.ACTIVE else ""

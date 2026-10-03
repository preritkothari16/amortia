extends Node
## Global signal hub. Add a signal here only when more than one system listens to it.

## A noise happened at `pos` that enemies within `radius` pixels can hear.
signal noise_emitted(pos: Vector2, radius: float)

## An enemy was killed (not despawned). Listeners read what they need from it (e.g. its genome
## for XP). It is still valid during this signal; it frees at the end of the frame.
signal enemy_killed(enemy: Node2D)

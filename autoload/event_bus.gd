extends Node
## Global signal hub. Add a signal here only when more than one system listens to it.

## A noise happened at `pos` that enemies within `radius` pixels can hear.
signal noise_emitted(pos: Vector2, radius: float)

extends StaticBody2D
## Test target: a body bullets can hit; remembers the damage it took.

var taken: float = 0.0


func take_damage(amount: float) -> void:
	taken += amount

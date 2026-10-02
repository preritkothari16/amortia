extends Node2D
## Prototype level root: puts the player on the map's spawn and keeps the camera inside the map.

@onready var _map: ZoneMap = $MapleHollow
@onready var _player: Player = $Player


func _ready() -> void:
	_player.global_position = _map.get_player_spawn()
	var bounds: Rect2 = _map.get_world_rect()
	var camera: Camera2D = _player.get_node("Camera2D")
	camera.limit_left = int(bounds.position.x)
	camera.limit_top = int(bounds.position.y)
	camera.limit_right = int(bounds.end.x)
	camera.limit_bottom = int(bounds.end.y)
	camera.reset_smoothing()

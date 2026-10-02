class_name FlankPlanner
extends RefCounted
## Finds a flank point: a spot beside / behind the player, away from where they are looking.
## Two candidates, `flank_angle_degrees` either side of the player's facing direction, at
## `flank_point_distance`. A candidate counts only if it is standable and a short walk from
## the player (so not inside a house or behind a fence). The one nearer the enemy wins.


## The flank point for an enemy at `enemy_pos`, or Vector2.INF if neither side works.
static func choose(player_pos: Vector2, player_facing: Vector2, enemy_pos: Vector2,
		field: FlowField, settings: UtilitySettings) -> Vector2:
	var facing: Vector2 = player_facing.normalized() if player_facing.length() > 0.001 else Vector2.RIGHT
	var angle: float = deg_to_rad(settings.flank_angle_degrees)
	var best: Vector2 = Vector2.INF
	var best_dist: float = INF
	for side: float in [1.0, -1.0]:
		var point: Vector2 = player_pos + facing.rotated(angle * side) * settings.flank_point_distance
		if not is_usable(point, field, settings):
			continue
		var d: float = enemy_pos.distance_squared_to(point)
		if d < best_dist:
			best = point
			best_dist = d
	return best


static func is_usable(point: Vector2, field: FlowField, settings: UtilitySettings) -> bool:
	if not field.is_built():
		return false
	var cell: Vector2i = field.grid.coords.world_to_cell(point)
	return field.grid.get_cost(cell) <= settings.flank_max_tile_cost \
		and field.get_cost(cell) <= settings.flank_max_path_cost

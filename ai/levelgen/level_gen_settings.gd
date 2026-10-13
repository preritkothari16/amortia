class_name LevelGenSettings
extends Resource
## Settings for CspLevelGenerator (GDD 4.6). Edit data/levelgen/*.tres.

@export var library: RoomChunkLibrary
## Chunk slots across / down (4 x 2 = 64 x 32 tiles).
@export var columns: int = 4
@export var rows: int = 2
## Row of the entry slot (left column) and of the exit slot (right column). -1 = seeded pick.
@export var entry_row: int = -1
@export var exit_row: int = -1
## Enemy spawns must be at least this many tiles (straight line) from the player spawn.
@export var min_spawn_distance: float = 15.0
## A layout needs at least this many such spawns (reachable by enemies).
@export var min_spawns: int = 4
## No more than this many chokepoint chunks in a row (horizontal or vertical run).
@export var max_consecutive_chokepoints: int = 2
## At least one chunk with a hazard.
@export var require_hazard: bool = true
## Search budget: give up (clearly) after this many tried assignments.
@export var max_nodes: int = 20000

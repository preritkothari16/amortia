class_name RoomChunk
extends Resource
## One hand-made room chunk for the level generator (GDD 4.6): SIZE x SIZE tiles as layout
## characters (legend in RoomChunkLibrary), which edges have an exit, where enemies may spawn,
## and tags the CSP constraints need. Built by tools/build_chunks.gd.
##
## Exit convention: an edge is either solid except a 2-tile opening in its middle (cells 7 and
## 8 along the edge) - an exit - or completely solid. So two neighbouring chunks fit exactly
## when both have an exit on their shared edge or neither does.

const SIZE: int = 16
## Exit bits.
const N: int = 1
const E: int = 2
const S: int = 4
const W: int = 8

@export var id: String = ""
## SIZE strings of SIZE layout characters, row by row.
@export var cells: PackedStringArray = PackedStringArray()
## Bitmask of N / E / S / W exits.
@export var exits: int = 0
## Cells (in chunk coordinates) where an enemy may spawn.
@export var spawn_cells: Array[Vector2i] = []
## A narrow pass (counts for the "no more than two chokepoints in a row" rule).
@export var chokepoint: bool = false
## Contains a hazard (damaging terrain or deep water).
@export var hazard: bool = false


func has_exit(direction: int) -> bool:
	return exits & direction != 0


## Layout character at a chunk cell.
func char_at(cell: Vector2i) -> String:
	return cells[cell.y][cell.x]


## The two cells of an edge's opening, in chunk coordinates.
static func opening_cells(direction: int) -> Array[Vector2i]:
	match direction:
		N: return [Vector2i(7, 0), Vector2i(8, 0)]
		E: return [Vector2i(SIZE - 1, 7), Vector2i(SIZE - 1, 8)]
		S: return [Vector2i(7, SIZE - 1), Vector2i(8, SIZE - 1)]
		_: return [Vector2i(0, 7), Vector2i(0, 8)]

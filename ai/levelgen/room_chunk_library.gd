class_name RoomChunkLibrary
extends Resource
## The chunks one zone's levels are built from, plus the layout-character legend
## (data/chunks/*.tres, written by tools/build_chunks.gd).

@export var chunks: Array[RoomChunk] = []
## Layout character -> terrain name (TerrainDefinition.id).
@export var legend: Dictionary[String, String] = {}


func terrain_of(c: String) -> String:
	return legend.get(c, "")


func find(chunk_id: String) -> RoomChunk:
	for c: RoomChunk in chunks:
		if c.id == chunk_id:
			return c
	return null

extends Resource
class_name MapBlockData

@export_group("Quadrants (Top-Left, Top-Right...)")
@export var chunk_tl: MapChunkData
@export var chunk_tr: MapChunkData
@export var chunk_bl: MapChunkData
@export var chunk_br: MapChunkData

@export var weight: int = 10

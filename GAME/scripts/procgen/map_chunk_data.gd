extends Resource
class_name MapChunkData

## The scene file for this chunk (Must contain a TileMapLayer or similar)
@export var chunk_scene: PackedScene

## Size in grid chunks (1x1 = 20x20 tiles, 2x2 = 40x40 tiles)
@export var size_in_chunks: Vector2i = Vector2i(1, 1)

## Socket definitions
## Start simple with: "road", "building", "grass"
## Use "any" if it can connect to anything (rarely used for structure)
@export var socket_top: String = "road"
@export var socket_bottom: String = "road"
@export var socket_left: String = "building"
@export var socket_right: String = "building"

## Probability weight (higher = more likely to appear)
@export var weight: int = 10

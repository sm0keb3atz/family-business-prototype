@tool
extends Node2D
class_name ChunkBorderGuide

## Dimensions
@export var chunk_size_tiles: Vector2i = Vector2i(20, 20)
@export var tile_size: int = 48
@export var border_color: Color = Color.MAGENTA
@export var border_width: float = 4.0

func _process(_delta: float) -> void:
	# Redraw if properties change in editor
	queue_redraw()

func _draw() -> void:
	# Only draw in editor!
	if not Engine.is_editor_hint():
		return
		
	var pixel_size = Vector2(chunk_size_tiles) * float(tile_size)
	var rect = Rect2(Vector2.ZERO, pixel_size)
	
	# Draw main border
	draw_rect(rect, border_color, false, border_width)
	
	# Draw a crosshair center for help
	var center = pixel_size / 2.0
	draw_line(Vector2(center.x, 0), Vector2(center.x, pixel_size.y), border_color * 0.5, 2.0)
	draw_line(Vector2(0, center.y), Vector2(pixel_size.x, center.y), border_color * 0.5, 2.0)
	
	# Draw text label? (Optional, skip for simplicity)

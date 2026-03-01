@tool
extends Node2D

@export var radius: float = 200.0:
	set(v):
		radius = v
		queue_redraw()
		
@export var fill_color: Color = Color(1, 0, 0, 0.2):
	set(v):
		fill_color = v
		queue_redraw()

func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, fill_color)

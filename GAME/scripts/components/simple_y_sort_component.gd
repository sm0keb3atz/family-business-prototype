extends Node
class_name SimpleYSortComponent

@export var enabled: bool = true
## Multiplier for Y position to Z-index mapping. 
## Z-index max is 4096. Map size / multiplier must fit in +/- 4096.
## 0.1 means 10 pixels = 1 Z-level.
@export var z_index_multiplier: float = 1.0
@export var z_offset: int = 2000

@onready var parent: Node2D = get_parent() as Node2D

func _process(_delta: float) -> void:
	if not enabled or not parent:
		return
		
	# Simple mapping: Lower on screen (higher Y) = Higher Z index (drawn on top)
	var sort_value = int(parent.global_position.y * z_index_multiplier) + z_offset
	
	# Clamp to safe Godot limits (approx +/- 4096 for strict safety, though engine allows more)
	parent.z_index = clamp(sort_value, -4000, 4000)

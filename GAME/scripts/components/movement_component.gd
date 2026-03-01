extends Node
class_name MovementComponent

@export var parent_body: CharacterBody2D
var stats: CharacterStatsResource
var speed_multiplier: float = 1.0

func setup(p_stats: CharacterStatsResource) -> void:
	stats = p_stats

func move(direction: Vector2, is_sprinting: bool = false) -> void:
	if not parent_body or not stats:
		return
	
	var current_speed = stats.move_speed * speed_multiplier
	if is_sprinting and "sprint_speed" in stats:
		current_speed = stats.sprint_speed
		
	parent_body.velocity = direction * current_speed
	parent_body.move_and_slide()

func move_velocity(p_velocity: Vector2) -> void:
	if not parent_body:
		return
	parent_body.velocity = p_velocity
	parent_body.move_and_slide()

extends Node
class_name AnimationComponent

@export var animation_player: AnimationPlayer
@export var flip_root: Node2D

var last_direction: Vector2 = Vector2.DOWN

func update_animation(direction: Vector2) -> void:
	if not animation_player:
		return
	
	if direction.length() > 0.1:
		last_direction = direction
		
		# Adjust speed based on sprint input
		if Input.is_action_pressed("sprint"):
			animation_player.speed_scale = 1.5
		else:
			animation_player.speed_scale = 1.0
			
		if abs(direction.x) > abs(direction.y):
			animation_player.play("walk_side")
			if flip_root:
				flip_root.scale.x = -1.0 if direction.x < 0 else 1.0
		elif direction.y > 0:
			animation_player.play("walk_down")
		else:
			animation_player.play("walk_up")
	else:
		animation_player.speed_scale = 1.0
		# Play idle based on last direction
		if abs(last_direction.x) > abs(last_direction.y):
			animation_player.play("idle_side")
			if flip_root:
				flip_root.scale.x = -1.0 if last_direction.x < 0 else 1.0
		elif last_direction.y > 0:
			animation_player.play("idle_down")
		else:
			animation_player.play("idle_up")

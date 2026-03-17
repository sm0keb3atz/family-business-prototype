extends Node
class_name AnimationComponent

@export var animation_player: AnimationPlayer
@export var flip_root: Node2D

var last_direction: Vector2 = Vector2.DOWN

func update_animation(direction: Vector2) -> void:
	if not animation_player:
		return
	
	var anim_name = ""
	var is_moving = direction.length() > 0.1
	
	if is_moving:
		last_direction = direction
		
		# Dynamic Speed Scaling
		var parent = get_parent()
		if parent is CharacterBody2D:
			var current_vel = parent.velocity.length()
			var base_speed = 200.0 # Default fallback
			if "stats" in parent and parent.stats:
				base_speed = parent.stats.move_speed
			
			# Scale animation speed: 1.0 at base speed, higher when faster (sprinting)
			if base_speed > 0:
				animation_player.speed_scale = max(0.5, current_vel / base_speed)
			else:
				animation_player.speed_scale = 1.0
		else:
			animation_player.speed_scale = 1.0
			
		if abs(direction.x) > abs(direction.y):
			anim_name = "walk_side"
			if flip_root:
				flip_root.scale.x = -1.0 if direction.x < 0 else 1.0
		elif direction.y > 0:
			anim_name = "walk_down"
		else:
			anim_name = "walk_up"
	else:
		animation_player.speed_scale = 1.0
		# Play idle based on last direction
		if abs(last_direction.x) > abs(last_direction.y):
			anim_name = "idle_side"
			if flip_root:
				flip_root.scale.x = -1.0 if last_direction.x < 0 else 1.0
		elif last_direction.y > 0:
			anim_name = "idle_down"
		else:
			anim_name = "idle_up"
	
	if animation_player.current_animation != anim_name:
		animation_player.play(anim_name)

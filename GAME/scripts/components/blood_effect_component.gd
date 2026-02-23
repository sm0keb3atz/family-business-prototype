extends Node
class_name BloodEffectComponent

## Component that handles spawning and positioning blood splatter effects.

@export var blood_scene: PackedScene = preload("res://GAME/scenes/blood_fx.tscn")
@export var hurt_box: Area2D

func _ready() -> void:
	if not hurt_box:
		# Try to find HurtBox on parent if not assigned
		var parent = get_parent()
		if parent:
			hurt_box = parent.get_node_or_null("HurtBox")

## Spawns a blood effect at the calculated exit point of the capsule.
func spawn_blood(global_hit_pos: Vector2, hit_dir: Vector2) -> void:
	if not blood_scene:
		push_warning("BloodEffectComponent: blood_scene not assigned.")
		return
		
	var blood_fx = blood_scene.instantiate()
	
	# Refinement: Add to the level scene root so it doesn't move with the character
	var world = get_tree().current_scene
	world.add_child(blood_fx)
	
	# Calculate the position on the boundary of the HurtBox
	blood_fx.global_position = _calculate_exit_position(global_hit_pos, hit_dir)
	
	# Rotate to match the bullet direction
	if hit_dir != Vector2.ZERO:
		blood_fx.global_rotation = hit_dir.angle()
		# Flip vertically if firing left to keep textures consistent if they have orientation
		if hit_dir.x < 0:
			blood_fx.scale.y = -1
	
	# Ensure it's rendered below characters but above the map
	blood_fx.z_index = 0
	blood_fx.z_as_relative = false

func _calculate_exit_position(global_hit_pos: Vector2, hit_dir: Vector2) -> Vector2:
	if not hurt_box:
		return global_hit_pos
		
	var shape_node: CollisionShape2D = hurt_box.get_node_or_null("CollisionShape2D")
	if not shape_node or not shape_node.shape is CapsuleShape2D:
		return global_hit_pos
		
	var capsule: CapsuleShape2D = shape_node.shape
	var radius = capsule.radius
	var height = capsule.height
	var center = shape_node.global_position
	
	# If no direction, fallback to simple side-flipping
	if hit_dir == Vector2.ZERO:
		var local_hit_pos = global_hit_pos - center
		var exit_side = 1.0 if local_hit_pos.x < 0 else -1.0
		return center + Vector2(radius * exit_side, local_hit_pos.y)

	# Improved Exit Logic:
	# 1. Start from the character center.
	# 2. Project outward in the hit direction to find the point on the capsule boundary.
	# A capsule is a line segment Minkowski-summed with a circle.
	var half_straight = (height - (radius * 2.0)) / 2.0
	
	# Find the extreme point in the hit direction
	var cap_center_y = 0.0
	if hit_dir.y > 0.01:
		cap_center_y = half_straight
	elif hit_dir.y < -0.01:
		cap_center_y = -half_straight
		
	var capsule_cap_center = Vector2(0, cap_center_y)
	# The exit point on the local boundary in hit_dir
	var local_exit_pos = capsule_cap_center + hit_dir.normalized() * radius
	
	# Scale by a small amount to ensure it starts slightly outside the visual boundary
	return center + local_exit_pos * 1.2


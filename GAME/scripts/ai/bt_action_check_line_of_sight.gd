@tool
extends BTAction
class_name BTActionCheckLineOfSight

@export var max_distance: float = 600.0

func _tick(delta: float) -> Status:
	if not agent or not blackboard:
		return FAILURE
		
	var target = blackboard.get_var(&"target", null) as Node2D
	if not target or not is_instance_valid(target):
		return FAILURE
		
	var detection_dist = max_distance
	var det_comp = agent.get_node_or_null("PoliceDetectionComponent")
	if det_comp:
		detection_dist = det_comp.detection_radius
		
	var distance = agent.global_position.distance_to(target.global_position)
	if distance > detection_dist:
		blackboard.set_var(&"has_line_of_sight", false)
		return FAILURE
		
	# Basic raycast to check for walls (collision mask 1 normally)
	var space_state = agent.get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(agent.global_position, target.global_position, 1)
	query.exclude = [agent.get_rid()]
	var result = space_state.intersect_ray(query)
	
	if result:
		# Hit a wall
		blackboard.set_var(&"has_line_of_sight", false)
		return FAILURE
	else:
		# Clear LOS
		blackboard.set_var(&"has_line_of_sight", true)
		blackboard.set_var(&"last_known_position", target.global_position)
		blackboard.set_var(&"is_searching", false)
		
		# Shared Intel: Broadcast to all police
		if agent.has_node("/root/HeatManager"):
			var vel = target.velocity if target is CharacterBody2D else Vector2.ZERO
			agent.get_node("/root/HeatManager").broadcast_player_position(target.global_position, vel)
			
		return SUCCESS

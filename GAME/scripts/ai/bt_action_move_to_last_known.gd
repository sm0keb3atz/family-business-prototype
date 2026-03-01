@tool
extends BTAction
class_name BTActionMoveToLastKnown

@export var tolerance: float = 20.0

func _tick(delta: float) -> Status:
	if not agent or not blackboard:
		return FAILURE
		
	var nav_agent = agent.get_node_or_null("%NavigationAgent2D")
	if not nav_agent:
		return FAILURE
		
	if not blackboard.has_var(&"last_known_position"):
		return FAILURE
		
	var last_known = blackboard.get_var(&"last_known_position", Vector2.ZERO)
	if last_known == Vector2.ZERO:
		return FAILURE

	# INTERCEPT LOGIC: Don't just go to where they WERE, go to where they are GOING
	var lkv = blackboard.get_var(&"last_known_velocity", Vector2.ZERO)
	var target_pos = last_known
	
	if lkv.length() > 50.0:
		# Calculate distance to LKP
		var dist = agent.global_position.distance_to(last_known)
		var time_to_reach = dist / agent.stats.move_speed
		# Project player position ahead
		target_pos = last_known + (lkv * time_to_reach * 0.8) # 80% confidence projection

	# FLANKING/SURROUND LOGIC: Each officer approaches from a slightly different angle
	if not blackboard.has_var(&"approach_offset"):
		# Persistence: Generate a perpendicular offset
		var perp = Vector2(-lkv.y, lkv.x).normalized() if lkv != Vector2.ZERO else Vector2.UP
		if randf() < 0.5: perp = -perp
		var offset = perp * randf_range(100.0, 300.0)
		blackboard.set_var(&"approach_offset", offset)
	
	var approach_target = target_pos + blackboard.get_var(&"approach_offset", Vector2.ZERO)
	nav_agent.target_position = approach_target
	
	var dist_to_target = agent.global_position.distance_to(approach_target)
	
	# Transition to search if we arrive at the intercept/flank point
	if dist_to_target <= tolerance or nav_agent.is_navigation_finished():
		blackboard.set_var(&"search_anchor", target_pos) # Search the INTERCEPT point
		blackboard.set_var(&"is_searching", true)
		blackboard.set_var(&"last_known_position", Vector2.ZERO)
		# Clear offset for next time
		blackboard.erase_var(&"approach_offset")
		return SUCCESS
		
	var next_path_pos: Vector2 = nav_agent.get_next_path_position()
	var dir: Vector2 = agent.global_position.direction_to(next_path_pos)
	nav_agent.set_velocity(dir * agent.stats.move_speed)
	
	return RUNNING

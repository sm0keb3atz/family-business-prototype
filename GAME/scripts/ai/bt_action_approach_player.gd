@tool
extends BTAction
## Approaches the player until within a certain distance.
## Uses NavigationAgent2D for movement to ensure animations are synced.

@export var distance_threshold: float = 75.0
@export var speed_multiplier: float = 1.0

func _generate_name() -> String:
	return "Approach Player"

func _tick(_delta: float) -> Status:
	var npc: NPC = agent as NPC
	if not npc or not npc.nav_agent or not blackboard:
		return FAILURE
	
	# ONLY approach if we actually see him or have a recent last known position
	var has_los = blackboard.get_var(&"has_line_of_sight", false)
	var lkp = blackboard.get_var(&"last_known_position", Vector2.ZERO)
	
	if has_los:
		# Update lkp to current player pos (safety, though LOS check node does this too)
		var player = npc.get_tree().get_first_node_in_group("player")
		if player:
			lkp = player.global_position
			blackboard.set_var(&"last_known_position", lkp)

	if lkp == Vector2.ZERO:
		return FAILURE
		
	var dist = npc.global_position.distance_to(lkp)
	
	if dist <= distance_threshold:
		# If we arrived at LKP but don't see him, we should fail so parent can search
		if not has_los:
			return SUCCESS # Returning success so MoveToLastKnown logic can transition
			
		# Force instant stop if we are in arrest range
		npc.nav_agent.set_velocity(Vector2.ZERO)
		return SUCCESS

	# Set target to last known position
	npc.nav_agent.target_position = lkp
	
	if npc.nav_agent.is_navigation_finished():
		return SUCCESS
		
	# Calculate direction and velocity
	var next_pos: Vector2 = npc.nav_agent.get_next_path_position()
	var direction: Vector2 = (next_pos - npc.global_position).normalized()
	var speed = npc.stats.move_speed * speed_multiplier
	
	# Slow down slightly when approaching to look more deliberate
	if dist < 200.0:
		speed *= 0.7
		
	var desired_velocity: Vector2 = direction * speed
	npc.nav_agent.set_velocity(desired_velocity)
	
	return RUNNING

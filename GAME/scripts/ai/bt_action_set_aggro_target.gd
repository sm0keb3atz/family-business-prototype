@tool
extends BTAction
class_name BTActionSetAggroTarget

func _tick(delta: float) -> Status:
	if not agent or not blackboard:
		return FAILURE
		
	# For simplicity, target the player directly.
	var player = agent.get_tree().get_first_node_in_group("player")
	if player:
		blackboard.set_var(&"target", player)
		return SUCCESS
		
	return FAILURE

@tool
extends BTAction
class_name BTActionCheckArrestRange

@export var arrest_distance: float = 80.0

func _tick(delta: float) -> Status:
	if not agent or not blackboard:
		return FAILURE
		
	var target = blackboard.get_var(&"target", null) as Node2D
	if not target or not is_instance_valid(target):
		return FAILURE
		
	if agent.global_position.distance_to(target.global_position) <= arrest_distance:
		blackboard.set_var(&"is_in_arrest_range", true)
		return SUCCESS
	else:
		blackboard.set_var(&"is_in_arrest_range", false)
		return FAILURE

@tool
extends BTAction
class_name BTActionSlowPlayerMovement

@export var slow_multiplier: float = 0.5

func _tick(delta: float) -> Status:
	if not agent or not blackboard:
		return FAILURE
		
	var target = blackboard.get_var(&"target", null) as Node2D
	if not target or not is_instance_valid(target):
		return FAILURE
		
	# In a full setup, we'd apply a debuff component or set a flag on the player.
	# For now, we mock it by returning SUCCESS and assuming the player is slowed while in this state.
	
	return SUCCESS

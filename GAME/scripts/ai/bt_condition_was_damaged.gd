@tool
extends BTCondition
class_name BTConditionWasDamaged

## Checks if the agent has been actually shot (damaged) by reading the blackboard "was_shot" flag.
## Ignores the "heard_gunfire" flag, meaning it only passes if the agent was directly harmed.

func _generate_name() -> String:
	return "WasDamaged?"

func _tick(_delta: float) -> Status:
	var was_shot: bool = blackboard.get_var(&"was_shot", false)
	
	if was_shot:
		return SUCCESS
	return FAILURE

@tool
extends BTCondition
## Checks if the agent has been shot by reading the blackboard "was_shot" flag.
## Returns SUCCESS if the flag is true, FAILURE otherwise.

func _generate_name() -> String:
	return "WasShot?"

func _tick(_delta: float) -> Status:
	var was_shot: bool = blackboard.get_var(&"was_shot", false)
	if was_shot:
		return SUCCESS
	return FAILURE

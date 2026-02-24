@tool
extends BTCondition
## Returns SUCCESS if 'is_solicited' is true on the blackboard.

func _generate_name() -> String:
	return "Is Solicited?"

func _tick(_delta: float) -> Status:
	if blackboard.get_var(&"is_solicited", false):
		return SUCCESS
	return FAILURE

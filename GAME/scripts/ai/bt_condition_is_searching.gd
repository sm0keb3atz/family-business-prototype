@tool
extends BTCondition
class_name BTConditionIsSearching

func _tick(delta: float) -> Status:
	if blackboard and blackboard.has_var(&"is_searching") and blackboard.get_var(&"is_searching", false):
		return SUCCESS
	return FAILURE

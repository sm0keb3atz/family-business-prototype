@tool
extends BTCondition

func _generate_name() -> String:
	return "Is Front Business Customer"

func _tick(_delta: float) -> Status:
	if not blackboard:
		return FAILURE
	if not blackboard.has_var(&"is_front_business_customer"):
		return FAILURE
	return SUCCESS if blackboard.get_var(&"is_front_business_customer", false) else FAILURE

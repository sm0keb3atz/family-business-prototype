@tool
extends BTCondition

func _generate_name() -> String:
	return "Is Dealer Customer?"

func _tick(_delta: float) -> Status:
	if blackboard and blackboard.has_var(&"is_dealer_customer") and blackboard.get_var(&"is_dealer_customer", false):
		return SUCCESS
	return FAILURE

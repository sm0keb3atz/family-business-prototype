@tool
extends BTCondition
class_name BTConditionRespondingToGunshot

## True when this officer was dispatched to investigate a gunshot (0 stars, heard shot in range).

func _tick(_delta: float) -> Status:
	if blackboard and blackboard.has_var(&"responding_to_gunshot") and blackboard.get_var(&"responding_to_gunshot", false):
		return SUCCESS
	return FAILURE

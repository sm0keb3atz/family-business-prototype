@tool
extends BTCondition
class_name BTConditionIntelFresh
## Returns SUCCESS if the last sighting of the target was within
## [member max_age_seconds]. Used as a guard on chase/investigate branches.

@export var max_age_seconds: float = 5.0

func _generate_name() -> String:
	return "Intel Fresh (≤%ss)" % max_age_seconds

func _tick(_delta: float) -> Status:
	if not blackboard:
		return FAILURE
	var last_seen: float = blackboard.get_var(&"last_seen_time", 0.0)
	if last_seen <= 0.0:
		return FAILURE
	var age: float = (Time.get_ticks_msec() / 1000.0) - last_seen
	return SUCCESS if age <= max_age_seconds else FAILURE

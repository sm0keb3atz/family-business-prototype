@tool
extends BTCondition
class_name BTConditionConfidenceAbove
## Returns SUCCESS when the officer's current confidence in
## the player's position is at or above [member threshold].
## Confidence decays automatically over time via [IntelConfidence].

@export var threshold: float = 0.5

func _generate_name() -> String:
	return "Confidence ≥ %s" % threshold

func _tick(_delta: float) -> Status:
	if not blackboard:
		return FAILURE
	var conf: float = IntelConfidence.get_current_confidence(blackboard)
	return SUCCESS if conf >= threshold else FAILURE

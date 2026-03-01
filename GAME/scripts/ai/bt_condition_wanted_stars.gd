@tool
extends BTCondition
class_name BTConditionWantedStars

@export var required_stars: int = 1
@export var comparison: String = ">=" # can be "==", ">=", "<=", ">", "<"

func _tick(delta: float) -> Status:
	var current_stars = 0
	if agent and agent.get_tree().root.has_node("HeatManager"):
		current_stars = agent.get_tree().root.get_node("HeatManager").wanted_stars
		
	var result = false
	match comparison:
		"==": result = (current_stars == required_stars)
		">=": result = (current_stars >= required_stars)
		"<=": result = (current_stars <= required_stars)
		">": result = (current_stars > required_stars)
		"<": result = (current_stars < required_stars)
		
	return SUCCESS if result else FAILURE

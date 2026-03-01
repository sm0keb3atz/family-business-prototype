@tool
extends BTAction
class_name BTActionHandleArrestOutcome

@export var base_escape_chance: float = 0.2

var time_in_state: float = 0.0
@export var arrest_time_required: float = 3.0

func _enter() -> void:
	time_in_state = 0.0
	if agent and agent.has_method("get_node"):
		var movement = agent.get_node_or_null("Components/MovementComponent")
		if movement:
			movement.move_velocity(Vector2.ZERO)
	
	print("POLICE: YOU'RE UNDER ARREST! DON'T MOVE!")

func _tick(delta: float) -> Status:
	if not agent or not blackboard:
		return FAILURE
		
	time_in_state += delta
	
	# Mock checking input for breaking free.
	# If player mashes buttons, we could check here.
	if Input.is_action_just_pressed("ui_accept"):
		if randf() < base_escape_chance:
			# Player broke free!
			if agent and agent.get_tree().root.has_node("HeatManager"):
				agent.get_tree().root.get_node("HeatManager").set_stars(2)
			print("Player broke free from arrest!")
			return FAILURE
			
	if time_in_state >= arrest_time_required:
		print("Player ARRESTED. Game Over / Respawn logic goes here.")
		return SUCCESS
		
	return RUNNING

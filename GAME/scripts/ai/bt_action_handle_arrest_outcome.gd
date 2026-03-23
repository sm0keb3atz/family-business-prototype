@tool
extends BTAction
class_name BTActionHandleArrestOutcome

@export var base_escape_chance: float = 0.2

const ARREST_BARKS = [
	preload("res://GAME/assets/audio/dialog/police/police_getontheground.ogg"),
	preload("res://GAME/assets/audio/dialog/police/police_getyourhandsbehindyourback.ogg"),
	preload("res://GAME/assets/audio/dialog/police/police_layontheground.ogg"),
	preload("res://GAME/assets/audio/dialog/police/police_ontheground.ogg"),
	preload("res://GAME/assets/audio/dialog/police/police_stopresisting.ogg"),
	preload("res://GAME/assets/audio/dialog/police/police_stopresisting2.ogg"),
	preload("res://GAME/assets/audio/dialog/police/police_stopresisting3.ogg"),
	preload("res://GAME/assets/audio/dialog/police/police_wehaveyousurrounded.ogg")
]

const ARREST_TEXTS = [
	"Get on the ground!",
	"Get your hands behind your back!",
	"Lay on the ground!",
	"On the ground!",
	"Stop resisting!",
	"Stop resisting!",
	"Stop resisting!",
	"We have you surrounded!"
]

var time_in_state: float = 0.0
@export var arrest_time_required: float = 3.0

func _enter() -> void:
	time_in_state = 0.0
	if agent and agent.has_method("get_node"):
		var movement = agent.get_node_or_null("Components/MovementComponent")
		if movement:
			movement.move_velocity(Vector2.ZERO)
			
		var detect_comp = agent.get_node_or_null("PoliceDetectionComponent")
		if detect_comp and detect_comp.bark_player:
			var idx = randi() % ARREST_BARKS.size()
			detect_comp.bark_player.stream = ARREST_BARKS[idx]
			# Ensure volume is consistent
			detect_comp.bark_player.volume_db = -10.0
			detect_comp.bark_player.play()
			
			if agent.has_method("bark"):
				agent.bark(ARREST_TEXTS[idx], 3.0, true, "combat")
	
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

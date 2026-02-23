extends Area2D
class_name DoorTrigger

@export var leads_to_interior: bool = true
## The marker or position where the player should spawn after swapping.
@export var spawn_point: Node2D
## The door node containing the AnimationPlayer (optional)
@export var door_node: Node



func _ready() -> void:
	add_to_group("door_trigger")
	# Ensure we detect the player (Layer 2)
	collision_mask |= 2
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	print("DoorTrigger: Body entered: ", body.name)
	if body.is_in_group("player") and body.has_method("interact"):
		print("DoorTrigger: Setting player current_interactable")
		body.current_interactable = self

func _on_body_exited(body: Node2D) -> void:
	print("DoorTrigger: Body exited: ", body.name)
	if body.is_in_group("player"):
		if body.get("current_interactable") == self:
			print("DoorTrigger: Clearing player current_interactable")
			body.current_interactable = null

func interact() -> void:
	print("DoorTrigger: Interaction triggered for ", name, ". door_node is: ", door_node.name if door_node else "NULL")
	var map_manager = get_tree().get_first_node_in_group("map_manager")
	if map_manager and map_manager.has_method("interact_with_door"):
		var target_pos = Vector2.ZERO
		if spawn_point:
			target_pos = spawn_point.global_position
			
		map_manager.interact_with_door(leads_to_interior, target_pos, door_node)
	else:
		print("DoorTrigger: MapManager not found or incompatible.")

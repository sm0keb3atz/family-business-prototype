extends Area2D
class_name StashInteractArea

@export var property_component: PropertyComponent

func _ready() -> void:
	add_to_group("door_trigger")
	add_to_group("interact_area")
	collision_mask |= 2
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("register_interactable"):
		body.register_interactable(self)

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("unregister_interactable"):
		body.unregister_interactable(self)

func interact() -> void:
	if not property_component: return
	
	var player = get_tree().get_first_node_in_group("player")
	if player:
		if player.get("property_ui"):
			var prop_state = property_component.get_property_state()
			if prop_state:
				player.property_ui.open(prop_state, player.inventory_component)

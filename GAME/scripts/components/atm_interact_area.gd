extends Area2D
class_name ATMInteractArea

func _ready() -> void:
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
	var player := get_tree().get_first_node_in_group("player")
	if player and player.get("atm_ui"):
		player.atm_ui.open(player)

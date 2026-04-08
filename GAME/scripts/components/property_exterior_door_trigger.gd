extends DoorTrigger
class_name PropertyExteriorDoorTrigger

@export var property_component: PropertyComponent

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("register_interactable"):
		body.register_interactable(self)
		if property_component and not property_component.is_owned():
			var price = property_component.property_data.purchase_price
			body.show_bark("Press [E] to buy this Stash for $" + str(price), "generic")
		else:
			body.show_bark("Press [E] to Enter", "generic")

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("unregister_interactable"):
		body.unregister_interactable(self)
		body.interrupt_bark()

func interact() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player: player.set("_is_interacting", false)

	if not property_component:
		super.interact()
		return
		
	if property_component.is_owned():
		super.interact()
	else:
		var price = property_component.property_data.purchase_price
		if property_component.purchase():
			if player: player.show_bark("Bought for $" + str(price) + "!", "generic")
			# Briefly wait or teleport immediately
			super.interact()
		else:
			if player: player.show_bark("Need $" + str(price) + " dirty money!", "generic")

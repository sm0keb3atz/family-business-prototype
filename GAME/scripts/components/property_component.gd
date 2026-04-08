class_name PropertyComponent extends Node

@export var property_data: PropertyResource

func get_property_state() -> OwnedPropertyState:
	var network = get_tree().root.get_node_or_null("NetworkManager")
	if network:
		return network.get_property(property_data.property_id)
	return null

func is_owned() -> bool:
	return get_property_state() != null

func purchase() -> bool:
	var network = get_tree().root.get_node_or_null("NetworkManager")
	if network:
		return network.purchase_property(property_data)
	return false

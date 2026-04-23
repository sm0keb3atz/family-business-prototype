extends Area2D
class_name TerritoryArea

@export var territory_data: TerritoryResource

@onready var reputation_component: TerritoryReputationComponent = get_node_or_null("ReputationComponent")
@onready var spawner: TerritorySpawner = get_node_or_null("TerritorySpawner")
@onready var dealer_traffic_component: TerritoryDealerTrafficComponent = get_node_or_null("DealerTraffic")
@onready var collision_shape: CollisionShape2D = get_node_or_null("CollisionShape2D")

signal player_entered(territory_id: StringName)
signal player_exited(territory_id: StringName)

func _ready() -> void:
	add_to_group("territories")
	_ensure_collision_shape()
	
	if territory_data:
		name = territory_data.display_name.replace(" ", "")
		if reputation_component:
			reputation_component.territory_id = territory_data.territory_id
		if spawner:
			# Pass dependencies to spawner if needed, though it mostly reads from parent
			pass
	
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _ensure_collision_shape() -> void:
	if not collision_shape:
		return
	if collision_shape.shape:
		return
	
	var marker_positions: Array[Vector2] = []
	for child in get_children():
		_collect_marker_positions(child, marker_positions)
	
	if marker_positions.is_empty():
		return
	
	var min_pos = marker_positions[0]
	var max_pos = marker_positions[0]
	for pos in marker_positions:
		min_pos.x = min(min_pos.x, pos.x)
		min_pos.y = min(min_pos.y, pos.y)
		max_pos.x = max(max_pos.x, pos.x)
		max_pos.y = max(max_pos.y, pos.y)
	
	var padding = Vector2(200, 200)
	min_pos -= padding
	max_pos += padding
	
	var size = max_pos - min_pos
	var center = min_pos + size * 0.5
	var rect_shape := RectangleShape2D.new()
	rect_shape.size = size
	collision_shape.shape = rect_shape
	collision_shape.position = center

func _collect_marker_positions(node: Node, out_positions: Array[Vector2]) -> void:
	if node is Marker2D:
		out_positions.append(to_local(node.global_position))
	for child in node.get_children():
		_collect_marker_positions(child, out_positions)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_entered.emit(get_territory_id())

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_exited.emit(get_territory_id())

## Returns the price for a specific drug in this territory
func get_drug_price(drug_id: StringName) -> int:
	if not territory_data: return 0
	
	var base_price = territory_data.drug_prices.get(drug_id, 10)
	return int(base_price * territory_data.price_multiplier)


func get_territory_id() -> StringName:
	return territory_data.territory_id if territory_data else &""


static func get_territory_by_id(tree: SceneTree, target_id: StringName) -> TerritoryArea:
	if not tree:
		return null
	var nodes := tree.get_nodes_in_group(&"territories")
	for node in nodes:
		var territory := node as TerritoryArea
		if territory and territory.get_territory_id() == target_id:
			return territory
	return null


func get_reputation() -> float:
	return reputation_component.get_reputation() if reputation_component else 0.0


func is_controlled() -> bool:
	var territory_id: StringName = get_territory_id()
	if territory_id == &"":
		return false
	return NetworkManager.is_territory_controlled(territory_id)


func get_hired_dealer_count() -> int:
	var territory_id: StringName = get_territory_id()
	if territory_id == &"":
		return 0
	return NetworkManager.get_hired_dealer_slots(territory_id).size()


func get_support_property_id() -> StringName:
	var territory_id: StringName = get_territory_id()
	if territory_id == &"":
		return &""
	return NetworkManager.get_territory_support_property_id(territory_id)


func get_support_property() -> OwnedPropertyState:
	var territory_id: StringName = get_territory_id()
	if territory_id == &"":
		return null
	return NetworkManager.get_territory_support_property(territory_id)


func get_support_property_name() -> String:
	var property_state: OwnedPropertyState = get_support_property()
	if property_state and property_state.property_data:
		return property_state.property_data.display_name
	return "None linked"


func get_support_stash_dirty_cash() -> int:
	var territory_id: StringName = get_territory_id()
	if territory_id == &"":
		return 0
	var stash: StashInventory = NetworkManager.get_territory_support_stash(territory_id)
	return stash.dirty_cash if stash else 0


func get_support_status() -> Dictionary:
	var territory_id: StringName = get_territory_id()
	if territory_id == &"":
		return {}
	return NetworkManager.get_territory_support_status(territory_id)


func has_support_property() -> bool:
	return get_support_property() != null


func is_support_network_productive() -> bool:
	return bool(get_support_status().get("is_productive", false))


func get_active_customer_count() -> int:
	return spawner.get_active_customer_count() if spawner else 0


func get_active_hired_dealer_count() -> int:
	return spawner.get_active_hired_dealer_count() if spawner else 0


func get_active_ambient_dealer_count() -> int:
	return spawner.get_active_ambient_dealer_count() if spawner else 0


func get_active_dealer_traffic_count() -> int:
	return dealer_traffic_component.get_active_dealer_customer_count() if dealer_traffic_component else 0


func get_random_point_inside() -> Vector2:
	if not collision_shape or not collision_shape.shape is RectangleShape2D:
		return global_position
	
	var rect := collision_shape.shape as RectangleShape2D
	var half_extents = rect.size * 0.5
	var local_pos = collision_shape.position + Vector2(
		randf_range(-half_extents.x, half_extents.x),
		randf_range(-half_extents.y, half_extents.y)
	)
	return to_global(local_pos)

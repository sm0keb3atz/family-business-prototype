extends Area2D
class_name TerritoryArea

@export var territory_data: TerritoryResource

@onready var reputation_component: TerritoryReputationComponent = get_node_or_null("ReputationComponent")
@onready var spawner: TerritorySpawner = get_node_or_null("TerritorySpawner")
@onready var collision_shape: CollisionShape2D = get_node_or_null("CollisionShape2D")

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
		# Could notify a UI or MapManager that the player entered a territory
		pass

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		pass

## Returns the price for a specific drug in this territory
func get_drug_price(drug_id: StringName) -> int:
	if not territory_data: return 0
	
	var base_price = territory_data.drug_prices.get(drug_id, 10)
	return int(base_price * territory_data.price_multiplier)

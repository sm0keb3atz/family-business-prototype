extends Node
class_name FrontBusinessCustomerTrafficComponent

@export var business_area: FrontBusinessInteractArea
@export var sales_anchor: Marker2D
@export var min_interval_seconds: float = 6.0
@export var max_interval_seconds: float = 12.0
@export var assignment_radius: float = 1300.0
@export var max_concurrent_buyers: int = 2

func _ready() -> void:
	if not business_area:
		business_area = get_parent() as FrontBusinessInteractArea
	if business_area:
		call_deferred("_schedule_next_tick")

func _schedule_next_tick() -> void:
	if not is_inside_tree():
		return
	var delay: float = randf_range(min_interval_seconds, max_interval_seconds)
	get_tree().create_timer(delay).timeout.connect(_on_tick, CONNECT_ONE_SHOT)

func _on_tick() -> void:
	_try_assign_buyer()
	_schedule_next_tick()

func _try_assign_buyer() -> void:
	if not business_area or not business_area.business_data:
		return
	var state := NetworkManager.get_front_business_state(business_area.business_data)
	if not state or not state.is_purchased:
		return
	if _count_active_front_business_customers() >= max_concurrent_buyers:
		return
	var available_levels: Array[int] = _get_sellable_levels(state)
	if available_levels.is_empty():
		return
	var candidates: Array[NPC] = []
	for node in get_tree().get_nodes_in_group("npc"):
		var npc := node as NPC
		if _is_eligible_customer(npc):
			candidates.append(npc)
	if candidates.is_empty():
		return
	candidates.shuffle()
	available_levels.shuffle()
	var customer: NPC = candidates[0]
	var level: int = available_levels[0]
	customer.blackboard.set_var(&"is_front_business_customer", true)
	var approach_target: Node2D = business_area
	if sales_anchor:
		approach_target = sales_anchor
	customer.blackboard.set_var(&"approach_target", approach_target)
	customer.blackboard.set_var(&"front_business_purchase_target", business_area)
	customer.blackboard.set_var(&"front_business_level", level)

func _get_sellable_levels(state: OwnedFrontBusinessState) -> Array[int]:
	var levels: Array[int] = []
	for level in range(1, 5):
		var stock_key: StringName = NetworkManager.get_gun_shop_stock_key(level)
		if state.get_stock_amount(stock_key) > 0:
			levels.append(level)
	return levels

func _is_eligible_customer(npc: NPC) -> bool:
	if not npc or npc.role != NPC.Role.CUSTOMER:
		return false
	if not npc.blackboard or not npc.nav_agent:
		return false
	if npc.global_position.distance_to(business_area.global_position) > assignment_radius:
		return false
	if npc.blackboard.get_var(&"is_solicited", false):
		return false
	if npc.blackboard.get_var(&"is_dealer_customer", false):
		return false
	if npc.blackboard.has_var(&"is_front_business_customer") and npc.blackboard.get_var(&"is_front_business_customer", false):
		return false
	return true

func _count_active_front_business_customers() -> int:
	var count: int = 0
	for node in get_tree().get_nodes_in_group("npc"):
		var npc := node as NPC
		if npc and npc.blackboard and npc.blackboard.has_var(&"is_front_business_customer") and npc.blackboard.get_var(&"is_front_business_customer", false):
			count += 1
	return count

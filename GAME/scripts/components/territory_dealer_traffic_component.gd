extends Node
class_name TerritoryDealerTrafficComponent
## Periodically sends civilians to buy from dealers in this territory (ambient or hired).

@export var min_interval_seconds: float = 4.0
@export var max_interval_seconds: float = 9.0
@export var max_concurrent_buyers: int = 3

var _territory: TerritoryArea
var _spawner: TerritorySpawner

func _ready() -> void:
	_territory = get_parent() as TerritoryArea
	if not _territory:
		push_error("TerritoryDealerTrafficComponent must be a child of TerritoryArea")
		return
	_spawner = _territory.get_node_or_null("TerritorySpawner") as TerritorySpawner
	if not _spawner:
		push_warning("TerritoryDealerTrafficComponent: no TerritorySpawner sibling")
		return
	call_deferred("_schedule_next_tick")

func _schedule_next_tick() -> void:
	if not is_inside_tree():
		return
	var delay: float = randf_range(min_interval_seconds, max_interval_seconds)
	get_tree().create_timer(delay).timeout.connect(_on_traffic_tick, CONNECT_ONE_SHOT)

func _on_traffic_tick() -> void:
	if not is_instance_valid(_territory) or not is_instance_valid(_spawner):
		return
	_try_assign_buyer()
	_schedule_next_tick()

func _try_assign_buyer() -> void:
	if _count_active_dealer_customers() >= max_concurrent_buyers:
		return

	var customers: Array[NPC] = _spawner.get_active_customers()
	var dealers: Array[NPC] = _spawner.get_active_dealers()
	if customers.is_empty() or dealers.is_empty():
		return
	customers.shuffle()
	dealers.shuffle()

	for customer in customers:
		if not _is_eligible_customer(customer):
			continue
		for dealer in dealers:
			if not _dealer_has_sellable_stock(dealer):
				continue
			var pick: Dictionary = _roll_purchase(dealer)
			if pick.is_empty():
				continue
			_assign_customer_to_dealer(customer, dealer, pick["drug_id"], pick["grams"])
			return

func _count_active_dealer_customers() -> int:
	var n: int = 0
	for c in _spawner.get_active_customers():
		if not is_instance_valid(c) or not c.blackboard:
			continue
		if c.blackboard.has_var(&"is_dealer_customer") and c.blackboard.get_var(&"is_dealer_customer", false):
			n += 1
	return n

func get_active_dealer_customer_count() -> int:
	return _count_active_dealer_customers()

func _is_eligible_customer(npc: NPC) -> bool:
	if not is_instance_valid(npc) or npc.role != NPC.Role.CUSTOMER:
		return false
	if not npc.blackboard:
		return false
	if npc.blackboard.has_var(&"is_solicited") and npc.blackboard.get_var(&"is_solicited", false):
		return false
	if npc.blackboard.has_var(&"is_dealer_customer") and npc.blackboard.get_var(&"is_dealer_customer", false):
		return false
	if npc.get_meta(&"territory", null) != _territory:
		return false
	if not npc.nav_agent:
		return false
	return true

func _dealer_has_sellable_stock(dealer: NPC) -> bool:
	if not is_instance_valid(dealer) or dealer.role != NPC.Role.DEALER:
		return false
	var shop: DealerShopComponent = dealer.get_node_or_null("DealerShopComponent") as DealerShopComponent
	if not shop:
		return false
	for drug_id in shop.get_available_drug_ids():
		if shop.get_stock_amount(drug_id) > 0:
			return true
	return false

func _roll_purchase(dealer: NPC) -> Dictionary:
	var shop: DealerShopComponent = dealer.get_node_or_null("DealerShopComponent") as DealerShopComponent
	if not shop:
		return {}
	var candidates: Array[StringName] = []
	for drug_id in shop.get_available_drug_ids():
		if shop.get_stock_amount(drug_id) > 0:
			candidates.append(drug_id)
	if candidates.is_empty():
		return {}
	var drug_id: StringName = candidates.pick_random()
	var max_g: int = shop.get_stock_amount(drug_id)
	var grams: int
	if shop.is_brick_stock_for(drug_id):
		var brick_grams: int = shop.get_brick_grams_for(drug_id)
		if brick_grams <= 0 or max_g < brick_grams:
			return {}
		var max_bricks: int = int(max_g / brick_grams)
		var brick_count: int = randi_range(1, max(1, mini(2, max_bricks)))
		grams = brick_count * brick_grams
	else:
		grams = randi_range(1, mini(24, max_g))
	if grams < 1:
		return {}
	return {"drug_id": drug_id, "grams": grams}

func _assign_customer_to_dealer(customer: NPC, dealer: NPC, drug_id: StringName, grams: int) -> void:
	customer.blackboard.set_var(&"is_dealer_customer", true)
	customer.blackboard.set_var(&"approach_target", dealer)
	customer.blackboard.set_var(&"dealer_purchase_target", dealer)
	customer.blackboard.set_var(&"dealer_purchase_drug_id", drug_id)
	customer.blackboard.set_var(&"dealer_purchase_grams", grams)
	if customer.has_method("_update_ui_icon"):
		customer._update_ui_icon()

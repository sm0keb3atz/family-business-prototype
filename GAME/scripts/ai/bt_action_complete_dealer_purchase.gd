@tool
extends BTAction
## Completes NPC purchase from dealer in `dealer_purchase_target` using shop npc_purchase.

@export var distance_threshold: float = 85.0

func _generate_name() -> String:
	return "Complete Dealer Purchase"

func _clear_dealer_customer_state(npc: NPC) -> void:
	if not blackboard:
		return
	blackboard.set_var(&"is_dealer_customer", false)
	blackboard.set_var(&"approach_target", null)
	blackboard.set_var(&"dealer_purchase_target", null)
	blackboard.set_var(&"dealer_purchase_drug_id", &"")
	blackboard.set_var(&"dealer_purchase_grams", 0)
	if npc and npc.has_method("_update_ui_icon"):
		npc._update_ui_icon()

func _tick(_delta: float) -> Status:
	var npc: NPC = agent as NPC
	if not npc or not blackboard:
		return FAILURE

	if not blackboard.has_var(&"dealer_purchase_target"):
		_clear_dealer_customer_state(npc)
		return FAILURE

	var dealer: Node2D = null
	var raw_dealer: Variant = blackboard.get_var(&"dealer_purchase_target", null)
	if is_instance_valid(raw_dealer) and raw_dealer is Node2D:
		dealer = raw_dealer
	if not is_instance_valid(dealer):
		_clear_dealer_customer_state(npc)
		return FAILURE

	var dist: float = npc.global_position.distance_to(dealer.global_position)
	if dist > distance_threshold:
		return RUNNING

	var drug_id: StringName = &"weed"
	if blackboard.has_var(&"dealer_purchase_drug_id"):
		drug_id = blackboard.get_var(&"dealer_purchase_drug_id", &"weed")

	var grams: int = 0
	if blackboard.has_var(&"dealer_purchase_grams"):
		grams = int(blackboard.get_var(&"dealer_purchase_grams", 0))
	if grams <= 0:
		_clear_dealer_customer_state(npc)
		return FAILURE

	var shop: DealerShopComponent = dealer.get_node_or_null("DealerShopComponent") as DealerShopComponent
	if not shop:
		_clear_dealer_customer_state(npc)
		return FAILURE

	if shop.npc_purchase(drug_id, grams):
		_clear_dealer_customer_state(npc)
		return SUCCESS

	_clear_dealer_customer_state(npc)
	return FAILURE

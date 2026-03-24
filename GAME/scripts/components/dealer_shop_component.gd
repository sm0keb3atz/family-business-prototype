extends Node
class_name DealerShopComponent

@export var tier_config: DealerTierResource

var current_stock: int = 0
var restock_timer: float = 0.0
var dealer_name: String = "Dealer"
var current_territory: TerritoryArea

func _ready() -> void:
	if tier_config:
		current_stock = randi_range(tier_config.min_stock, tier_config.max_stock)
		restock_timer = tier_config.restock_time_seconds
	
	var parent_npc = get_parent()
	if parent_npc and parent_npc.has_meta(&"territory"):
		current_territory = parent_npc.get_meta(&"territory")

func _process(delta: float) -> void:
	if not tier_config: return
	
	if current_stock < tier_config.max_stock:
		restock_timer -= delta
		if restock_timer <= 0.0:
			current_stock = tier_config.max_stock
			restock_timer = tier_config.restock_time_seconds

func can_buy(amount: int) -> bool:
	return current_stock >= amount

func buy(amount: int) -> void:
	if can_buy(amount):
		current_stock -= amount

func get_price(drug_id: StringName, buyer: Node = null) -> int:
	var base_price := 10
	if current_territory:
		base_price = current_territory.get_drug_price(drug_id)
	if buyer and buyer.has_method("get_dealer_price_multiplier"):
		base_price = max(1, roundi(float(base_price) * buyer.get_dealer_price_multiplier()))
	return base_price

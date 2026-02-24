extends Node
class_name DealerShopComponent

@export var tier_config: DealerTierResource

var current_stock: int = 0
var restock_timer: float = 0.0
var dealer_name: String = "Dealer"

func _ready() -> void:
	if tier_config:
		current_stock = tier_config.max_stock
		restock_timer = tier_config.restock_time_seconds

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

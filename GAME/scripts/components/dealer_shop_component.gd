extends Node
class_name DealerShopComponent

@export var tier_config: DealerTierResource

var current_stock: int = 0
var restock_timer: float = 0.0
var dealer_name: String = "Dealer"
var current_territory: TerritoryArea
var current_drug_definition: DrugDefinitionResource
var current_stock_uses_bricks: bool = false
var stock_by_drug: Dictionary = {}
var stock_mode_by_drug: Dictionary = {}

func _ready() -> void:
	if tier_config:
		_roll_stock()
		restock_timer = tier_config.restock_time_seconds
	
	var parent_npc = get_parent()
	if parent_npc and parent_npc.has_meta(&"territory"):
		current_territory = parent_npc.get_meta(&"territory")

func _process(delta: float) -> void:
	if not tier_config: return
	
	if _is_depleted():
		restock_timer -= delta
		if restock_timer <= 0.0:
			_roll_stock()
			restock_timer = tier_config.restock_time_seconds

func _roll_stock() -> void:
	stock_by_drug.clear()
	stock_mode_by_drug.clear()

	var options := tier_config.stock_options
	if options.is_empty():
		current_drug_definition = tier_config.allowed_drugs[0] if not tier_config.allowed_drugs.is_empty() else null
		current_stock_uses_bricks = tier_config.tier_level == 4
		if current_drug_definition:
			var amount := randi_range(tier_config.min_stock, tier_config.max_stock)
			if current_stock_uses_bricks:
				amount *= current_drug_definition.brick_grams
			stock_by_drug[current_drug_definition.id] = amount
			stock_mode_by_drug[current_drug_definition.id] = current_stock_uses_bricks
			current_stock = amount
		return

	if tier_config.tier_level >= 4:
		var option: DealerStockOptionResource = options.pick_random()
		current_drug_definition = option.drug
		current_stock_uses_bricks = option.use_bricks
		if not current_drug_definition:
			current_stock = 0
			return
		var rolled_amount := randi_range(option.min_amount, option.max_amount)
		if current_stock_uses_bricks:
			rolled_amount *= current_drug_definition.brick_grams
		stock_by_drug[current_drug_definition.id] = rolled_amount
		stock_mode_by_drug[current_drug_definition.id] = current_stock_uses_bricks
	else:
		for option in options:
			if not option or not option.drug:
				continue
			var rolled_amount := randi_range(option.min_amount, option.max_amount)
			if option.use_bricks:
				rolled_amount *= option.drug.brick_grams
			stock_by_drug[option.drug.id] = rolled_amount
			stock_mode_by_drug[option.drug.id] = option.use_bricks

	_sync_current_drug()

func _sync_current_drug(preferred_drug_id: StringName = &"") -> void:
	if preferred_drug_id != &"" and stock_by_drug.has(preferred_drug_id):
		current_drug_definition = DrugCatalog.get_definition(preferred_drug_id)
		current_stock = int(stock_by_drug.get(preferred_drug_id, 0))
		current_stock_uses_bricks = bool(stock_mode_by_drug.get(preferred_drug_id, false))
		return

	var selected_id := &""
	for drug_id in stock_by_drug.keys():
		if int(stock_by_drug[drug_id]) > 0:
			selected_id = drug_id
			break

	if selected_id == &"" and not stock_by_drug.is_empty():
		selected_id = stock_by_drug.keys()[0]

	current_drug_definition = DrugCatalog.get_definition(selected_id)
	current_stock = int(stock_by_drug.get(selected_id, 0))
	current_stock_uses_bricks = bool(stock_mode_by_drug.get(selected_id, false))

func _is_depleted() -> bool:
	for amount in stock_by_drug.values():
		if int(amount) > 0:
			return false
	return true

func get_available_drug_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for drug_id in stock_by_drug.keys():
		ids.append(drug_id)
	return ids

func get_stock_amount(drug_id: StringName) -> int:
	return int(stock_by_drug.get(drug_id, 0))

func is_brick_stock_for(drug_id: StringName) -> bool:
	return bool(stock_mode_by_drug.get(drug_id, false))

func get_brick_grams_for(drug_id: StringName) -> int:
	var definition := DrugCatalog.get_definition(drug_id)
	return definition.brick_grams if definition else 100

func get_brick_count_for(drug_id: StringName) -> int:
	var brick_grams := get_brick_grams_for(drug_id)
	return int(get_stock_amount(drug_id) / brick_grams) if brick_grams > 0 else 0

func select_drug(drug_id: StringName) -> void:
	_sync_current_drug(drug_id)

func can_buy_drug(drug_id: StringName, amount: int) -> bool:
	return get_stock_amount(drug_id) >= amount

func buy_drug(drug_id: StringName, amount: int) -> void:
	if not can_buy_drug(drug_id, amount):
		return
	var remaining := get_stock_amount(drug_id) - amount
	if remaining < 0:
		remaining = 0
	stock_by_drug[drug_id] = remaining
	_sync_current_drug(drug_id)
	if _is_depleted():
		restock_timer = tier_config.restock_time_seconds
	else:
		current_stock = int(stock_by_drug.get(current_drug_definition.id, 0)) if current_drug_definition else 0

func can_buy(amount: int) -> bool:
	return current_stock >= amount

func buy(amount: int) -> void:
	if current_drug_definition:
		buy_drug(current_drug_definition.id, amount)

func get_price(drug_id: StringName, buyer: Node = null) -> int:
	var base_price := 10
	if current_territory:
		base_price = current_territory.get_drug_price(drug_id)
	if buyer and buyer.has_method("get_dealer_price_multiplier"):
		base_price = max(1, roundi(float(base_price) * buyer.get_dealer_price_multiplier()))
	return base_price

func get_current_drug_id() -> StringName:
	return current_drug_definition.id if current_drug_definition else &"weed"

func is_brick_stock() -> bool:
	return current_stock_uses_bricks

func get_brick_grams() -> int:
	return current_drug_definition.brick_grams if current_drug_definition else 100

func get_current_brick_count() -> int:
	var brick_grams := get_brick_grams()
	return int(current_stock / brick_grams) if brick_grams > 0 else 0

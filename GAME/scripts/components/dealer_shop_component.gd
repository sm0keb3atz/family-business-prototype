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
	var parent_npc := get_parent()
	if parent_npc:
		if parent_npc.has_meta(&"territory"):
			current_territory = parent_npc.get_meta(&"territory")
		elif "territory_id" in parent_npc and parent_npc.territory_id != &"":
			current_territory = TerritoryArea.get_territory_by_id(get_tree(), parent_npc.territory_id)

	if tier_config:
		setup(tier_config, current_territory)

func setup(config: DealerTierResource, territory: TerritoryArea = null) -> void:
	tier_config = config
	current_territory = territory
	if _is_hired_dealer():
		_configure_hired_inventory_profile()
	else:
		_roll_stock()
		restock_timer = tier_config.restock_time_seconds

func _process(delta: float) -> void:
	if not tier_config:
		return
	if _is_hired_dealer():
		var preferred_id: StringName = &""
		if current_drug_definition:
			preferred_id = current_drug_definition.id
		_sync_current_drug(preferred_id)
		return

	if _is_depleted():
		restock_timer -= delta
		if restock_timer <= 0.0:
			_roll_stock()
			restock_timer = tier_config.restock_time_seconds

func _is_hired_dealer() -> bool:
	var parent_npc := get_parent()
	return parent_npc != null and parent_npc.get_meta(&"hired_dealer", false) == true

func _get_territory_id() -> StringName:
	if current_territory and current_territory.territory_data:
		return current_territory.territory_data.territory_id
	return &""

func _get_support_stash() -> StashInventory:
	var territory_id: StringName = _get_territory_id()
	if territory_id == &"":
		return null
	return NetworkManager.get_territory_support_stash(territory_id)

func _configure_hired_inventory_profile() -> void:
	stock_by_drug.clear()
	stock_mode_by_drug.clear()

	var options := tier_config.stock_options
	if options.is_empty():
		current_drug_definition = null
		if not tier_config.allowed_drugs.is_empty():
			current_drug_definition = tier_config.allowed_drugs[0]
		current_stock_uses_bricks = tier_config.tier_level == 4
		if current_drug_definition:
			stock_by_drug[current_drug_definition.id] = 0
			stock_mode_by_drug[current_drug_definition.id] = current_stock_uses_bricks
		current_stock = 0
		return

	if tier_config.tier_level >= 4:
		var option: DealerStockOptionResource = options.pick_random()
		current_drug_definition = option.drug
		current_stock_uses_bricks = option.use_bricks
		if current_drug_definition:
			stock_by_drug[current_drug_definition.id] = 0
			stock_mode_by_drug[current_drug_definition.id] = current_stock_uses_bricks
	else:
		for option in options:
			if not option or not option.drug:
				continue
			stock_by_drug[option.drug.id] = 0
			stock_mode_by_drug[option.drug.id] = option.use_bricks

	_sync_current_drug()

func _roll_stock() -> void:
	stock_by_drug.clear()
	stock_mode_by_drug.clear()

	var options := tier_config.stock_options
	if options.is_empty():
		current_drug_definition = null
		if not tier_config.allowed_drugs.is_empty():
			current_drug_definition = tier_config.allowed_drugs[0]
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

func _get_hired_stock_amount(drug_id: StringName) -> int:
	var stash: StashInventory = _get_support_stash()
	if not stash:
		return 0
	if is_brick_stock_for(drug_id):
		var brick_count: int = int(stash.bricks.get(drug_id, 0))
		return brick_count * get_brick_grams_for(drug_id)
	return int(stash.drugs.get(drug_id, 0))

func _sync_current_drug(preferred_drug_id: StringName = &"") -> void:
	if _is_hired_dealer():
		var supported_ids: Array[StringName] = get_available_drug_ids()
		var selected_id: StringName = &""
		if preferred_drug_id != &"" and supported_ids.has(preferred_drug_id):
			selected_id = preferred_drug_id
		if selected_id == &"":
			for drug_id in supported_ids:
				if _get_hired_stock_amount(drug_id) > 0:
					selected_id = drug_id
					break
		if selected_id == &"" and not supported_ids.is_empty():
			selected_id = supported_ids[0]
		current_drug_definition = DrugCatalog.get_definition(selected_id)
		current_stock_uses_bricks = bool(stock_mode_by_drug.get(selected_id, false))
		current_stock = _get_hired_stock_amount(selected_id)
		return

	if preferred_drug_id != &"" and stock_by_drug.has(preferred_drug_id):
		current_drug_definition = DrugCatalog.get_definition(preferred_drug_id)
		current_stock = int(stock_by_drug.get(preferred_drug_id, 0))
		current_stock_uses_bricks = bool(stock_mode_by_drug.get(preferred_drug_id, false))
		return

	var selected_id: StringName = &""
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
	if _is_hired_dealer():
		for drug_id in get_available_drug_ids():
			if _get_hired_stock_amount(drug_id) > 0:
				return false
		return true

	for amount in stock_by_drug.values():
		if int(amount) > 0:
			return false
	return true

func get_available_drug_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	var source: Dictionary = stock_by_drug
	if _is_hired_dealer():
		source = stock_mode_by_drug
	for drug_id in source.keys():
		ids.append(drug_id)
	return ids

func get_stock_amount(drug_id: StringName) -> int:
	if _is_hired_dealer():
		return _get_hired_stock_amount(drug_id)
	return int(stock_by_drug.get(drug_id, 0))

func is_brick_stock_for(drug_id: StringName) -> bool:
	return bool(stock_mode_by_drug.get(drug_id, false))

func get_brick_grams_for(drug_id: StringName) -> int:
	var definition := DrugCatalog.get_definition(drug_id)
	if definition:
		return definition.brick_grams
	return 100

func get_brick_count_for(drug_id: StringName) -> int:
	var brick_grams := get_brick_grams_for(drug_id)
	if brick_grams <= 0:
		return 0
	return int(get_stock_amount(drug_id) / brick_grams)

func select_drug(drug_id: StringName) -> void:
	_sync_current_drug(drug_id)

func can_buy_drug(drug_id: StringName, amount: int) -> bool:
	if amount <= 0:
		return false
	if _is_hired_dealer() and is_brick_stock_for(drug_id):
		var brick_grams: int = get_brick_grams_for(drug_id)
		if brick_grams <= 0 or amount % brick_grams != 0:
			return false
	return get_stock_amount(drug_id) >= amount

## NPC civilian purchase: same as buy_drug but returns whether stock was available.
func npc_purchase(drug_id: StringName, amount: int) -> bool:
	if not can_buy_drug(drug_id, amount):
		return false
	
	# Reduce stock for both hired and ambient dealers
	buy_drug(drug_id, amount)
	
	_apply_npc_sale_feedback(drug_id, amount)
	return true

func _apply_npc_sale_feedback(drug_id: StringName, amount: int) -> void:
	var price_per_gram := get_price(drug_id) + randi_range(2, 5)
	var payout: int = price_per_gram * amount
	if _is_hired_dealer():
		var stash: StashInventory = _get_support_stash()
		if stash:
			stash.add_dirty_cash(payout)

	var parent_npc := get_parent() as NPC
	if parent_npc:
		if parent_npc.npc_ui:
			parent_npc.npc_ui.spawn_indicator("money_up", "+$" + str(payout))
		AudioManager.play_spatial_transaction(parent_npc.global_position)
		if parent_npc.has_method("bark_dealer_feedback"):
			parent_npc.bark_dealer_feedback("solicitation")
	else:
		AudioManager.play_transaction()

func buy_drug(drug_id: StringName, amount: int) -> void:
	if not can_buy_drug(drug_id, amount):
		return

	if _is_hired_dealer():
		var stash: StashInventory = _get_support_stash()
		if not stash:
			return
		if is_brick_stock_for(drug_id):
			var brick_grams: int = get_brick_grams_for(drug_id)
			var brick_count: int = int(amount / brick_grams)
			if brick_count <= 0:
				return
			if not stash.remove_brick(drug_id, brick_count):
				return
		else:
			if not stash.remove_drug(drug_id, amount):
				return
		_sync_current_drug(drug_id)
		return

	var remaining := get_stock_amount(drug_id) - amount
	if remaining < 0:
		remaining = 0
	stock_by_drug[drug_id] = remaining
	_sync_current_drug(drug_id)
	if _is_depleted():
		restock_timer = tier_config.restock_time_seconds
	else:
		if current_drug_definition:
			current_stock = int(stock_by_drug.get(current_drug_definition.id, 0))
		else:
			current_stock = 0

func can_buy(amount: int) -> bool:
	return current_stock >= amount

func buy(amount: int) -> void:
	if current_drug_definition:
		buy_drug(current_drug_definition.id, amount)

func get_price(drug_id: StringName, buyer: Node = null) -> int:
	var base_price := 10
	if not current_territory:
		var parent_npc = get_parent()
		if parent_npc and "territory_id" in parent_npc and parent_npc.territory_id != &"":
			current_territory = TerritoryArea.get_territory_by_id(get_tree(), parent_npc.territory_id)

	if current_territory:
		base_price = current_territory.get_drug_price(drug_id)
	if buyer and buyer.has_method("get_dealer_price_multiplier"):
		base_price = max(1, roundi(float(base_price) * buyer.get_dealer_price_multiplier()))
	return base_price

func get_current_drug_id() -> StringName:
	if current_drug_definition:
		return current_drug_definition.id
	return &"weed"

func is_brick_stock() -> bool:
	return current_stock_uses_bricks

func get_brick_grams() -> int:
	if current_drug_definition:
		return current_drug_definition.brick_grams
	return 100

func get_current_brick_count() -> int:
	var brick_grams := get_brick_grams()
	if brick_grams <= 0:
		return 0
	return int(current_stock / brick_grams)

func is_interactable() -> bool:
	return not _is_hired_dealer()

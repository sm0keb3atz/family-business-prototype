extends Node

const ATM_DAILY_LIMIT: int = 1000

const GUN_SHOP_STOCK_KEYS := {
	1: &"glock_lv1",
	2: &"glock_lv2",
	3: &"glock_lv3",
	4: &"glock_lv4"
}

const GUN_SHOP_STOCK_COSTS := {
	1: 900,
	2: 1500,
	3: 2400,
	4: 3600
}

const GUN_SHOP_RETAIL_PRICES := {
	1: 1400,
	2: 2300,
	3: 3600,
	4: 5200
}

## The global economy state - dirty money, clean money, and debt.
## This persists independently of the player node (survives death/respawn).
var economy: EconomyState = EconomyState.new()

## Active owned properties mapped by property_id -> OwnedPropertyState
var owned_properties: Dictionary = {}

## Active front businesses mapped by business_id -> OwnedFrontBusinessState
var owned_front_businesses: Dictionary = {}

## territory_id -> true when the player controls that territory (separate from property ownership).
var controlled_territory_ids: Dictionary = {}

## territory_id -> Array[HiredDealerSlot]; only used while territory is controlled.
var hired_dealer_slots: Dictionary = {}

## territory_id -> property_id for the canonical stash house supporting hired dealers.
var territory_support_properties: Dictionary = {}

var _atm_daily_deposited_dirty: int = 0
var _atm_last_date_key: String = ""
var _time_manager: TimeManager

## Emitted once the NetworkManager has finished initialization.
signal economy_ready

## Emitted when a property is successfully purchased
signal property_purchased(property_state: OwnedPropertyState)
signal front_business_purchased(front_business_state: OwnedFrontBusinessState)
signal front_business_stock_changed(business_id: StringName, stock_key: StringName, new_amount: int)
signal front_business_sale_completed(business_id: StringName, stock_key: StringName, clean_amount: int)
signal atm_state_changed(daily_deposited: int, remaining_limit: int, date_key: String)

signal territory_control_changed(territory_id: StringName, controlled: bool)
signal hired_dealers_changed(territory_id: StringName)
signal territory_support_property_changed(territory_id: StringName, property_id: StringName)

func _ready() -> void:
	# Starting cash - the player begins with $1000 dirty money
	economy.dirty_money = 1000
	_connect_time_manager()
	economy_ready.emit()

func _connect_time_manager() -> void:
	if is_instance_valid(_time_manager):
		return
	
	_time_manager = get_tree().get_first_node_in_group("time_manager") as TimeManager
	if _time_manager:
		if not _time_manager.date_updated.is_connected(_on_date_updated):
			_time_manager.date_updated.connect(_on_date_updated)
		_ensure_atm_date_key()

func _ensure_atm_date_key() -> void:
	if not is_instance_valid(_time_manager):
		_connect_time_manager()
	
	if is_instance_valid(_time_manager):
		var date_key := _build_date_key(_time_manager.current_day, _time_manager.current_month, _time_manager.current_year)
		if _atm_last_date_key != date_key:
			_atm_last_date_key = date_key
			_atm_daily_deposited_dirty = 0
	elif _atm_last_date_key == "":
		# Default fallback if time manager isn't present yet (e.g. still in LoadingScreen)
		_atm_last_date_key = "STARTUP"
		_atm_daily_deposited_dirty = 0

func _on_date_updated(day: int, month: int, year: int) -> void:
	var date_key := _build_date_key(day, month, year)
	if _atm_last_date_key == date_key:
		return
	_atm_last_date_key = date_key
	_atm_daily_deposited_dirty = 0
	_emit_atm_state_changed()

func _build_date_key(day: int, month: int, year: int) -> String:
	return "%04d-%02d-%02d" % [year, month, day]

func get_atm_daily_limit() -> int:
	return ATM_DAILY_LIMIT

func get_atm_daily_deposited() -> int:
	_ensure_atm_date_key()
	return _atm_daily_deposited_dirty

func get_atm_remaining_deposit_limit() -> int:
	_ensure_atm_date_key()
	return max(ATM_DAILY_LIMIT - _atm_daily_deposited_dirty, 0)

func get_atm_date_key() -> String:
	_ensure_atm_date_key()
	return _atm_last_date_key

func deposit_dirty_to_clean(amount: int) -> int:
	_ensure_atm_date_key()
	if amount <= 0:
		return 0
	var actual_amount: int = mini(amount, mini(economy.dirty_money, get_atm_remaining_deposit_limit()))
	if actual_amount <= 0:
		return 0
	if not economy.spend_dirty(actual_amount):
		return 0
	economy.add_clean(actual_amount)
	_atm_daily_deposited_dirty += actual_amount
	_emit_atm_state_changed()
	return actual_amount

func withdraw_clean_to_dirty(amount: int) -> int:
	_ensure_atm_date_key()
	if amount <= 0:
		return 0
	var actual_amount: int = mini(amount, economy.clean_money)
	if actual_amount <= 0:
		return 0
	if not economy.spend_clean(actual_amount):
		return 0
	economy.add_dirty(actual_amount)
	_emit_atm_state_changed()
	return actual_amount

func _emit_atm_state_changed() -> void:
	atm_state_changed.emit(_atm_daily_deposited_dirty, max(ATM_DAILY_LIMIT - _atm_daily_deposited_dirty, 0), _atm_last_date_key)

func purchase_property(property_data: PropertyResource) -> bool:
	if is_property_owned(property_data.property_id):
		return false

	if economy.spend_dirty(property_data.purchase_price):
		var state: OwnedPropertyState = OwnedPropertyState.new()
		state.initialize(property_data)
		owned_properties[property_data.property_id] = state
		property_purchased.emit(state)
		return true

	return false

func get_property(id: StringName) -> OwnedPropertyState:
	if owned_properties.has(id):
		return owned_properties[id]
	return null

func is_property_owned(id: StringName) -> bool:
	return owned_properties.has(id)

func get_owned_properties() -> Array[OwnedPropertyState]:
	var out: Array[OwnedPropertyState] = []
	for item in owned_properties.values():
		if item is OwnedPropertyState:
			out.append(item)
	out.sort_custom(_sort_owned_properties_by_name)
	return out

func get_owned_stash_trap_properties() -> Array[OwnedPropertyState]:
	var out: Array[OwnedPropertyState] = []
	for property_state in get_owned_properties():
		if not property_state or not property_state.property_data:
			continue
		if property_state.property_data.property_type == PropertyResource.PropertyType.STASH_TRAP:
			out.append(property_state)
	return out

func _sort_owned_properties_by_name(a: OwnedPropertyState, b: OwnedPropertyState) -> bool:
	var a_name: String = ""
	var b_name: String = ""
	if a and a.property_data:
		a_name = a.property_data.display_name
	if b and b.property_data:
		b_name = b.property_data.display_name
	return a_name.naturalnocasecmp_to(b_name) < 0

func get_front_business_state(business_data: FrontBusinessResource) -> OwnedFrontBusinessState:
	if not business_data or business_data.business_id == &"":
		return null
	if owned_front_businesses.has(business_data.business_id):
		return owned_front_businesses[business_data.business_id]

	var state := OwnedFrontBusinessState.new()
	state.initialize(business_data)
	owned_front_businesses[business_data.business_id] = state
	return state

func purchase_front_business(business_data: FrontBusinessResource) -> bool:
	var state := get_front_business_state(business_data)
	if not state or state.is_purchased:
		return false
	if not economy.spend_clean(business_data.purchase_price):
		return false
	state.set_purchased(true)
	front_business_purchased.emit(state)
	return true

func is_front_business_purchased(business_id: StringName) -> bool:
	var state: OwnedFrontBusinessState = owned_front_businesses.get(business_id, null)
	return state != null and state.is_purchased

func get_gun_shop_stock_key(level: int) -> StringName:
	return StringName(GUN_SHOP_STOCK_KEYS.get(clampi(level, 1, 4), &""))

func get_gun_shop_stock_cost(level: int) -> int:
	return int(GUN_SHOP_STOCK_COSTS.get(clampi(level, 1, 4), 0))

func get_gun_shop_retail_price(level: int) -> int:
	return int(GUN_SHOP_RETAIL_PRICES.get(clampi(level, 1, 4), 0))

func buy_front_business_stock(business_data: FrontBusinessResource, level: int, amount: int = 1) -> bool:
	var state := get_front_business_state(business_data)
	if not state or not state.is_purchased:
		return false
	if amount <= 0:
		return false
	var stock_key: StringName = get_gun_shop_stock_key(level)
	var total_cost: int = get_gun_shop_stock_cost(level) * amount
	if stock_key == &"" or total_cost <= 0:
		return false
	if not economy.spend_clean(total_cost):
		return false
	state.add_stock(stock_key, amount)
	front_business_stock_changed.emit(business_data.business_id, stock_key, state.get_stock_amount(stock_key))
	return true

func complete_front_business_sale(business_data: FrontBusinessResource, level: int) -> bool:
	var state := get_front_business_state(business_data)
	if not state or not state.is_purchased:
		return false
	var stock_key: StringName = get_gun_shop_stock_key(level)
	if stock_key == &"":
		return false
	if not state.remove_stock(stock_key, 1):
		return false
	var payout: int = get_gun_shop_retail_price(level)
	economy.add_clean(payout)
	state.record_clean_earnings(payout)
	front_business_stock_changed.emit(business_data.business_id, stock_key, state.get_stock_amount(stock_key))
	front_business_sale_completed.emit(business_data.business_id, stock_key, payout)
	return true

func is_territory_controlled(territory_id: StringName) -> bool:
	return controlled_territory_ids.get(territory_id, false) == true

func set_territory_controlled(territory_id: StringName, controlled: bool) -> void:
	if territory_id == &"":
		return
	if controlled:
		if is_territory_controlled(territory_id):
			return
		controlled_territory_ids[territory_id] = true
		territory_control_changed.emit(territory_id, true)
		return

	if not is_territory_controlled(territory_id):
		return
	controlled_territory_ids.erase(territory_id)
	clear_hired_dealers(territory_id)
	clear_territory_support_property(territory_id)
	territory_control_changed.emit(territory_id, false)

func get_hired_dealer_slots(territory_id: StringName) -> Array[HiredDealerSlot]:
	if not hired_dealer_slots.has(territory_id):
		return []
	var raw: Array = hired_dealer_slots[territory_id]
	var out: Array[HiredDealerSlot] = []
	for item in raw:
		if item is HiredDealerSlot:
			out.append(item)
	return out

func hire_territory_dealer(territory_id: StringName, tier_level: int = 1) -> void:
	if not is_territory_controlled(territory_id):
		return
	var tier: int = clampi(tier_level, 1, 4)
	var slot := HiredDealerSlot.new()
	slot.tier_level = tier
	if not hired_dealer_slots.has(territory_id):
		hired_dealer_slots[territory_id] = []
	var arr: Array = hired_dealer_slots[territory_id]
	arr.append(slot)
	hired_dealers_changed.emit(territory_id)

func clear_hired_dealers(territory_id: StringName) -> void:
	if hired_dealer_slots.has(territory_id):
		hired_dealer_slots.erase(territory_id)
	hired_dealers_changed.emit(territory_id)

func get_territory_support_property_id(territory_id: StringName) -> StringName:
	return StringName(territory_support_properties.get(territory_id, &""))

func get_territory_support_property(territory_id: StringName) -> OwnedPropertyState:
	var property_id: StringName = get_territory_support_property_id(territory_id)
	if property_id == &"":
		return null
	return get_property(property_id)

func get_territory_support_stash(territory_id: StringName) -> StashInventory:
	var property_state: OwnedPropertyState = get_territory_support_property(territory_id)
	if property_state:
		return property_state.stash
	return null

func get_supported_territory_for_property(property_id: StringName) -> StringName:
	if property_id == &"":
		return &""
	for territory_id in territory_support_properties.keys():
		if territory_support_properties[territory_id] == property_id:
			return StringName(territory_id)
	return &""

func set_territory_support_property(territory_id: StringName, property_id: StringName) -> bool:
	if territory_id == &"" or property_id == &"":
		return false
	if not is_territory_controlled(territory_id):
		return false
	var property_state: OwnedPropertyState = get_property(property_id)
	if not property_state or not property_state.property_data:
		return false
	if property_state.property_data.property_type != PropertyResource.PropertyType.STASH_TRAP:
		return false

	for other_territory in territory_support_properties.keys():
		if other_territory == territory_id:
			continue
		if territory_support_properties[other_territory] == property_id:
			territory_support_properties.erase(other_territory)
			territory_support_property_changed.emit(StringName(other_territory), &"")

	territory_support_properties[territory_id] = property_id
	territory_support_property_changed.emit(territory_id, property_id)
	return true

func clear_territory_support_property(territory_id: StringName) -> void:
	if not territory_support_properties.has(territory_id):
		return
	territory_support_properties.erase(territory_id)
	territory_support_property_changed.emit(territory_id, &"")

func _stash_has_sellable_stock(stash: StashInventory) -> bool:
	if not stash:
		return false
	for amount in stash.drugs.values():
		if int(amount) > 0:
			return true
	for amount in stash.bricks.values():
		if int(amount) > 0:
			return true
	return false

func get_territory_support_status(territory_id: StringName) -> Dictionary:
	var controlled: bool = is_territory_controlled(territory_id)
	var property_state: OwnedPropertyState = get_territory_support_property(territory_id)
	var stash: StashInventory = null
	if property_state:
		stash = property_state.stash
	var hired_count: int = get_hired_dealer_slots(territory_id).size()
	var has_stock: bool = _stash_has_sellable_stock(stash)
	var is_productive: bool = controlled and stash != null and hired_count > 0 and has_stock
	var reason: String = "Operational"
	if not controlled:
		reason = "Territory uncontrolled"
	elif stash == null:
		reason = "No support stash linked"
	elif hired_count <= 0:
		reason = "No hired dealers assigned"
	elif not has_stock:
		reason = "Support stash has no sellable stock"

	var property_id: StringName = &""
	var property_name: String = "None"
	var stash_dirty_cash: int = 0
	if property_state and property_state.property_data:
		property_id = property_state.property_data.property_id
		property_name = property_state.property_data.display_name
	if stash:
		stash_dirty_cash = stash.dirty_cash

	return {
		"territory_id": territory_id,
		"controlled": controlled,
		"property_id": property_id,
		"property_name": property_name,
		"has_support_property": property_state != null,
		"hired_dealer_count": hired_count,
		"stash_dirty_cash": stash_dirty_cash,
		"has_sellable_stock": has_stock,
		"is_productive": is_productive,
		"reason": reason
	}

func collect_territory_support_cash(territory_id: StringName) -> int:
	if not is_territory_controlled(territory_id):
		return 0
	var stash: StashInventory = get_territory_support_stash(territory_id)
	if not stash:
		return 0
	var amount: int = stash.dirty_cash
	if amount <= 0:
		return 0
	if not stash.remove_dirty_cash(amount):
		return 0
	economy.add_dirty(amount)
	return amount

func get_territory_summary(territory_id: StringName) -> Dictionary:
	var support_status: Dictionary = get_territory_support_status(territory_id)
	return {
		"territory_id": territory_id,
		"controlled": is_territory_controlled(territory_id),
		"hired_dealer_count": get_hired_dealer_slots(territory_id).size(),
		"support_property_id": support_status.get("property_id", &""),
		"support_property_name": support_status.get("property_name", "None"),
		"support_stash_dirty_cash": support_status.get("stash_dirty_cash", 0),
		"support_productive": support_status.get("is_productive", false),
		"support_reason": support_status.get("reason", "")
	}

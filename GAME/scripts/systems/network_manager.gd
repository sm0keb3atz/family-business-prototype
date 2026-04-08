extends Node

## The global economy state — dirty money, clean money, and debt.
## This persists independently of the player node (survives death/respawn).
var economy: EconomyState = EconomyState.new()

## Active owned properties mapped by property_id -> OwnedPropertyState
var owned_properties: Dictionary = {}

## territory_id -> true when the player controls that territory (separate from property ownership).
var controlled_territory_ids: Dictionary = {}

## territory_id -> Array[HiredDealerSlot]; only used while territory is controlled.
var hired_dealer_slots: Dictionary = {}

## territory_id -> property_id for the canonical stash house supporting hired dealers.
var territory_support_properties: Dictionary = {}

## Emitted once the NetworkManager has finished initialization.
signal economy_ready

## Emitted when a property is successfully purchased
signal property_purchased(property_state: OwnedPropertyState)

signal territory_control_changed(territory_id: StringName, controlled: bool)
signal hired_dealers_changed(territory_id: StringName)
signal territory_support_property_changed(territory_id: StringName, property_id: StringName)

func _ready() -> void:
	# Starting cash — the player begins with $1000 dirty money
	economy.dirty_money = 1000
	economy_ready.emit()

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
	var a_name: String = a.property_data.display_name if a and a.property_data else ""
	var b_name: String = b.property_data.display_name if b and b.property_data else ""
	return a_name.naturalnocasecmp_to(b_name) < 0

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
	var stash: StashInventory = property_state.stash if property_state else null
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

	return {
		"territory_id": territory_id,
		"controlled": controlled,
		"property_id": property_state.property_data.property_id if property_state and property_state.property_data else &"",
		"property_name": property_state.property_data.display_name if property_state and property_state.property_data else "None",
		"has_support_property": property_state != null,
		"hired_dealer_count": hired_count,
		"stash_dirty_cash": stash.dirty_cash if stash else 0,
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

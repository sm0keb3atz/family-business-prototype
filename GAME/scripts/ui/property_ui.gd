extends CanvasLayer
class_name PropertyUI

@onready var title_label: Label = %TitleLabel
@onready var capacity_label: Label = %CapacityLabel
@onready var capacity_bar: ProgressBar = %CapacityBar
@onready var dirty_cash_label: Label = %DirtyCashLabel
@onready var stash_cash_label: Label = %StashCashLabel
@onready var support_role_label: Label = %SupportRoleLabel
@onready var linked_territory_label: Label = %LinkedTerritoryLabel
@onready var support_status_label: Label = %SupportStatusLabel

@onready var player_drug_list: VBoxContainer = %PlayerDrugList
@onready var stash_drug_list: VBoxContainer = %StashDrugList

@onready var deposit_cash_btn: Button = %DepositCashBtn
@onready var withdraw_cash_btn: Button = %WithdrawCashBtn
@onready var deposit_all_cash_btn: Button = %DepositAllCashBtn
@onready var quick_stash_btn: Button = %QuickStashBtn

@onready var transfer_amount_spinbox: SpinBox = %TransferAmountSpinBox
@onready var close_btn: Button = %CloseBtn

var current_property: OwnedPropertyState
var player_inventory: InventoryComponent
var _connected_stash: StashInventory
var _connected_player_inventory: InventoryComponent

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	close_btn.pressed.connect(close)

	deposit_cash_btn.pressed.connect(_on_deposit_cash)
	withdraw_cash_btn.pressed.connect(_on_withdraw_cash)
	deposit_all_cash_btn.pressed.connect(_on_deposit_all_cash)
	quick_stash_btn.pressed.connect(_on_quick_stash)

func open(property_state: OwnedPropertyState, inventory: InventoryComponent) -> void:
	_disconnect_runtime_signals()
	current_property = property_state
	player_inventory = inventory
	_connect_runtime_signals()

	_update_ui()
	layer = 120
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	show()

func close() -> void:
	_disconnect_runtime_signals()

	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.set("_is_interacting", false)

	hide()

func _connect_runtime_signals() -> void:
	if current_property and current_property.stash:
		_connected_stash = current_property.stash
		if not _connected_stash.stash_changed.is_connected(_update_ui):
			_connected_stash.stash_changed.connect(_update_ui)
	if player_inventory:
		_connected_player_inventory = player_inventory
		if not _connected_player_inventory.inventory_changed.is_connected(_update_ui):
			_connected_player_inventory.inventory_changed.connect(_update_ui)
	if NetworkManager and NetworkManager.economy and not NetworkManager.economy.dirty_money_changed.is_connected(_on_economy_changed):
		NetworkManager.economy.dirty_money_changed.connect(_on_economy_changed)
	if not NetworkManager.territory_support_property_changed.is_connected(_on_support_mapping_changed):
		NetworkManager.territory_support_property_changed.connect(_on_support_mapping_changed)
	if not NetworkManager.territory_control_changed.is_connected(_on_territory_runtime_changed):
		NetworkManager.territory_control_changed.connect(_on_territory_runtime_changed)
	if not NetworkManager.hired_dealers_changed.is_connected(_on_hired_dealers_changed):
		NetworkManager.hired_dealers_changed.connect(_on_hired_dealers_changed)

func _disconnect_runtime_signals() -> void:
	if _connected_stash and _connected_stash.stash_changed.is_connected(_update_ui):
		_connected_stash.stash_changed.disconnect(_update_ui)
	if _connected_player_inventory and _connected_player_inventory.inventory_changed.is_connected(_update_ui):
		_connected_player_inventory.inventory_changed.disconnect(_update_ui)
	if NetworkManager and NetworkManager.economy and NetworkManager.economy.dirty_money_changed.is_connected(_on_economy_changed):
		NetworkManager.economy.dirty_money_changed.disconnect(_on_economy_changed)
	if NetworkManager.territory_support_property_changed.is_connected(_on_support_mapping_changed):
		NetworkManager.territory_support_property_changed.disconnect(_on_support_mapping_changed)
	if NetworkManager.territory_control_changed.is_connected(_on_territory_runtime_changed):
		NetworkManager.territory_control_changed.disconnect(_on_territory_runtime_changed)
	if NetworkManager.hired_dealers_changed.is_connected(_on_hired_dealers_changed):
		NetworkManager.hired_dealers_changed.disconnect(_on_hired_dealers_changed)
	_connected_stash = null
	_connected_player_inventory = null

func _on_economy_changed(_amount: int) -> void:
	_update_ui()

func _on_support_mapping_changed(_territory_id: StringName, _property_id: StringName) -> void:
	_update_ui()

func _on_territory_runtime_changed(_territory_id: StringName, _controlled: bool) -> void:
	_update_ui()

func _on_hired_dealers_changed(_territory_id: StringName) -> void:
	_update_ui()

func _update_ui() -> void:
	if not current_property:
		return

	title_label.text = current_property.property_data.display_name

	var stash := current_property.stash
	var used := stash.get_used_capacity()
	var cap := stash.capacity

	capacity_label.text = "Capacity: %d / %d" % [used, cap]
	capacity_bar.max_value = cap
	capacity_bar.value = used

	stash_cash_label.text = "$%d" % stash.dirty_cash

	if NetworkManager and NetworkManager.economy:
		dirty_cash_label.text = "$%d" % NetworkManager.economy.dirty_money

	_update_support_labels()

	for child in player_drug_list.get_children():
		child.queue_free()
	for child in stash_drug_list.get_children():
		child.queue_free()

	if player_inventory:
		for drug_id in player_inventory.drugs.keys():
			player_drug_list.add_child(_create_player_row(drug_id, player_inventory.drugs[drug_id], false))
		for drug_id in player_inventory.bricks.keys():
			player_drug_list.add_child(_create_player_row(drug_id, player_inventory.bricks[drug_id], true))

	for drug_id in stash.drugs.keys():
		stash_drug_list.add_child(_create_stash_row(drug_id, stash.drugs[drug_id], false))
	for drug_id in stash.bricks.keys():
		stash_drug_list.add_child(_create_stash_row(drug_id, stash.bricks[drug_id], true))

func _update_support_labels() -> void:
	var property_id: StringName = current_property.property_data.property_id if current_property and current_property.property_data else &""
	var supported_territory_id: StringName = NetworkManager.get_supported_territory_for_property(property_id)
	if supported_territory_id == &"":
		support_role_label.text = "Support Role: Not assigned as a territory hub"
		linked_territory_label.text = "Linked Territory: None"
		support_status_label.text = "Dealer Support: Idle"
		return

	var status: Dictionary = NetworkManager.get_territory_support_status(supported_territory_id)
	support_role_label.text = "Support Role: Active support stash"
	linked_territory_label.text = "Linked Territory: %s" % String(supported_territory_id)
	if bool(status.get("is_productive", false)):
		support_status_label.text = "Dealer Support: Productive | Cash: $%d" % int(status.get("stash_dirty_cash", 0))
	else:
		support_status_label.text = "Dealer Support: %s" % String(status.get("reason", "Blocked"))

func _create_player_row(drug_id: StringName, amount: int, is_brick: bool) -> HBoxContainer:
	var row = HBoxContainer.new()
	var lbl = Label.new()
	lbl.text = ("[Brick] " if is_brick else "") + "%s: %d" % [str(drug_id).capitalize(), amount] + ("" if is_brick else "g")
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var btn = Button.new()
	btn.text = "Deposit"
	btn.pressed.connect(func(): _on_deposit_drug(drug_id, is_brick, false))

	var btn_all = Button.new()
	btn_all.text = "All"
	btn_all.pressed.connect(func(): _on_deposit_drug(drug_id, is_brick, true))

	row.add_child(lbl)
	row.add_child(btn)
	row.add_child(btn_all)
	return row

func _create_stash_row(drug_id: StringName, amount: int, is_brick: bool) -> HBoxContainer:
	var row = HBoxContainer.new()
	var lbl = Label.new()
	lbl.text = ("[Brick] " if is_brick else "") + "%s: %d" % [str(drug_id).capitalize(), amount] + ("" if is_brick else "g")
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var btn = Button.new()
	btn.text = "Withdraw"
	btn.pressed.connect(func(): _on_withdraw_drug(drug_id, is_brick, false))

	var btn_all = Button.new()
	btn_all.text = "All"
	btn_all.pressed.connect(func(): _on_withdraw_drug(drug_id, is_brick, true))

	row.add_child(lbl)
	row.add_child(btn)
	row.add_child(btn_all)
	return row

func _on_deposit_drug(drug_id: StringName, is_brick: bool, all: bool) -> void:
	if not player_inventory or not current_property:
		return
	var stash = current_property.stash

	var qty_owned = player_inventory.bricks.get(drug_id, 0) if is_brick else player_inventory.drugs.get(drug_id, 0)
	if qty_owned <= 0:
		return

	var req_amount = qty_owned if all else int(transfer_amount_spinbox.value)
	var unit_weight = 100 if is_brick else 1
	var free_space = stash.get_free_capacity()

	var max_affordable_units = free_space / unit_weight
	var actual_amount = clampi(req_amount, 0, min(qty_owned, max_affordable_units))

	if actual_amount > 0:
		if is_brick:
			player_inventory.remove_brick(drug_id, actual_amount)
			stash.add_brick(drug_id, actual_amount)
		else:
			player_inventory.remove_drug(drug_id, actual_amount)
			stash.add_drug(drug_id, actual_amount)

func _on_withdraw_drug(drug_id: StringName, is_brick: bool, all: bool) -> void:
	if not current_property:
		return
	var stash = current_property.stash
	var qty_owned = stash.bricks.get(drug_id, 0) if is_brick else stash.drugs.get(drug_id, 0)
	if qty_owned <= 0:
		return

	var req_amount = qty_owned if all else int(transfer_amount_spinbox.value)
	var actual_amount = min(req_amount, qty_owned)

	if actual_amount > 0:
		if is_brick:
			stash.remove_brick(drug_id, actual_amount)
			player_inventory.add_brick(drug_id, actual_amount)
		else:
			stash.remove_drug(drug_id, actual_amount)
			player_inventory.add_drug(drug_id, actual_amount)

func _on_deposit_cash() -> void:
	var amount = int(transfer_amount_spinbox.value)
	if NetworkManager and NetworkManager.economy.dirty_money >= amount:
		NetworkManager.economy.spend_dirty(amount)
		current_property.stash.add_dirty_cash(amount)

func _on_deposit_all_cash() -> void:
	if NetworkManager:
		var all_cash = NetworkManager.economy.dirty_money
		if all_cash > 0:
			NetworkManager.economy.spend_dirty(all_cash)
			current_property.stash.add_dirty_cash(all_cash)

func _on_withdraw_cash() -> void:
	var amount = int(transfer_amount_spinbox.value)
	if current_property.stash.remove_dirty_cash(amount):
		if NetworkManager:
			NetworkManager.economy.add_dirty(amount)

func _on_quick_stash() -> void:
	if not player_inventory or not current_property:
		return
	_on_deposit_all_cash()
	var p_bricks = player_inventory.bricks.keys()
	for drug_id in p_bricks:
		_on_deposit_drug(drug_id, true, true)
	var p_drugs = player_inventory.drugs.keys()
	for drug_id in p_drugs:
		_on_deposit_drug(drug_id, false, true)

extends CanvasLayer
class_name GunShopUI

const GLOCK_LEVEL_LABELS := {
	1: "Glock Lv1",
	2: "Glock Lv2",
	3: "Glock Lv3",
	4: "Glock Lv4"
}

var GUN_CARD_SCENE: PackedScene
const GLOCK_ICONS := {
	1: preload("res://GAME/assets/sprites/weapons/pistol/glocklv1.png"),
	2: preload("res://GAME/assets/sprites/weapons/pistol/glocklv2.png"),
	3: preload("res://GAME/assets/sprites/weapons/pistol/glocklv3.png"),
	4: preload("res://GAME/assets/sprites/weapons/pistol/glocklv4.png")
}

@onready var panel: Control = $Control
@onready var title_label: Label = %TitleLabel
@onready var business_button: Button = %BuyBusinessButton
@onready var business_status_label: Label = %BusinessStatusLabel
@onready var clean_money_label: Label = %CleanMoneyLabel
@onready var tabs: TabContainer = %Tabs
@onready var gun_cards_list: VBoxContainer = %GunCardsList
@onready var gun_info_label: RichTextLabel = %GunInfoLabel
@onready var gun_action_hint_label: Label = %GunActionHintLabel
@onready var stock_status_label: Label = %StockStatusLabel
@onready var stock_list: VBoxContainer = %StockList
@onready var close_button: Button = %CloseButton

var _player: Player
var _business_data: FrontBusinessResource
var _selected_level: int = 1

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	GUN_CARD_SCENE = load("res://GAME/scenes/ui/gun_shop_card.tscn")
	if not GUN_CARD_SCENE:
		push_error("Failed to load res://GAME/scenes/ui/gun_shop_card.tscn")
	
	close_button.pressed.connect(close)
	business_button.pressed.connect(_on_buy_business_pressed)
	if not NetworkManager.front_business_purchased.is_connected(_on_business_runtime_changed):
		NetworkManager.front_business_purchased.connect(_on_business_runtime_changed)
	if not NetworkManager.front_business_stock_changed.is_connected(_on_front_business_stock_changed):
		NetworkManager.front_business_stock_changed.connect(_on_front_business_stock_changed)
	if not NetworkManager.front_business_sale_completed.is_connected(_on_front_business_sale_completed):
		NetworkManager.front_business_sale_completed.connect(_on_front_business_sale_completed)
	if not NetworkManager.economy.clean_money_changed.is_connected(_on_clean_money_changed):
		NetworkManager.economy.clean_money_changed.connect(_on_clean_money_changed)

func open(player: Player, business_data: FrontBusinessResource) -> void:
	_player = player
	_business_data = business_data
	_selected_level = max(1, player.get_owned_glock_level())
	layer = 120
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	show()
	_refresh_ui()
	AudioManager.play_ui_menu()

func close() -> void:
	hide()
	if _player:
		_player._is_interacting = false

func _on_buy_business_pressed() -> void:
	if not _business_data:
		return
	if NetworkManager.purchase_front_business(_business_data):
		AudioManager.play_transaction()
	_refresh_ui()

func _on_gun_action_pressed(level: int) -> void:
	if not _player:
		return
	if _player.purchase_or_upgrade_glock(level):
		AudioManager.play_transaction()
		_selected_level = level
	_refresh_ui()

func _on_buy_stock_pressed(level: int) -> void:
	if not _business_data:
		return
	if NetworkManager.buy_front_business_stock(_business_data, level, 1):
		AudioManager.play_transaction()
	_refresh_ui()

func _on_business_runtime_changed(_state: OwnedFrontBusinessState) -> void:
	_refresh_ui()

func _on_front_business_stock_changed(_business_id: StringName, _stock_key: StringName, _new_amount: int) -> void:
	_refresh_ui()

func _on_front_business_sale_completed(_business_id: StringName, _stock_key: StringName, _clean_amount: int) -> void:
	_refresh_ui()

func _on_clean_money_changed(_new_amount: int) -> void:
	_refresh_ui()

func _refresh_ui() -> void:
	if not is_node_ready() or not _business_data:
		return
	var business_state := NetworkManager.get_front_business_state(_business_data)
	var is_purchased: bool = business_state != null and business_state.is_purchased
	title_label.text = _business_data.display_name.to_upper()
	clean_money_label.text = "CLEAN: $%d" % NetworkManager.economy.clean_money
	if is_purchased:
		business_status_label.text = "BUSINESS: OWNED"
	else:
		business_status_label.text = "BUSINESS: NOT OWNED"
	business_button.visible = not is_purchased
	business_button.text = "BUY BUSINESS ($%d CLEAN)" % _business_data.purchase_price
	business_button.disabled = is_purchased or NetworkManager.economy.clean_money < _business_data.purchase_price
	tabs.set_tab_disabled(1, not is_purchased)
	if not is_purchased and tabs.current_tab == 1:
		tabs.current_tab = 0
	_build_gun_cards()
	_refresh_gun_info()
	_build_stock_rows(business_state)

func _build_gun_cards() -> void:
	for child in gun_cards_list.get_children():
		child.queue_free()
	
	var owned_level: int = _player.get_owned_glock_level()
	var clean_money = NetworkManager.economy.clean_money
	
	# Only one glock card that shows the NEXT level to purchase/upgrade
	var display_level: int = 1
	if owned_level > 0:
		display_level = clampi(owned_level + 1, 1, 4) if owned_level < 4 else 4
	
	var card = GUN_CARD_SCENE.instantiate()
	gun_cards_list.add_child(card)
	
	var cost = _player.get_glock_purchase_cost(display_level)
	var can_afford = clean_money >= cost
	
	card.setup(display_level, GLOCK_LEVEL_LABELS[display_level], GLOCK_ICONS[display_level], owned_level, cost, can_afford)
	card.selected.connect(_on_select_level)
	card.action_pressed.connect(_on_gun_action_pressed)
	
	# Select it by default
	_selected_level = display_level

func _on_select_level(level: int) -> void:
	_selected_level = clampi(level, 1, 4)
	_refresh_gun_info()

func _refresh_gun_info() -> void:
	if not _player:
		return
	var weapon_data: WeaponDataResource = _player.glock_weapon_data_by_level.get(_selected_level, null)
	var owned_level: int = _player.get_owned_glock_level()
	var hint_text := "Buy Glock Lv1 first."
	
	if owned_level <= 0:
		if _selected_level == 1:
			hint_text = "This becomes your first personal Glock."
	elif _selected_level == owned_level:
		hint_text = "Current equipped Glock level."
	elif _selected_level == owned_level + 1:
		hint_text = "Upgrades replace your current Glock."
	elif _selected_level < owned_level:
		hint_text = "Already surpassed this level."
	else:
		hint_text = "Upgrade in order, one Glock level at a time."
		
	gun_action_hint_label.text = hint_text
	
	if weapon_data:
		gun_info_label.text = "[ %s ]\n\nDamage: %d\nFire Rate: %.2f\nReload: %.2fs\nMagazine: %d\nSpread: %.2f" % [
			GLOCK_LEVEL_LABELS[_selected_level].to_upper(),
			weapon_data.damage,
			weapon_data.fire_rate,
			weapon_data.reload_time,
			weapon_data.magazine_size,
			weapon_data.spread_degrees
		]
	else:
		gun_info_label.text = GLOCK_LEVEL_LABELS[_selected_level]

func _build_stock_rows(business_state: OwnedFrontBusinessState) -> void:
	for child in stock_list.get_children():
		child.queue_free()
	if not business_state or not business_state.is_purchased:
		stock_status_label.text = "Buy the business with clean money to unlock stock and customer sales."
		return
	var total_stock: int = 0
	for level in range(1, 5):
		total_stock += business_state.get_stock_amount(NetworkManager.get_gun_shop_stock_key(level))
	if total_stock <= 0:
		stock_status_label.text = "Total Clean Earnings: $%d | Status: No stock for customers." % business_state.total_clean_earnings
	else:
		stock_status_label.text = "Total Clean Earnings: $%d | Status: Selling from live stock." % business_state.total_clean_earnings
	for level in range(1, 5):
		var stock_key: StringName = NetworkManager.get_gun_shop_stock_key(level)
		var row := HBoxContainer.new()
		var label := Label.new()
		label.text = "%s Stock: %d" % [GLOCK_LEVEL_LABELS[level], business_state.get_stock_amount(stock_key)]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var buy_button := Button.new()
		buy_button.text = "Buy Stock ($%d)" % NetworkManager.get_gun_shop_stock_cost(level)
		buy_button.disabled = NetworkManager.economy.clean_money < NetworkManager.get_gun_shop_stock_cost(level)
		buy_button.pressed.connect(_on_buy_stock_pressed.bind(level))
		row.add_child(buy_button)
		stock_list.add_child(row)

extends CanvasLayer
class_name ShopUI

@onready var main_control: Control = $Control
@onready var dealer_name_label: Label = %DealerNameLabel
@onready var stock_label: Label = %StockLabel
@onready var drug_name_label: Label = %DrugNameLabel
@onready var price_label: Label = %PriceLabel
@onready var drug_selector: OptionButton = %DrugSelector
@onready var stock_summary_label: Label = %StockSummaryLabel
@onready var error_label: Label = %ErrorLabel

@onready var btn_5g: Button = %Btn5g
@onready var btn_10g: Button = %Btn10g
@onready var btn_20g: Button = %Btn20g
@onready var btn_max: Button = %BtnMax
@onready var close_btn: Button = %CloseBtn

var current_dealer: DealerShopComponent
var current_player: Node2D
var selected_drug_id: StringName = &""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	main_control.hide()
	
	btn_5g.pressed.connect(func(): _attempt_buy(5))
	btn_10g.pressed.connect(func(): _attempt_buy(10))
	btn_20g.pressed.connect(func(): _attempt_buy(20))
	btn_max.pressed.connect(_on_buy_max)
	close_btn.pressed.connect(close_shop)
	drug_selector.item_selected.connect(_on_drug_selected)

func open_shop(dealer: DealerShopComponent, player: Node2D) -> void:
	current_dealer = dealer
	current_player = player
	selected_drug_id = dealer.get_current_drug_id()
	layer = 120 # Ensure it's above HUD
	main_control.show()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	error_label.text = ""
	_refresh_ui()
	AudioManager.play_ui_menu()

func close_shop() -> void:
	main_control.hide()
	var dealer_npc: NPC = null
	if current_dealer:
		dealer_npc = current_dealer.get_parent() as NPC
	if current_player:
		current_player._is_interacting = false
		if dealer_npc and current_player.current_interactable == dealer_npc:
			current_player.current_interactable = null
	if dealer_npc:
		dealer_npc._is_interacting = false
		if dealer_npc.blackboard:
			dealer_npc.blackboard.set_var(&"is_interacting", false)
	current_dealer = null
	current_player = null
	AudioManager.play_ui_menu()

func _process(_delta: float) -> void:
	if main_control.visible and current_dealer:
		_refresh_ui()

func _refresh_ui() -> void:
	var tier = current_dealer.get("tier_config")
	var drug_ids := current_dealer.get_available_drug_ids()
	_rebuild_selector(drug_ids)
	if selected_drug_id == &"" and not drug_ids.is_empty():
		selected_drug_id = drug_ids[0]
	current_dealer.select_drug(selected_drug_id)
	var drug: DrugDefinitionResource = DrugCatalog.get_definition(selected_drug_id)
	if not tier or not drug:
		return
	
	dealer_name_label.text = current_dealer.get("dealer_name") + " (Tier " + str(tier.get("tier_level")) + ")"
	stock_summary_label.text = _build_stock_summary(drug_ids)
	
	var drug_id = drug.id
	var price = current_dealer.get_price(drug_id, current_player)
	var is_brick_tier = current_dealer.is_brick_stock_for(drug_id)
	var brick_grams := current_dealer.get_brick_grams_for(drug_id)
	var current_stock := current_dealer.get_stock_amount(drug_id)
	
	if is_brick_tier:
		var brick_count = current_dealer.get_brick_count_for(drug_id)
		stock_label.text = "Stock: " + str(brick_count) + " bricks"
		drug_name_label.text = drug.get("display_name") + " Bricks"
		price_label.text = "$" + str(price * brick_grams) + " / brick"
		
		btn_5g.text = "Buy 1 Brick"
		btn_10g.text = "Buy 2 Bricks"
		btn_20g.text = "Buy 5 Bricks"
	else:
		stock_label.text = "Stock: " + str(current_stock) + "g"
		drug_name_label.text = drug.get("display_name")
		price_label.text = "$" + str(price) + " / g"
		
		btn_5g.text = "Buy 5g"
		btn_10g.text = "Buy 10g"
		btn_20g.text = "Buy 20g"
	
	# Update button states
	var player_money: int = NetworkManager.economy.dirty_money
	if is_brick_tier:
		btn_5g.disabled = current_stock < brick_grams or player_money < price * brick_grams
		btn_10g.disabled = current_stock < (2 * brick_grams) or player_money < price * (2 * brick_grams)
		btn_20g.disabled = current_stock < (5 * brick_grams) or player_money < price * (5 * brick_grams)
	else:
		btn_5g.disabled = current_stock < 5 or player_money < 5 * price
		btn_10g.disabled = current_stock < 10 or player_money < 10 * price
		btn_20g.disabled = current_stock < 20 or player_money < 20 * price
	
	var divisor = brick_grams if is_brick_tier else 1
	var max_affordable = floor(player_money / (price * divisor))
	var max_buyable = min(max_affordable, current_stock / divisor)
	btn_max.disabled = max_buyable <= 0

func _attempt_buy(amount: int) -> void:
	var tier = current_dealer.get("tier_config")
	var drug: DrugDefinitionResource = DrugCatalog.get_definition(selected_drug_id)
	if not tier or not drug:
		return
	
	var price = current_dealer.get_price(drug.id, current_player)
	var is_brick_tier = current_dealer.is_brick_stock_for(drug.id)
	var brick_grams := current_dealer.get_brick_grams_for(drug.id)
	
	var actual_gram_amount = amount
	var cost = 0
	
	if is_brick_tier:
		# Map btn presses to brick counts: 5->1, 10->2, 20->5
		var brick_count = 1
		match amount:
			5: brick_count = 1
			10: brick_count = 2
			20: brick_count = 5
		actual_gram_amount = brick_count * brick_grams
		cost = brick_count * price * brick_grams
	else:
		cost = amount * price
	
	if NetworkManager.economy.dirty_money < cost:
		error_label.text = "Not enough money!"
		return
	if not current_dealer.can_buy_drug(drug.id, actual_gram_amount):
		error_label.text = "Dealer out of stock!"
		return
		
	current_dealer.buy_drug(drug.id, actual_gram_amount)
	NetworkManager.economy.spend_dirty(cost)
	
	if is_brick_tier:
		current_player.get("inventory_component").add_brick(drug.id, int(actual_gram_amount / brick_grams))
	else:
		current_player.get("inventory_component").add_drug(drug.id, actual_gram_amount)
	
	# Audio Feedback
	AudioManager.play_transaction()
	
	var pui = current_player.get("player_ui")
	if pui:
		pui.spawn_indicator("money_down", "-$" + str(cost))
		var label_text = "+" + str(int(actual_gram_amount / brick_grams)) + " brick" if is_brick_tier else "+" + str(actual_gram_amount) + "g"
		pui.spawn_indicator("product", label_text, DrugCatalog.get_product_icon(drug.id, is_brick_tier))
		
	error_label.text = "Bought " + drug.display_name + "!"
	_refresh_ui()

func _on_buy_max() -> void:
	var tier = current_dealer.get("tier_config")
	var drug: DrugDefinitionResource = DrugCatalog.get_definition(selected_drug_id)
	if not tier or not drug:
		return
	
	var price = current_dealer.get_price(drug.id, current_player)
	var is_brick_tier = current_dealer.is_brick_stock_for(drug.id)
	var divisor = current_dealer.get_brick_grams_for(drug.id) if is_brick_tier else 1
	var current_stock := current_dealer.get_stock_amount(drug.id)
	
	var max_affordable = floor(NetworkManager.economy.dirty_money / (price * divisor))
	var max_buyable = min(max_affordable, current_stock / divisor)
	
	if max_buyable > 0:
		var gram_amount = max_buyable * divisor
		var total_cost = max_buyable * price * divisor
		
		current_dealer.buy_drug(drug.id, gram_amount)
		NetworkManager.economy.spend_dirty(total_cost)
		
		if is_brick_tier:
			current_player.get("inventory_component").add_brick(drug.id, int(max_buyable))
		else:
			current_player.get("inventory_component").add_drug(drug.id, gram_amount)
		
		# Audio/UI Feedback
		AudioManager.play_transaction()
		var pui = current_player.get("player_ui")
		if pui:
			pui.spawn_indicator("money_down", "-$" + str(total_cost))
			var label_text = "+" + str(int(max_buyable)) + " brick" if is_brick_tier else "+" + str(gram_amount) + "g"
			pui.spawn_indicator("product", label_text, DrugCatalog.get_product_icon(drug.id, is_brick_tier))
		
		error_label.text = "Bought MAX!"
		_refresh_ui()

func _rebuild_selector(drug_ids: Array[StringName]) -> void:
	var previous_selection := selected_drug_id
	var matched_previous := false
	drug_selector.clear()
	for i in range(drug_ids.size()):
		var drug_id := drug_ids[i]
		var definition := DrugCatalog.get_definition(drug_id)
		var label := definition.display_name if definition else String(drug_id).capitalize()
		drug_selector.add_item(label)
		drug_selector.set_item_metadata(i, String(drug_id))
		if drug_id == previous_selection:
			drug_selector.select(i)
			matched_previous = true
	if drug_selector.item_count > 1:
		if not matched_previous:
			drug_selector.select(0)
			selected_drug_id = StringName(drug_selector.get_item_metadata(0))
		drug_selector.visible = true
	elif drug_selector.item_count == 1:
		drug_selector.select(0)
		selected_drug_id = StringName(drug_selector.get_item_metadata(0))
		drug_selector.visible = false
	else:
		drug_selector.visible = false

func _build_stock_summary(drug_ids: Array[StringName]) -> String:
	var lines: Array[String] = []
	for drug_id in drug_ids:
		var definition := DrugCatalog.get_definition(drug_id)
		var display_name := definition.display_name if definition else String(drug_id).capitalize()
		if current_dealer.is_brick_stock_for(drug_id):
			lines.append("%s: %d brick(s)" % [display_name, current_dealer.get_brick_count_for(drug_id)])
		else:
			lines.append("%s: %dg" % [display_name, current_dealer.get_stock_amount(drug_id)])
	return "\n".join(lines)

func _on_drug_selected(index: int) -> void:
	if index < 0 or index >= drug_selector.item_count:
		return
	selected_drug_id = StringName(drug_selector.get_item_metadata(index))
	_refresh_ui()

extends CanvasLayer
class_name ShopUI

@onready var main_control: Control = $Control
@onready var dealer_name_label: Label = %DealerNameLabel
@onready var stock_label: Label = %StockLabel
@onready var drug_name_label: Label = %DrugNameLabel
@onready var price_label: Label = %PriceLabel
@onready var error_label: Label = %ErrorLabel

@onready var btn_5g: Button = %Btn5g
@onready var btn_10g: Button = %Btn10g
@onready var btn_20g: Button = %Btn20g
@onready var btn_max: Button = %BtnMax
@onready var close_btn: Button = %CloseBtn

var current_dealer: DealerShopComponent
var current_player: Player

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	main_control.hide()
	
	btn_5g.pressed.connect(func(): _attempt_buy(5))
	btn_10g.pressed.connect(func(): _attempt_buy(10))
	btn_20g.pressed.connect(func(): _attempt_buy(20))
	btn_max.pressed.connect(_on_buy_max)
	close_btn.pressed.connect(close_shop)

func open_shop(dealer: DealerShopComponent, player: Player) -> void:
	current_dealer = dealer
	current_player = player
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
	var tier = current_dealer.tier_config
	if not tier or tier.allowed_drugs.is_empty(): return
	var drug = tier.allowed_drugs[0]
	
	dealer_name_label.text = current_dealer.dealer_name + " (Level " + str(tier.tier_level) + ")"
	
	var drug_id = drug.id
	var price = current_dealer.get_price(drug_id)
	var is_brick_tier = (tier.tier_level == 4)
	
	if is_brick_tier:
		var brick_count = int(current_dealer.current_stock / 100)
		stock_label.text = "Stock: " + str(brick_count) + " bricks"
		drug_name_label.text = drug.display_name + " Bricks"
		price_label.text = "$" + str(price * 100) + " / brick"
		
		btn_5g.text = "Buy 1 Brick"
		btn_10g.text = "Buy 2 Bricks"
		btn_20g.text = "Buy 5 Bricks"
	else:
		stock_label.text = "Stock: " + str(current_dealer.current_stock) + "g"
		drug_name_label.text = drug.display_name
		price_label.text = "$" + str(price) + " / g"
		
		btn_5g.text = "Buy 5g"
		btn_10g.text = "Buy 10g"
		btn_20g.text = "Buy 20g"
	
	# Update button states
	var player_money = current_player.progression.money
	if is_brick_tier:
		btn_5g.disabled = current_dealer.current_stock < 100 or player_money < price * 100
		btn_10g.disabled = current_dealer.current_stock < 200 or player_money < price * 200
		btn_20g.disabled = current_dealer.current_stock < 500 or player_money < price * 500
	else:
		btn_5g.disabled = current_dealer.current_stock < 5 or player_money < 5 * price
		btn_10g.disabled = current_dealer.current_stock < 10 or player_money < 10 * price
		btn_20g.disabled = current_dealer.current_stock < 20 or player_money < 20 * price
	
	var divisor = 100 if is_brick_tier else 1
	var max_affordable = floor(player_money / (price * divisor))
	var max_buyable = min(max_affordable, current_dealer.current_stock / divisor)
	btn_max.disabled = max_buyable <= 0

func _attempt_buy(amount: int) -> void:
	var tier = current_dealer.tier_config
	if not tier or tier.allowed_drugs.is_empty(): return
	var drug = tier.allowed_drugs[0]
	
	var price = current_dealer.get_price(drug.id)
	var is_brick_tier = (tier.tier_level == 4)
	
	var actual_gram_amount = amount
	var cost = 0
	
	if is_brick_tier:
		# Map btn presses to brick counts: 5->1, 10->2, 20->5
		var brick_count = 1
		match amount:
			5: brick_count = 1
			10: brick_count = 2
			20: brick_count = 5
		actual_gram_amount = brick_count * 100
		cost = brick_count * price * 100
	else:
		cost = amount * price
	
	if current_player.progression.money < cost:
		error_label.text = "Not enough money!"
		return
	if not current_dealer.can_buy(actual_gram_amount):
		error_label.text = "Dealer out of stock!"
		return
		
	current_dealer.buy(actual_gram_amount)
	current_player.progression.money -= cost
	
	if is_brick_tier:
		current_player.inventory_component.add_brick(drug.id, int(actual_gram_amount / 100))
	else:
		current_player.inventory_component.add_drug(drug.id, actual_gram_amount)
	
	# Audio Feedback
	AudioManager.play_transaction()
	
	var pui = current_player.get("player_ui")
	if pui:
		pui.spawn_indicator("money_down", "-$" + str(cost))
		var label_text = "+" + str(int(actual_gram_amount/100)) + " brick" if is_brick_tier else "+" + str(actual_gram_amount) + "g"
		pui.spawn_indicator("product", label_text)
		
	error_label.text = "Bought " + drug.display_name + "!"
	_refresh_ui()

func _on_buy_max() -> void:
	var tier = current_dealer.tier_config
	if not tier or tier.allowed_drugs.is_empty(): return
	var drug = tier.allowed_drugs[0]
	
	var price = current_dealer.get_price(drug.id)
	var is_brick_tier = (tier.tier_level == 4)
	var divisor = 100 if is_brick_tier else 1
	
	var max_affordable = floor(current_player.progression.money / (price * divisor))
	var max_buyable = min(max_affordable, current_dealer.current_stock / divisor)
	
	if max_buyable > 0:
		var gram_amount = max_buyable * divisor
		var total_cost = max_buyable * price * divisor
		
		current_dealer.buy(gram_amount)
		current_player.progression.money -= total_cost
		
		if is_brick_tier:
			current_player.inventory_component.add_brick(drug.id, int(max_buyable))
		else:
			current_player.inventory_component.add_drug(drug.id, gram_amount)
		
		# Audio/UI Feedback
		AudioManager.play_transaction()
		var pui = current_player.get("player_ui")
		if pui:
			pui.spawn_indicator("money_down", "-$" + str(total_cost))
			var label_text = "+" + str(int(max_buyable)) + " brick" if is_brick_tier else "+" + str(gram_amount) + "g"
			pui.spawn_indicator("product", label_text)
		
		error_label.text = "Bought MAX!"
		_refresh_ui()

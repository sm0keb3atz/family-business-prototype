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
	stock_label.text = "Stock: " + str(current_dealer.current_stock) + "g"
	drug_name_label.text = drug.display_name
	price_label.text = "$" + str(drug.base_price) + " / g"
	
	# Update button states
	var player_money = current_player.progression.money
	btn_5g.disabled = current_dealer.current_stock < 5 or player_money < 5 * drug.base_price
	btn_10g.disabled = current_dealer.current_stock < 10 or player_money < 10 * drug.base_price
	btn_20g.disabled = current_dealer.current_stock < 20 or player_money < 20 * drug.base_price
	
	var max_affordable = floor(player_money / drug.base_price)
	var max_buyable = min(max_affordable, current_dealer.current_stock)
	btn_max.disabled = max_buyable <= 0

func _attempt_buy(amount: int) -> void:
	var tier = current_dealer.tier_config
	if not tier or tier.allowed_drugs.is_empty(): return
	var drug = tier.allowed_drugs[0]
	
	var cost = amount * drug.base_price
	if current_player.progression.money < cost:
		error_label.text = "Not enough money!"
		return
	if not current_dealer.can_buy(amount):
		error_label.text = "Dealer out of stock!"
		return
		
	current_dealer.buy(amount)
	current_player.progression.money -= cost
	current_player.inventory_component.add_drug(drug.id, amount)
	
	# Audio Feedback
	AudioManager.play_transaction()
	
	var pui = current_player.get("player_ui")
	if pui:
		pui.spawn_indicator("money_down", "-$" + str(cost))
		pui.spawn_indicator("product", "+" + str(amount) + "g")
		
	error_label.text = "Bought " + str(amount) + "g of " + drug.display_name + "!"
	_refresh_ui()

func _on_buy_max() -> void:
	var tier = current_dealer.tier_config
	if not tier or tier.allowed_drugs.is_empty(): return
	var drug = tier.allowed_drugs[0]
	
	var max_affordable = floor(current_player.progression.money / drug.base_price)
	var max_buyable = min(max_affordable, current_dealer.current_stock)
	if max_buyable > 0:
		_attempt_buy(max_buyable)

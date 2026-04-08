extends Area2D
class_name FrontBusinessInteractArea

@export var business_data: FrontBusinessResource

func _ready() -> void:
	add_to_group("interact_area")
	collision_mask |= 2
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("register_interactable"):
		body.register_interactable(self)

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("unregister_interactable"):
		body.unregister_interactable(self)

func interact() -> void:
	var player := get_tree().get_first_node_in_group("player") as Player
	if player and player.gun_shop_ui:
		player.gun_shop_ui.open(player, business_data)

func npc_purchase(level: int) -> bool:
	if not business_data:
		return false
	var payout: int = NetworkManager.get_gun_shop_retail_price(level)
	var succeeded: bool = NetworkManager.complete_front_business_sale(business_data, level)
	if not succeeded:
		return false
	var player := get_tree().get_first_node_in_group("player") as Player
	if player and player.player_ui and payout > 0:
		player.player_ui.spawn_indicator("money_up", "+$%d Clean" % payout)
	AudioManager.play_transaction()
	return true

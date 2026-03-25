extends Node
class_name CustomerComponent

var config: SolicitationConfigResource
var player: Node2D
var target_npc: CharacterBody2D

var requested_grams: int = 0
var offered_payout: int = 0
var requested_drug_id: StringName = &"weed"
var customer_tier: int = 1

var state: String = "APPROACHING"
var current_territory: TerritoryArea

func _ready() -> void:
	target_npc = get_parent() as CharacterBody2D
	if not target_npc or not player or not config:
		queue_free()
		return
		
	# Find territory if not already set
	if target_npc.has_meta(&"territory"):
		current_territory = target_npc.get_meta(&"territory")
	
	requested_grams = randi_range(config.min_request_grams, config.max_request_grams)
	
	var territory_price = 10 # Fallback
	if current_territory:
		territory_price = current_territory.get_drug_price(requested_drug_id)
	else:
		territory_price = randi_range(config.min_payout_per_gram, config.max_payout_per_gram)
		
	# Profit of 1-10 dollars over the territory price
	var price_per_gram = territory_price + randi_range(1, 10)
	offered_payout = requested_grams * price_per_gram
	
	if target_npc.bt_player:
		target_npc.bt_player.set_process(false)
		target_npc.bt_player.set_physics_process(false)
		
	if target_npc.has_method("bark"):
		target_npc.bark("Hey! Over here!", 2.5, false, "solicitation")

func _physics_process(_delta: float) -> void:
	if not is_instance_valid(player) or not is_instance_valid(target_npc):
		_cancel()
		return
		
	var dist = target_npc.global_position.distance_to(player.global_position)
	
	if dist > config.radius * 2.0:
		_cancel()
		return
		
	if state == "APPROACHING":
		if dist > 60.0:
			if target_npc.nav_agent:
				target_npc.nav_agent.target_position = player.global_position
				var next_path_pos = target_npc.nav_agent.get_next_path_position()
				var dir = target_npc.global_position.direction_to(next_path_pos)
				target_npc.nav_agent.velocity = dir * target_npc.nav_agent.max_speed
		else:
			state = "WAITING"
			if target_npc.movement_component:
				target_npc.movement_component.move_velocity(Vector2.ZERO)
			if target_npc.has_method("bark"):
				var drug_name := DrugCatalog.get_display_name(requested_drug_id)
				target_npc.bark("I need %dg of %s. Give you $%d.\n(Press Space inside E radius)" % [requested_grams, drug_name, offered_payout], 2.5, true, "solicitation")

	elif state == "WAITING":
		if target_npc.animation_component:
			var dir = target_npc.global_position.direction_to(player.global_position)
			target_npc.animation_component.last_direction = dir
			target_npc.animation_component.update_animation(Vector2.ZERO)

func complete_deal() -> void:
	if state != "WAITING": return
	var player_node = player
	if not player_node: return
	
	var inv = player_node.inventory_component
	if inv.has_drug(requested_drug_id, requested_grams):
		inv.remove_drug(requested_drug_id, requested_grams)
		var sale_payout: int = int(offered_payout)
		if player_node.has_method("get_sale_payout_multiplier"):
			sale_payout = roundi(float(offered_payout) * player_node.get_sale_payout_multiplier())
		player_node.progression.money += sale_payout
		
		var definition := DrugCatalog.get_definition(requested_drug_id)
		var base_heat := definition.base_heat_per_gram if definition else HeatConfig.BASE_HEAT_PER_GRAM
		var risk_multiplier := definition.risk_multiplier if definition else 1.0
		var sale_heat = base_heat * requested_grams * risk_multiplier * HeatConfig.SALE_RISK_MULTIPLIER
		if player_node.has_method("get_sale_heat_multiplier"):
			sale_heat *= player_node.get_sale_heat_multiplier()
		if has_node("/root/HeatManager"):
			get_node("/root/HeatManager").add_heat(sale_heat)
		
		# XP and Indicators
		var sale_xp = int(requested_grams * 50) # Balanced: 50 XP per gram
		if player_node.has_method("get_sale_xp_multiplier"):
			sale_xp = roundi(float(sale_xp) * player_node.get_sale_xp_multiplier())
		player_node.progression.add_xp(sale_xp)
		
		if player_node.get("player_ui"):
			var pui = player_node.player_ui
			pui.spawn_indicator("money_up", "+$" + str(sale_payout))
			pui.spawn_indicator("product", "-%dg %s" % [requested_grams, DrugCatalog.get_display_name(requested_drug_id)], DrugCatalog.get_product_icon(requested_drug_id, false))
			pui.spawn_indicator("xp", "+" + str(sale_xp) + " XP")
			
		# Gain Reputation in Territory
		if current_territory and current_territory.reputation_component:
			current_territory.reputation_component.add_reputation(1.0 + (requested_grams * 0.1))
			if player_node.get("player_ui"):
				player_node.player_ui.spawn_indicator("money_up", "+REP") # Simple indicator for now
			
		if target_npc.has_method("bark"):
			target_npc.bark("Thanks man.", 2.0, false, "solicitation")
		
		# Short delay before returning to normal
		get_tree().create_timer(2.0).timeout.connect(_cancel)
		state = "LEAVING"
	else:
		if target_npc.has_method("bark"):
			target_npc.bark("You don't have enough!", 2.0, false, "solicitation")

func interact_triggered() -> void:
	if state == "WAITING":
		if target_npc.has_method("bark"):
			target_npc.bark("I said %dg of %s for $%d.\n(Press Space)" % [requested_grams, DrugCatalog.get_display_name(requested_drug_id), offered_payout], 2.5, true, "solicitation")

func _cancel() -> void:
	if is_instance_valid(target_npc):
		if target_npc.bt_player:
			target_npc.bt_player.set_process(true)
			target_npc.bt_player.set_physics_process(true)
		if target_npc.npc_ui:
			target_npc.npc_ui.hide_dialog_bubble()
			
		var p = get_tree().get_first_node_in_group("player")
		if p and p.get("current_interactable") == target_npc:
			p.current_interactable = null
			
	queue_free()

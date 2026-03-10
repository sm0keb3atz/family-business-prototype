extends Node
class_name CustomerComponent

var config: SolicitationConfigResource
var player: Node2D
var target_npc: CharacterBody2D

var requested_grams: int = 0
var offered_payout: int = 0

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
	
	var price_per_gram = config.min_payout_per_gram # Fallback
	if current_territory:
		price_per_gram = current_territory.get_drug_price(&"weed") # For now assuming weed
	else:
		price_per_gram = randi_range(config.min_payout_per_gram, config.max_payout_per_gram)
		
	offered_payout = requested_grams * price_per_gram
	
	if target_npc.bt_player:
		target_npc.bt_player.set_process(false)
		target_npc.bt_player.set_physics_process(false)
		
	if target_npc.npc_ui:
		target_npc.npc_ui.show_dialog_bubble("Hey! Over here!")

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
			if target_npc.npc_ui:
				target_npc.npc_ui.show_dialog_bubble("I need " + str(requested_grams) + "g. Give you $" + str(offered_payout) + ".\n(Press Space inside E radius)")

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
	var found_drug_id = ""
	
	# Just checking keys case-insensitively since we might create "Weed" or "weed"
	for k in inv.drugs.keys():
		if str(k).to_lower() == "weed":
			found_drug_id = k
			break
			
	if found_drug_id != "" and inv.has_drug(found_drug_id, requested_grams):
		inv.remove_drug(found_drug_id, requested_grams)
		player_node.progression.money += offered_payout
		
		# XP and Indicators
		var sale_xp = int(requested_grams * 5)
		player_node.progression.xp += sale_xp
		
		if player_node.get("player_ui"):
			var pui = player_node.player_ui
			pui.spawn_indicator("money_up", "+$" + str(offered_payout))
			pui.spawn_indicator("product", "-" + str(requested_grams) + "g")
			pui.spawn_indicator("xp", "+" + str(sale_xp) + " XP")
			
		# Gain Reputation in Territory
		if current_territory and current_territory.reputation_component:
			current_territory.reputation_component.add_reputation(1.0 + (requested_grams * 0.1))
			if player_node.get("player_ui"):
				player_node.player_ui.spawn_indicator("money_up", "+REP") # Simple indicator for now
			
		if target_npc.npc_ui:
			target_npc.npc_ui.show_dialog_bubble("Thanks man.")
		
		# Short delay before returning to normal
		get_tree().create_timer(2.0).timeout.connect(_cancel)
		state = "LEAVING"
	else:
		if target_npc.npc_ui:
			target_npc.npc_ui.show_dialog_bubble("You don't have enough!")

func interact_triggered() -> void:
	if state == "WAITING":
		if target_npc.npc_ui:
			target_npc.npc_ui.show_dialog_bubble("I said " + str(requested_grams) + "g for $" + str(offered_payout) + ".\n(Press Space)")

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

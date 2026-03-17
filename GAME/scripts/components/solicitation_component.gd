extends Node2D
class_name SolicitationComponent

@export var config: SolicitationConfigResource
var cooldown_timer: float = 0.0

var pulse_scene = preload("res://GAME/scenes/vfx/SolicitationPulse.tscn")

var barks: Array[String] = [
	"Yo i got that fire!",
	"Who needs some green?",
	"Check the product.",
	"Best in town right here.",
	"Hey! Over here!",
	"I got what you need."
]

func _process(delta: float) -> void:
	if cooldown_timer > 0:
		cooldown_timer -= delta

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_SPACE and event.pressed and not event.echo:
		var player = get_parent()
		if player and player.get("_is_interacting") and player.get("current_interactable"):
			var interactable = player.current_interactable
			if interactable.has_method("interact"):
				interactable.interact()
				return
			
		if cooldown_timer <= 0.0:
			solicit()

func solicit() -> void:
	if not config: return
	cooldown_timer = config.cooldown_seconds
	
	var player = get_parent()
	if not player is Player: return
	
	player.show_bark(barks.pick_random())
	AudioManager.play_random_solicitation()
	
	# Visual Pulse
	var pulse = pulse_scene.instantiate()
	get_tree().root.add_child(pulse)
	pulse.start_pulse(player.global_position, config.radius)
	
	var npcs = get_tree().get_nodes_in_group("npc")
	for npc in npcs:
		if not npc is NPC:
			continue

		var dist = player.global_position.distance_to(npc.global_position)
		
		if npc.role == npc.Role.CUSTOMER and not npc.has_node("CustomerComponent"):
			if dist <= config.radius:
				if randf() * 100.0 <= config.base_chance_percent:
					_convert_to_customer(npc, player)
		
		elif npc.role == npc.Role.DEALER:
			if dist <= config.radius:
				if npc.has_method("bark_dealer_feedback"):
					npc.bark_dealer_feedback("solicitation")
				
				# Lose reputation for soliciting on dealer's turf
				var territory = npc.get_meta(&"territory") if npc.has_meta(&"territory") else null
				if territory and territory.reputation_component:
					territory.reputation_component.add_reputation(-5.0)
					if player.get("player_ui"):
						player.player_ui.spawn_indicator("money_up", "-REP (Dealer Turf)")
		
		elif npc.role == npc.Role.POLICE:
			var detect_comp = npc.get_node_or_null("PoliceDetectionComponent")
			if detect_comp:
				# If the distance between player and police is less than or equal to the sum of their radii, the solicitation reaches them.
				if dist <= (config.radius + detect_comp.detection_radius):
					if has_node("/root/HeatManager"):
						get_node("/root/HeatManager").add_heat(HeatConfig.SOLICIT_HEAT)

func _convert_to_customer(npc: Node2D, player: Player) -> void:
	if npc is NPC and npc.blackboard:
		print("Solicitation: Converting NPC ", npc.name, " to customer")
		npc.blackboard.set_var(&"is_solicited", true)
		var grams = randi_range(config.min_request_grams, config.max_request_grams)
		npc.blackboard.set_var(&"requested_grams", grams)
		
		var territory = npc.get_meta(&"territory") if npc.has_meta(&"territory") else null
		var territory_price = 10 # Fallback
		if territory and territory.has_method("get_drug_price"):
			territory_price = territory.get_drug_price(&"weed")
		
		var payout_per_gram = territory_price + randi_range(1, 10)
		npc.blackboard.set_var(&"offered_payout", grams * payout_per_gram)
		
		# Initialize movement vars for ApproachPlayer action
		npc.blackboard.set_var(&"target", player)
		npc.blackboard.set_var(&"last_known_position", player.global_position)
		npc.blackboard.set_var(&"has_line_of_sight", true)
		
		if npc.has_method("_update_ui_icon"):
			npc._update_ui_icon()
		
		if npc.npc_ui:
			npc.npc_ui.show_dialog_bubble("Hey! Over here!")
		
		# Play gender-specific customer voice line (Spatial) with a natural delay
		var delay = randf_range(0.3, 0.6)
		get_tree().create_timer(delay).timeout.connect(
			func(): if is_instance_valid(npc): AudioManager.play_customer_dialog(npc.gender, npc.global_position)
		)


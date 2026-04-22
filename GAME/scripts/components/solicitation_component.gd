extends Node2D
class_name SolicitationComponent

@export var config: SolicitationConfigResource
var cooldown_timer: float = 0.0

const CUSTOMER_REQUEST_OPTIONS: Array[Dictionary] = [
	{"tier": 1, "drug_id": &"weed", "min_grams": 1, "max_grams": 15},
	{"tier": 2, "drug_id": &"weed", "min_grams": 15, "max_grams": 30},
	{"tier": 2, "drug_id": &"coke", "min_grams": 1, "max_grams": 15},
	{"tier": 3, "drug_id": &"coke", "min_grams": 15, "max_grams": 30},
	{"tier": 3, "drug_id": &"fetty", "min_grams": 1, "max_grams": 15},
	{"tier": 4, "drug_id": &"weed", "min_grams": 100, "max_grams": 100},
	{"tier": 4, "drug_id": &"coke", "min_grams": 73, "max_grams": 73},
	{"tier": 4, "drug_id": &"fetty", "min_grams": 50, "max_grams": 50}
]

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
		
		# Prioritize nearby interactables over soliciting (EXCEPT potential girlfriends, which require E)
		if player and player.get("_available_interactables") != null and not player._available_interactables.is_empty():
			if not player._is_interacting:
				# Find the closest interactable to check its type
				var closest = null
				var min_dist = 1e10
				for node in player._available_interactables:
					if not is_instance_valid(node): continue
					var d = player.global_position.distance_to(node.global_position)
					if d < min_dist:
						min_dist = d
						closest = node
				
				# If the closest thing is a potential girlfriend, we SKIP recruitment on Space.
				# This forces the player to use E for recruitment, avoiding accidents while soliciting.
				if closest and closest.get("is_potential_girlfriend"):
					pass # Skip recruitment on Space
				else:
					player.interact()
					return
			
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
	
	player.show_bark(barks.pick_random(), "solicitation")
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
			if npc.is_potential_girlfriend or npc.gf_resource != null:
				continue
			if npc.blackboard and npc.blackboard.has_var(&"is_dealer_customer") and npc.blackboard.get_var(&"is_dealer_customer", false):
				continue

			if dist <= config.radius:
				var chance_percent := config.base_chance_percent
				if player.has_method("get_solicitation_chance_multiplier"):
					chance_percent *= player.get_solicitation_chance_multiplier()
				chance_percent = minf(chance_percent, 100.0)
				if randf() * 100.0 <= chance_percent:
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
		var territory = npc.get_meta(&"territory") if npc.has_meta(&"territory") else null
		if not territory and "territory_id" in npc and npc.territory_id != &"":
			territory = TerritoryArea.get_territory_by_id(get_tree(), npc.territory_id)
		var request := _build_customer_request(player, territory)
		if request.is_empty():
			return

		npc.blackboard.set_var(&"is_solicited", true)
		npc.blackboard.set_var(&"requested_drug_id", request["drug_id"])
		npc.blackboard.set_var(&"requested_grams", request["grams"])
		npc.blackboard.set_var(&"offered_payout", request["payout"])
		npc.blackboard.set_var(&"customer_tier", request["tier"])
		
		# Initialize movement vars for ApproachPlayer action
		npc.blackboard.set_var(&"target", player)
		npc.blackboard.set_var(&"last_known_position", player.global_position)
		npc.blackboard.set_var(&"has_line_of_sight", true)
		
		if npc.has_method("_update_ui_icon"):
			npc._update_ui_icon()
		
		if npc.has_method("bark"):
			npc.bark("Hey! Over here!", 2.5, false, "solicitation")
		
		# Play gender-specific customer voice line (Spatial) with a natural delay
		var delay = randf_range(0.3, 0.6)
		get_tree().create_timer(delay).timeout.connect(
			func(): if is_instance_valid(npc): AudioManager.play_customer_dialog(npc.gender, npc.global_position)
		)

func _build_customer_request(player: Player, territory: Variant) -> Dictionary:
	var weighted_requests: Array[Dictionary] = []
	var total_weight := 0.0

	for option in CUSTOMER_REQUEST_OPTIONS:
		var weight := _get_request_weight(player, option)
		if weight <= 0.0:
			continue
		total_weight += weight
		weighted_requests.append({
			"option": option,
			"cumulative_weight": total_weight
		})

	if weighted_requests.is_empty():
		return {}

	var roll := randf() * total_weight
	for entry in weighted_requests:
		if roll <= entry["cumulative_weight"]:
			var option: Dictionary = entry["option"]
			var grams := randi_range(option["min_grams"], option["max_grams"])
			var drug_id: StringName = option["drug_id"]
			var territory_price := 10
			if territory and territory.has_method("get_drug_price"):
				territory_price = territory.get_drug_price(drug_id)
			else:
				territory_price = _get_fallback_price(drug_id)
			var payout_per_gram := territory_price + randi_range(2, 5)
			return {
				"tier": option["tier"],
				"drug_id": drug_id,
				"grams": grams,
				"payout": grams * payout_per_gram
			}

	return {}

func _get_request_weight(player: Player, option: Dictionary) -> float:
	var tier: int = option["tier"]
	var drug_id: StringName = option["drug_id"]
	var min_grams: int = option["min_grams"]
	var max_grams: int = option["max_grams"]
	var target_grams := int(round((min_grams + max_grams) * 0.5))
	var tier_weight := _get_customer_tier_weight(player, tier)
	var inventory_weight := _get_inventory_match_weight(player, drug_id, min_grams, target_grams, tier)
	return tier_weight * inventory_weight

func _get_customer_tier_weight(player: Player, tier: int) -> float:
	var player_level := player.progression.level if player and player.progression else 1
	var social_level := player.progression.get_skill_level(PlayerSkills.SOCIAL) if player and player.progression else 0

	match tier:
		1:
			return 1.0
		2:
			return clampf(0.35 + (0.05 * max(player_level - 1, 0)) + (0.30 * social_level), 0.35, 2.0)
		3:
			return clampf(0.08 + (0.02 * max(player_level - 1, 0)) + (0.22 * social_level), 0.08, 1.6)
		4:
			return clampf(0.01 + (0.008 * max(player_level - 1, 0)) + (0.12 * social_level), 0.01, 0.9)
		_:
			return 0.0

func _get_inventory_match_weight(player: Player, drug_id: StringName, min_grams: int, target_grams: int, tier: int) -> float:
	if not player or not player.inventory_component:
		return 0.01

	var total_available := player.inventory_component.get_total_grams_for_drug(drug_id)
	if total_available >= target_grams:
		return 1.0 + minf(1.5, float(total_available) / maxf(float(target_grams), 1.0) * 0.25)
	if total_available >= min_grams:
		return 0.35 if tier <= 2 else 0.12
	if total_available > 0:
		return 0.10 if tier <= 2 else 0.02
	return 0.03 if tier <= 2 else 0.005

func _get_fallback_price(drug_id: StringName) -> int:
	match String(drug_id).to_lower():
		"weed":
			return 25
		"coke":
			return 65
		"fetty":
			return 125
		_:
			return 10


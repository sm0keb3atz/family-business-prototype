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
		if npc.role == npc.Role.CUSTOMER and not npc.has_node("CustomerComponent"):
			var dist = player.global_position.distance_to(npc.global_position)
			if dist <= config.radius:
				if randf() * 100.0 <= config.base_chance_percent:
					_convert_to_customer(npc)

func _convert_to_customer(npc: Node2D) -> void:
	if npc is NPC and npc.blackboard:
		print("Solicitation: Converting NPC ", npc.name, " to customer")
		npc.blackboard.set_var(&"is_solicited", true)
		npc.blackboard.set_var(&"requested_grams", randi_range(config.min_request_grams, config.max_request_grams))
		var payout_per_gram = randi_range(config.min_payout_per_gram, config.max_payout_per_gram)
		npc.blackboard.set_var(&"offered_payout", npc.blackboard.get_var(&"requested_grams") * payout_per_gram)
		
		if npc.has_method("_update_ui_icon"):
			npc._update_ui_icon()
		
		if npc.npc_ui:
			npc.npc_ui.show_dialog_bubble("Hey! Over here!")
		
		# Play gender-specific customer voice line (Spatial) with a natural delay
		var delay = randf_range(0.3, 0.6)
		get_tree().create_timer(delay).timeout.connect(
			func(): if is_instance_valid(npc): AudioManager.play_customer_dialog(npc.gender, npc.global_position)
		)


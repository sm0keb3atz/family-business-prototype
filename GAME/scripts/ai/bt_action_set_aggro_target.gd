@tool
extends BTAction
class_name BTActionSetAggroTarget

func _tick(delta: float) -> Status:
	if not agent or not blackboard:
		return FAILURE
		
	# Target the attacker if we have one, otherwise target the player.
	var raw_attacker = blackboard.get_var(&"attacker", null)
	var target: Node2D = null
	
	if raw_attacker and is_instance_valid(raw_attacker):
		var attacker := raw_attacker as Node2D
		# ONLY target if the attacker is still alive
		var is_alive: bool = true
		var hc = attacker.get_node_or_null("HealthComponent")
		if not hc: hc = attacker.get_node_or_null("Components/HealthComponent")
		if hc and hc.is_dead:
			is_alive = false
			
		if is_alive:
			target = attacker
	
	if not target or not is_instance_valid(target):
		target = agent.get_tree().get_first_node_in_group("player")
		
	if target and is_instance_valid(target):
		var old_target = blackboard.get_var(&"target", null) if blackboard.has_var(&"target") else null
		blackboard.set_var(&"target", target)
		
		# Proactive: Bark if dealer and target is new or were not in combat
		if agent is NPC and agent.role == NPC.Role.DEALER:
			if target != old_target:
				agent.bark_dealer_combat(target)
		
		return SUCCESS
		
	return FAILURE

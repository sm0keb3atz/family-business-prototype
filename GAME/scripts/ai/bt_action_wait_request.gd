@tool
extends BTAction

func _tick(_delta: float) -> Status:
	var npc: NPC = agent as NPC
	if npc:
		if npc.nav_agent:
			npc.nav_agent.set_velocity(Vector2.ZERO)
			
		var player = npc.get_tree().get_first_node_in_group("player")
		if player and npc.animation_component:
			var dir = npc.global_position.direction_to(player.global_position)
			npc.animation_component.last_direction = dir
			npc.animation_component.update_animation(Vector2.ZERO)
	return RUNNING

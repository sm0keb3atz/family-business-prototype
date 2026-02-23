extends PlayerState

func physics_update(_delta: float) -> void:
	var direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	
	if direction.length() < 0.1:
		state_machine.transition_to("Idle")
		return
	
	if player.has_node("%MovementComponent"):
		var is_sprinting = Input.is_action_pressed("sprint")
		player.get_node("%MovementComponent").move(direction, is_sprinting)
	
	if player.has_node("%AnimationComponent"):
		player.get_node("%AnimationComponent").update_animation(direction)

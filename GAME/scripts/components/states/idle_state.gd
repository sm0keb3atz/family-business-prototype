extends PlayerState

func enter(_msg: Dictionary = {}) -> void:
	if player.has_node("%AnimationComponent"):
		player.get_node("%AnimationComponent").update_animation(Vector2.ZERO)

func physics_update(_delta: float) -> void:
	var input_component = player.get_node_or_null("%InputComponent")
	if input_component:
		var direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		if direction.length() > 0.1:
			state_machine.transition_to("Move")

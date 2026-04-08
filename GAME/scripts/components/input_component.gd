extends Node
class_name InputComponent

signal movement_direction_changed(direction: Vector2)
signal fire_requested
signal interact_requested
signal weapon_next_requested
signal weapon_prev_requested
signal reload_requested
signal aim_state_changed(is_aiming: bool)

var _is_aiming_last_state: bool = false

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("weapon_next"):
		weapon_next_requested.emit()
	elif event.is_action_pressed("weapon_prev"):
		weapon_prev_requested.emit()

func _process(_delta: float) -> void:
	var direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	movement_direction_changed.emit(direction)
	
	# Skip combat/interact input if hovering over EXCLUSIVE UI
	var is_blocked = _is_interaction_blocked_by_ui()
	
	if Input.is_action_pressed("fire") and not is_blocked:
		fire_requested.emit()
		
	var is_aiming = Input.is_action_pressed("aim")
	if is_aiming != _is_aiming_last_state:
		_is_aiming_last_state = is_aiming
		aim_state_changed.emit(is_aiming)
		
	if Input.is_action_just_pressed("interact"):
		if not is_blocked:
			print("InputComponent: Interaction Triggered")
			interact_requested.emit()
		else:
			var hovered = get_viewport().gui_get_hovered_control()
			if hovered:
				print("InputComponent: Interact BLOCKED by: ", hovered.name, " (", hovered.get_path(), ")")

	if Input.is_action_just_pressed("reload"):
		reload_requested.emit()

func _is_interaction_blocked_by_ui() -> bool:
	var hovered = get_viewport().gui_get_hovered_control()
	if not hovered:
		return false
	
	# Ignore the HUD and other non-exclusive overlays
	var path = str(hovered.get_path())
	if "Hud" in path or "HUD" in path:
		return false
	if "PlayerUI" in path:
		return false
		
	# If the control is stopping mouse input, it's likely a menu or blocking UI
	if hovered.mouse_filter == Control.MOUSE_FILTER_STOP:
		return true
		
	return false

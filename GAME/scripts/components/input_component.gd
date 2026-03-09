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
	
	if Input.is_action_pressed("fire"):
		fire_requested.emit()
		
	var is_aiming = Input.is_action_pressed("aim")
	if is_aiming != _is_aiming_last_state:
		_is_aiming_last_state = is_aiming
		aim_state_changed.emit(is_aiming)
		
	if Input.is_action_just_pressed("interact"):
		print("InputComponent: Interact pressed")
		interact_requested.emit()

	if Input.is_action_just_pressed("reload"):
		reload_requested.emit()

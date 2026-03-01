extends Node

signal player_detection_changed(state: bool)

var active_detection_count: int = 0
var is_player_detected: bool = false

func register_detection() -> void:
	active_detection_count += 1
	_evaluate_detection_state()

func unregister_detection() -> void:
	active_detection_count = maxi(0, active_detection_count - 1)
	_evaluate_detection_state()

func _evaluate_detection_state() -> void:
	var new_state = active_detection_count > 0
	if is_player_detected != new_state:
		is_player_detected = new_state
		player_detection_changed.emit(is_player_detected)

@tool
extends BTAction
## Waits for a random duration between [member min_duration] and [member max_duration].
## Returns RUNNING while waiting, SUCCESS when finished.

@export var min_duration: float = 2.0
@export var max_duration: float = 5.0

var _duration: float = 0.0
var _elapsed: float = 0.0

func _generate_name() -> String:
	return "Wait Random (%s to %s s)" % [min_duration, max_duration]

func _enter() -> void:
	_duration = randf_range(min_duration, max_duration)
	_elapsed = 0.0

func _tick(delta: float) -> Status:
	_elapsed += delta
	if _elapsed >= _duration:
		return SUCCESS
	return RUNNING

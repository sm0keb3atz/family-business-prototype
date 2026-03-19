extends CanvasModulate
class_name DayNightCycle

@export var time_manager: TimeManager
@export var day_night_gradient: Gradient

func _ready() -> void:
	if not time_manager:
		time_manager = get_tree().get_first_node_in_group("time_manager")
		
	if time_manager:
		time_manager.percent_changed.connect(_on_time_percent_changed)
		_on_time_percent_changed(time_manager.get_day_percent())

func _on_time_percent_changed(percent: float) -> void:
	if day_night_gradient:
		color = day_night_gradient.sample(percent)

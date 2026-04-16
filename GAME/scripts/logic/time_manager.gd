extends Node
class_name TimeManager

signal time_updated(hours: int, minutes: int)
signal date_updated(day: int, month: int, year: int)
signal percent_changed(percent: float)

@export var day_length_seconds: float = 600.0
@export var starting_hour: int = 8
@export var starting_day: int = 1
@export var starting_month: int = 1
@export var starting_year: int = 2026

var total_game_seconds: float = 0.0
var current_minute: int = 0
var current_hour: int = 0
var current_day: int = 0
var current_month: int = 0
var current_year: int = 0

func _ready() -> void:
	current_hour = starting_hour
	current_minute = 0
	current_day = starting_day
	current_month = starting_month
	current_year = starting_year

	total_game_seconds = float(starting_hour) * 3600.0
	add_to_group("time_manager")
	call_deferred("_emit_initial_signals")

func _emit_initial_signals() -> void:
	time_updated.emit(current_hour, current_minute)
	date_updated.emit(current_day, current_month, current_year)

func _process(delta: float) -> void:
	var game_seconds_per_real_second: float = 86400.0 / day_length_seconds
	total_game_seconds += delta * game_seconds_per_real_second
	_update_time_logic()

func _update_time_logic() -> void:
	var total_minutes: int = int(total_game_seconds / 60.0)
	var new_minute: int = total_minutes % 60
	var new_hour: int = int(total_minutes / 60) % 24
	var new_day_count: int = int(total_minutes / 1440)

	if new_minute != current_minute or new_hour != current_hour:
		current_minute = new_minute
		current_hour = new_hour
		time_updated.emit(current_hour, current_minute)
		percent_changed.emit(get_day_percent())

	var day_in_cycle: int = (new_day_count % 30) + starting_day
	var month_in_cycle: int = (int(new_day_count / 30) % 12) + starting_month
	var year_in_cycle: int = int(new_day_count / 360) + starting_year

	if day_in_cycle != current_day or month_in_cycle != current_month or year_in_cycle != current_year:
		current_day = day_in_cycle
		current_month = month_in_cycle
		current_year = year_in_cycle
		date_updated.emit(current_day, current_month, current_year)

func get_day_percent() -> float:
	return (float(current_hour) * 60.0 + float(current_minute)) / 1440.0

func set_time(hour: int, minute: int = 0) -> void:
	current_hour = clampi(hour, 0, 23)
	current_minute = clampi(minute, 0, 59)
	total_game_seconds = (float(current_hour) * 3600.0) + (float(current_minute) * 60.0)
	
	# Force an immediate update of signals
	time_updated.emit(current_hour, current_minute)
	percent_changed.emit(get_day_percent())

func get_time_string() -> String:
	var am_pm: String = "AM"
	var display_hour: int = current_hour
	if display_hour >= 12:
		am_pm = "PM"
		if display_hour > 12:
			display_hour -= 12
	if display_hour == 0:
		display_hour = 12
	return "%d:%02d %s" % [display_hour, current_minute, am_pm]

func get_date_string() -> String:
	var months: Array = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
	var month_index: int = maxi(0, (current_month - 1) % 12)
	var month_str: String = str(months[month_index])
	return "%s %d, %d" % [month_str, current_day, current_year]

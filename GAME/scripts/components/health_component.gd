extends Node
class_name HealthComponent

signal health_changed(current: int, max: int)
signal damage_taken(amount: int)
signal died

@export var current_health: int = 100
var stats: CharacterStatsResource
var is_dead: bool = false
var _regen_accumulator: float = 0.0  # Fractional HP so regen isn't lost to int truncation

func setup(p_stats: CharacterStatsResource) -> void:
	stats = p_stats
	_regen_accumulator = 0.0
	if stats:
		current_health = stats.max_health
		health_changed.emit(current_health, stats.max_health)

func take_damage(amount: int) -> void:
	var actual_damage = clampi(amount - int(stats.defense if stats else 0.0), 0, amount)
	current_health -= actual_damage
	damage_taken.emit(actual_damage)
	health_changed.emit(current_health, stats.max_health if stats else current_health)
	
	if current_health <= 0 and not is_dead:
		is_dead = true
		died.emit()

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	if not stats or stats.health_regen <= 0 or current_health >= stats.max_health:
		_regen_accumulator = 0.0
		return
	_regen_accumulator += stats.health_regen * delta
	var max_gain := stats.max_health - current_health
	while _regen_accumulator >= 1.0 and max_gain > 0:
		current_health += 1
		max_gain -= 1
		_regen_accumulator -= 1.0
		health_changed.emit(current_health, stats.max_health)
	if _regen_accumulator >= 1.0:
		_regen_accumulator = 0.0

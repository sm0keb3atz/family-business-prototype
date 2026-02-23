extends Node
class_name HealthComponent

signal health_changed(current: int, max: int)
signal died

@export var current_health: int = 100
var stats: CharacterStatsResource

func setup(p_stats: CharacterStatsResource) -> void:
	stats = p_stats
	if stats:
		current_health = stats.max_health
		health_changed.emit(current_health, stats.max_health)

func take_damage(amount: int) -> void:
	var actual_damage = clampi(amount - int(stats.defense if stats else 0.0), 0, amount)
	current_health -= actual_damage
	health_changed.emit(current_health, stats.max_health if stats else current_health)
	
	if current_health <= 0:
		died.emit()

func _process(delta: float) -> void:
	if stats and stats.health_regen > 0 and current_health < stats.max_health:
		var old_health = current_health
		current_health = int(min(current_health + stats.health_regen * delta, stats.max_health))
		if old_health != current_health:
			health_changed.emit(current_health, stats.max_health)

extends Resource
class_name PlayerProgressionResource

signal xp_changed(current: int, required: int)
signal leveled_up(new_level: int)
signal money_changed(new_amount: int)

@export var money: int = 0:
	set(v):
		money = v
		money_changed.emit(money)

@export var xp: int = 0
@export var level: int = 1
@export var skill_points: int = 0

func add_xp(amount: int) -> void:
	xp += amount
	var required = get_required_xp()
	
	while xp >= required:
		xp -= required
		level += 1
		skill_points += 1
		leveled_up.emit(level)
		required = get_required_xp()
	
	xp_changed.emit(xp, required)

func get_required_xp() -> int:
	# Levels 1-20: 500 XP per level (Easy)
	if level < 20:
		return 500
	# Levels 21-40: 1000 XP per level (Moderate)
	elif level < 40:
		return 1000
	# Levels 41-100+: 5000 XP per level (Hard)
	else:
		return 5000

extends Resource
class_name PlayerProgressionResource

signal xp_changed(current: int, required: int)
signal leveled_up(new_level: int)
signal skill_points_changed(new_amount: int)
signal skills_changed(skill_id: StringName, new_level: int)


@export var xp: int = 0
@export var level: int = 1
@export var skill_points: int = 0:
	set(v):
		skill_points = max(v, 0)
		skill_points_changed.emit(skill_points)

@export var combat_skill_level: int = 0
@export var sales_skill_level: int = 0
@export var social_skill_level: int = 0
@export var strength_skill_level: int = 0


func set_level_value(new_level: int, reset_xp: bool = true) -> void:
	level = max(new_level, 1)
	if reset_xp:
		xp = 0
	xp_changed.emit(xp, get_required_xp())

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

func get_skill_level(skill_id: StringName) -> int:
	match skill_id:
		PlayerSkills.COMBAT:
			return combat_skill_level
		PlayerSkills.SALES:
			return sales_skill_level
		PlayerSkills.SOCIAL:
			return social_skill_level
		PlayerSkills.STRENGTH:
			return strength_skill_level
		_:
			return 0

func set_skill_level(skill_id: StringName, new_level: int) -> void:
	var clamped_level := clampi(new_level, 0, PlayerSkills.MAX_LEVEL)
	match skill_id:
		PlayerSkills.COMBAT:
			combat_skill_level = clamped_level
		PlayerSkills.SALES:
			sales_skill_level = clamped_level
		PlayerSkills.SOCIAL:
			social_skill_level = clamped_level
		PlayerSkills.STRENGTH:
			strength_skill_level = clamped_level
		_:
			return
	skills_changed.emit(skill_id, clamped_level)

func get_next_skill_cost(skill_id: StringName) -> int:
	var next_level := get_skill_level(skill_id) + 1
	return PlayerSkills.get_level_cost(next_level)

func can_purchase_skill(skill_id: StringName) -> bool:
	var current_level := get_skill_level(skill_id)
	if current_level >= PlayerSkills.MAX_LEVEL:
		return false
	var next_cost := get_next_skill_cost(skill_id)
	return next_cost > 0 and skill_points >= next_cost

func purchase_skill(skill_id: StringName) -> bool:
	if not can_purchase_skill(skill_id):
		return false
	var next_level := get_skill_level(skill_id) + 1
	var cost := PlayerSkills.get_level_cost(next_level)
	skill_points -= cost
	set_skill_level(skill_id, next_level)
	return true

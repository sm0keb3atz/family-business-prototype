extends Resource
class_name PlayerWeaponState

signal owned_glock_level_changed(new_level: int)
signal equipped_state_changed(is_equipped: bool)

@export var owned_glock_level: int = 0:
	set(v):
		var clamped: int = clampi(v, 0, 4)
		if owned_glock_level == clamped:
			return
		owned_glock_level = clamped
		owned_glock_level_changed.emit(owned_glock_level)

@export var is_equipped: bool = false:
	set(v):
		if is_equipped == v:
			return
		is_equipped = v
		equipped_state_changed.emit(is_equipped)

func has_glock() -> bool:
	return owned_glock_level > 0

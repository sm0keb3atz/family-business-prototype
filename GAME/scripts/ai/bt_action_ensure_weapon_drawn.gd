@tool
extends BTAction
class_name BTActionEnsureWeaponDrawn

func _tick(delta: float) -> Status:
	if not agent:
		return FAILURE
		
	var weapon_holder = agent.get_node_or_null("%WeaponHolderComponent")
	if not weapon_holder:
		return FAILURE
		
	if not weapon_holder.current_weapon:
		# Give them a gun if they don't have one out.
		var glock = preload("res://GAME/scenes/Weapons/glock.tscn")
		var glock_data = preload("res://GAME/resources/weapons/glock_lv1.tres")
		weapon_holder.equip_weapon(glock, glock_data)
		return SUCCESS
		
	return SUCCESS

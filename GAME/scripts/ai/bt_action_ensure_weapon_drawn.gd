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
		# Give them a gun if they don't have one out. Mix levels for variety in cadence/spread.
		var glock = preload("res://GAME/scenes/Weapons/glock.tscn")
		var loadout: Array[WeaponDataResource] = [
			preload("res://GAME/resources/weapons/glock_lv1.tres"),
			preload("res://GAME/resources/weapons/glock_lv2.tres"),
			preload("res://GAME/resources/weapons/glock_lv3.tres")
		]
		var glock_data: WeaponDataResource = loadout.pick_random()
		weapon_holder.equip_weapon(glock, glock_data)
		return SUCCESS
		
	return SUCCESS

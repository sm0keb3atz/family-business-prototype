@tool
extends BTAction
class_name BTActionEnsureWeaponHolstered

func _tick(_delta: float) -> Status:
	if not agent:
		return FAILURE
		
	var weapon_holder = agent.get_node_or_null("%WeaponHolderComponent")
	if not weapon_holder:
		return FAILURE
		
	if weapon_holder.current_weapon:
		# Remove the weapon
		weapon_holder.equip_weapon(null)
		return SUCCESS
		
	return SUCCESS

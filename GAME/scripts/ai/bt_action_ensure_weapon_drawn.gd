@tool
extends BTAction
class_name BTActionEnsureWeaponDrawn

func _tick(delta: float) -> Status:
	if not agent:
		return FAILURE
		
	var weapon_holder = agent.get_node_or_null("%WeaponHolderComponent")
	if not weapon_holder:
		return FAILURE
		
	# RESTRICTION: Only Dealers and Police can draw weapons
	if agent.role == NPC.Role.CUSTOMER:
		return FAILURE
		
	if not weapon_holder.current_weapon:
		var weapon_scene = preload("res://GAME/scenes/Weapons/glock.tscn")
		var weapon_data = preload("res://GAME/resources/weapons/glock_lv1.tres")
		
		# If it's a dealer, use their specific tier gear
		if agent.get("dealer_tier"):
			var tier = agent.dealer_tier
			if tier.weapon_scene: weapon_scene = tier.weapon_scene
			if tier.weapon_data: weapon_data = tier.weapon_data
		else:
			# Police Fallback
			var loadout: Array[WeaponDataResource] = [
				preload("res://GAME/resources/weapons/glock_lv1.tres"),
				preload("res://GAME/resources/weapons/glock_lv2.tres"),
				preload("res://GAME/resources/weapons/glock_lv3.tres")
			]
			weapon_data = loadout.pick_random()
			
		weapon_holder.equip_weapon(weapon_scene, weapon_data)
		return SUCCESS
		
	return SUCCESS

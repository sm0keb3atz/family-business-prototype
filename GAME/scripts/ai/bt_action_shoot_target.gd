@tool
extends BTAction
class_name BTActionShootTarget

func _tick(delta: float) -> Status:
	if not agent or not blackboard:
		return FAILURE
		
	var target = blackboard.get_var(&"target", null) as Node2D
	if not target or not is_instance_valid(target):
		return FAILURE
		
	# Don't shoot if target is already dead
	if target.has_node("Components/HealthComponent"):
		var hc = target.get_node("Components/HealthComponent")
		if hc.is_dead:
			return FAILURE
	elif target.has_node("HealthComponent"): # Fallback
		var hc = target.get_node("HealthComponent")
		if hc.is_dead:
			return FAILURE
		
	# Leniency Check: Don't shoot if the player is no longer at combat heat level
	var hm = agent.get_node_or_null("/root/HeatManager")
	if hm and hm.wanted_stars < 2:
		return FAILURE
		
	var weapon_holder = agent.get_node_or_null("%WeaponHolderComponent")
	if not weapon_holder or not weapon_holder.current_weapon:
		return FAILURE
		
	var weapon_pivot = agent.get_node_or_null("%WeaponPivot")
	if weapon_pivot:
		weapon_pivot.look_at(target.global_position)
		
	# Halt movement while shooting to prevent sliding/running past the player
	if agent.has_method("get_node_or_null"):
		var nav_agent = agent.get_node_or_null("%NavigationAgent2D")
		var movement = agent.get_node_or_null("%MovementComponent")
		var animation = agent.get_node_or_null("%AnimationComponent")
		if movement: movement.move_velocity(Vector2.ZERO)
		if nav_agent: nav_agent.set_velocity(Vector2.ZERO)
		if animation: animation.update_animation(Vector2.ZERO)
		
	weapon_holder.fire()
	
	return SUCCESS

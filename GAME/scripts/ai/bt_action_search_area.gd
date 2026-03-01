@tool
extends BTAction
class_name BTActionSearchArea

@export var search_radius: float = 600.0
@export var speed_multiplier: float = 0.8 # Methodical but faster search
@export var direction_var: StringName = &"move_direction"

var _target_set: bool = false
var _current_target: Vector2 = Vector2.ZERO
var _last_point: Vector2 = Vector2.ZERO
var _time_searching: float = 0.0

func _generate_name() -> String:
	return "Search Area (radius: %s)" % search_radius

func _enter() -> void:
	_target_set = false
	_time_searching = 0.0
	# Give this NPC a unique search bias and glide variance so they don't all follow the exact same path
	if blackboard:
		var off = Vector2(randf_range(-400, 400), randf_range(-400, 400))
		blackboard.set_var(&"search_offset", off)
		var g_var = randf_range(0.2, 0.9) # Higher variance in how far they "guess"
		blackboard.set_var(&"glide_variance", g_var)

func _tick(delta: float) -> Status:
	var npc: NPC = agent as NPC
	if not npc or not npc.movement_component or not npc.nav_agent:
		return FAILURE
		
	if not blackboard.has_var(&"search_anchor"):
		return FAILURE
		
	var anchor: Vector2 = blackboard.get_var(&"search_anchor", Vector2.ZERO)
	if anchor == Vector2.ZERO:
		return FAILURE
		
	_time_searching += delta
	
	# PREDICTIVE SEARCH: Move the anchor in the direction the player was last seen running
	var lkv: Vector2 = blackboard.get_var(&"last_known_velocity", Vector2.ZERO)
	if lkv.length() > 20.0:
		var glide_factor = blackboard.get_var(&"glide_variance", 0.4)
		var new_anchor = anchor + (lkv * glide_factor * delta)
		blackboard.set_var(&"search_anchor", new_anchor)
		anchor = new_anchor # Use updated anchor for this tick

	# EXPANDING SEARCH: Increase radius over time to roam further
	var expansion_rate = 15.0 # Faster expansion
	var current_radius = search_radius + (_time_searching * expansion_rate)
	current_radius = min(current_radius, search_radius * 5.0) # Larger max radius
	
	# Apply individual offset
	var offset = blackboard.get_var(&"search_offset", Vector2.ZERO)
	var effective_anchor = anchor + offset

	if not _target_set:
		# Pick a random point within a donuts range (min to max radius)
		var min_radius = current_radius * 0.3
		var valid_point_found = false
		var attempts = 0
		
		while not valid_point_found and attempts < 20:
			var random_dir = Vector2.RIGHT.rotated(randf_range(0, TAU))
			
			# DIRECTIONAL CONE SEARCH:
			# If we have a last known velocity or current direction, bias heavily toward it
			var bias_dir = Vector2.ZERO
			if lkv.length() > 20.0:
				bias_dir = lkv.normalized()
			else:
				var current_dir = blackboard.get_var(direction_var, Vector2.ZERO)
				if current_dir != Vector2.ZERO:
					bias_dir = current_dir
			
			if bias_dir != Vector2.ZERO:
				# 80% chance to stay within a 120-degree cone centered on momentum
				if randf() < 0.8:
					var base_angle = bias_dir.angle()
					random_dir = Vector2.RIGHT.rotated(base_angle + randf_range(-PI/3.0, PI/3.0))
				
			var random_dist = randf_range(min_radius, current_radius)
			var desired_point = effective_anchor + (random_dir * random_dist)
			
			# Ensure it's reachable on the nav mesh 
			var map = npc.nav_agent.get_navigation_map()
			var valid_point = NavigationServer2D.map_get_closest_point(map, desired_point)
			
			# Check distance from last point to avoid "shuffling"
			if _last_point == Vector2.ZERO or valid_point.distance_to(_last_point) > 250.0:
				_current_target = valid_point
				_last_point = valid_point
				valid_point_found = true
			
			attempts += 1
			
		if not valid_point_found:
			_current_target = effective_anchor
			
		npc.nav_agent.target_position = _current_target
		_target_set = true

	if blackboard.get_var(&"is_interacting", false):
		if npc.movement_component: npc.movement_component.move_velocity(Vector2.ZERO)
		return RUNNING

	if npc.global_position.distance_to(_current_target) <= 40.0 or npc.nav_agent.is_navigation_finished():
		# Arrived at this search point, reset to find next one next tick
		if npc.movement_component: npc.movement_component.move_velocity(Vector2.ZERO)
		if npc.animation_component: npc.animation_component.update_animation(Vector2.ZERO)
		_target_set = false # Pick new point next tick
		return RUNNING # Continue search

	# Move towards the current search point
	var next_pos: Vector2 = npc.nav_agent.get_next_path_position()
	var direction: Vector2 = npc.global_position.direction_to(next_pos)
	
	var desired_velocity: Vector2 = direction * (npc.stats.move_speed * speed_multiplier)
	npc.nav_agent.set_velocity(desired_velocity)

	blackboard.set_var(direction_var, direction)
	
	return RUNNING

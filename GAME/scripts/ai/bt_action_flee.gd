@tool
extends BTAction
## Moves the agent away from a threat position using NavigationAgent2D.
## Returns RUNNING while fleeing, SUCCESS when the flee duration expires.

@export var flee_duration: float = 3.0
@export var flee_distance: float = 300.0
@export var sprint_speed_multiplier: float = 1.5
## Blackboard variable containing the position to flee from.
@export var threat_position_var: StringName = &"damage_source_position"
## Blackboard variable that stores the movement direction for AnimationComponent.
@export var direction_var: StringName = &"move_direction"

var _elapsed: float = 0.0
var _initial_flee_direction: Vector2 = Vector2.ZERO

func _generate_name() -> String:
	return "Flee (duration: %s, sprint: %sx)" % [flee_duration, sprint_speed_multiplier]

func _enter() -> void:
	_elapsed = 0.0
	var npc: NPC = agent as NPC
	if not npc or not npc.nav_agent:
		return

	var threat_pos: Vector2 = blackboard.get_var(threat_position_var, npc.global_position)
	_initial_flee_direction = (npc.global_position - threat_pos).normalized()

	# If somehow threat is at the exact same position, pick a random direction
	if _initial_flee_direction.length() < 0.1:
		_initial_flee_direction = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized()

	# Calculate target point far away in the flee direction
	var potential_target: Vector2 = npc.global_position + _initial_flee_direction * flee_distance
	
	# Snap the target point to the navigation mesh to ensure it's valid
	var map: RID = npc.get_world_2d().navigation_map
	var safe_target: Vector2 = NavigationServer2D.map_get_closest_point(map, potential_target)
	
	npc.nav_agent.target_position = safe_target
	
	# Speed up animation to simulate sprinting
	if npc.animation_component and npc.animation_component.animation_player:
		npc.animation_component.animation_player.speed_scale = sprint_speed_multiplier
	
	# Increase nav agent max speed to allow sprinting
	if npc.nav_agent and npc.stats:
		npc.nav_agent.max_speed = npc.stats.move_speed * sprint_speed_multiplier

func _exit() -> void:
	# Reset animation speed and max speed when task ends or is aborted
	var npc: NPC = agent as NPC
	if npc:
		if npc.animation_component and npc.animation_component.animation_player:
			npc.animation_component.animation_player.speed_scale = 1.0
		if npc.nav_agent and npc.stats:
			npc.nav_agent.max_speed = npc.stats.move_speed

func _tick(delta: float) -> Status:
	_elapsed += delta
	var npc: NPC = agent as NPC
	if not npc or not npc.movement_component or not npc.nav_agent:
		return FAILURE

	if _elapsed >= flee_duration or npc.nav_agent.is_navigation_finished():
		# Done fleeing — stop movement and clear the shot flag
		npc.movement_component.move_velocity(Vector2.ZERO)
		if npc.animation_component:
			npc.animation_component.update_animation(Vector2.ZERO)
		blackboard.set_var(&"was_shot", false)
		return SUCCESS

	# Follow nav agent path
	var next_pos: Vector2 = npc.nav_agent.get_next_path_position()
	var direction: Vector2 = (next_pos - npc.global_position).normalized()
	
	# If nav path is not yet ready (direction is zero), fall back to raw flee direction
	if direction.length_squared() < 0.01:
		direction = _initial_flee_direction

	# Move at boosted speed
	var boost_speed = npc.stats.move_speed * sprint_speed_multiplier
	var desired_velocity = direction * boost_speed
	
	# Send to nav agent for avoidance
	npc.nav_agent.set_velocity(desired_velocity)

	blackboard.set_var(direction_var, direction)
	
	return RUNNING

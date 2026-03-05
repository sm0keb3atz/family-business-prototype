@tool
extends BTAction
## Picks a random point within [member wander_radius] of the agent's spawn
## position and uses NavigationAgent2D to pathfind toward it.
## Returns SUCCESS when the agent arrives.

@export var wander_radius: float = 150.0
## Blackboard variable that stores the movement direction for AnimationComponent.
@export var direction_var: StringName = &"move_direction"

var _target_set: bool = false

func _generate_name() -> String:
	return "Wander (radius: %s)" % wander_radius

func _enter() -> void:
	_target_set = false
	var npc: NPC = agent as NPC
	if not npc or not npc.nav_agent:
		return

	# Pick a random point within wander_radius of spawn
	var random_offset := Vector2(
		randf_range(-wander_radius, wander_radius),
		randf_range(-wander_radius, wander_radius)
	)
	var target_point: Vector2 = npc.spawn_position + random_offset
	npc.nav_agent.target_position = target_point
	_target_set = true

func _tick(_delta: float) -> Status:
	var npc: NPC = agent as NPC
	if not npc or not npc.movement_component or not npc.nav_agent:
		return FAILURE

	# Police should never wander while wanted — force search behavior instead
	if npc.role == NPC.Role.POLICE:
		var hm: Node = npc.get_node_or_null("/root/HeatManager")
		if hm and hm.wanted_stars >= 1:
			return FAILURE

	if not _target_set:
		return FAILURE

	# Pause movement while interacting with the player
	if blackboard.get_var(&"is_interacting", false):
		npc.movement_component.move(Vector2.ZERO)
		return RUNNING

	if npc.nav_agent.is_navigation_finished():
		# Arrived — stop moving
		npc.movement_component.move(Vector2.ZERO)
		if npc.animation_component:
			npc.animation_component.update_animation(Vector2.ZERO)
		return SUCCESS

	# Get next path position from nav agent
	var next_pos: Vector2 = npc.nav_agent.get_next_path_position()
	var direction: Vector2 = (next_pos - npc.global_position).normalized()
	var desired_velocity: Vector2 = direction * npc.stats.move_speed
	
	# Send to nav agent for avoidance
	npc.nav_agent.set_velocity(desired_velocity)

	# Store direction on blackboard for other tasks if needed
	blackboard.set_var(direction_var, direction)
	
	return RUNNING

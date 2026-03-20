@tool
extends BTAction
## Follows the player as a companion.
## Optimized for girlfriends/following NPCs.

@export var stop_distance: float = 120.0
@export var resume_distance: float = 180.0
@export var sprint_distance: float = 400.0
@export var fail_on_arrival: bool = false

func _generate_name() -> String:
	return "Companion Follow"

func _tick(_delta: float) -> Status:
	var npc: NPC = agent as NPC
	if not npc or not npc.nav_agent:
		return FAILURE
	
	var player = npc.get_tree().get_first_node_in_group("player")
	if not player:
		return FAILURE
		
	var dist = npc.global_position.distance_to(player.global_position)
	
	# Determine if we should move
	var is_moving = !npc.nav_agent.is_navigation_finished()
	
	if dist > resume_distance or (is_moving and dist > stop_distance):
		npc.nav_agent.target_position = player.global_position
		
		var next_pos = npc.nav_agent.get_next_path_position()
		var dir = npc.global_position.direction_to(next_pos)
		
		# Match player's speed roughly if far away, otherwise use base speed
		var speed = npc.stats.move_speed
		if dist > sprint_distance:
			speed *= 1.2 # Catch up speed
			
		npc.nav_agent.set_velocity(dir * speed)
		return RUNNING
	else:
		npc.nav_agent.set_velocity(Vector2.ZERO)
		# Face the player when stopped
		if npc.animation_component:
			var look_dir = npc.global_position.direction_to(player.global_position)
			npc.animation_component.last_direction = look_dir
		return FAILURE if fail_on_arrival else SUCCESS

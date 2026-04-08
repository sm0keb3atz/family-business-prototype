@tool
extends BTAction
## Navigates toward blackboard `approach_target` (Node2D), updating each tick for moving targets.

@export var distance_threshold: float = 75.0
@export var speed_multiplier: float = 1.0

func _generate_name() -> String:
	return "Approach Blackboard Target"

func _tick(_delta: float) -> Status:
	var npc: NPC = agent as NPC
	if not npc or not npc.nav_agent or not blackboard:
		return FAILURE

	if not blackboard.has_var(&"approach_target"):
		return FAILURE

	var target: Node2D = null
	var raw_target: Variant = blackboard.get_var(&"approach_target", null)
	if is_instance_valid(raw_target) and raw_target is Node2D:
		target = raw_target
	if not is_instance_valid(target):
		return FAILURE

	var lkp: Vector2 = target.global_position
	blackboard.set_var(&"last_known_position", lkp)

	var dist: float = npc.global_position.distance_to(lkp)
	if dist <= distance_threshold:
		npc.nav_agent.set_velocity(Vector2.ZERO)
		return SUCCESS

	npc.nav_agent.target_position = lkp

	var next_pos: Vector2 = npc.nav_agent.get_next_path_position()
	var direction: Vector2 = (next_pos - npc.global_position).normalized()
	var speed: float = npc.stats.move_speed * speed_multiplier
	if dist < 200.0:
		speed *= 0.7
	npc.nav_agent.set_velocity(direction * speed)
	return RUNNING

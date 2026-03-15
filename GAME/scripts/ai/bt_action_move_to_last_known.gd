@tool
extends BTAction
class_name BTActionMoveToLastKnown

@export var predict_velocity: bool = true
@export var speed_multiplier: float = 1.0
@export var tolerance: float = 20.0

## Maximum seconds of projection for intercept prediction.
const MAX_PREDICTION_TIME: float = 2.0
## Maximum distance the projected intercept may extend from LKP.
const MAX_PROJECTION_DIST: float = 400.0

func _tick(delta: float) -> Status:
	if not agent or not blackboard:
		return FAILURE

	var nav_agent: NavigationAgent2D = agent.get_node_or_null("%NavigationAgent2D")
	if not nav_agent:
		return FAILURE

	if not blackboard.has_var(&"last_known_position"):
		return FAILURE

	var last_known: Vector2 = blackboard.get_var(&"last_known_position", Vector2.ZERO)
	if last_known == Vector2.ZERO:
		return FAILURE

	# ── Confidence-scaled intercept logic ─────────────────────────────
	# High confidence = aggressive projection. Low confidence = go directly to LKP.
	var confidence: float = IntelConfidence.get_current_confidence(blackboard)
	var lkv: Vector2 = blackboard.get_var(&"last_known_velocity", Vector2.ZERO)
	var target_pos: Vector2 = last_known

	if lkv.length() > 50.0 and confidence > 0.2:
		var dist: float = agent.global_position.distance_to(last_known)
		var time_to_reach: float = minf(dist / agent.stats.move_speed, MAX_PREDICTION_TIME)
		# Scale projection by confidence — low confidence = cautious, high = aggressive
		var projection: Vector2 = lkv * time_to_reach * 0.8 * confidence
		if projection.length() > MAX_PROJECTION_DIST * confidence:
			projection = projection.normalized() * MAX_PROJECTION_DIST * confidence
		target_pos = last_known + projection

	# FLANKING/SURROUND LOGIC: Each officer approaches from a slightly different angle
	if not blackboard.has_var(&"approach_offset"):
		var perp: Vector2 = Vector2(-lkv.y, lkv.x).normalized() if lkv != Vector2.ZERO else Vector2.UP
		if randf() < 0.5: perp = -perp
		var dist: float = agent.global_position.distance_to(last_known)
		var dist_factor: float = clampf(dist / 500.0, 0.3, 1.0)
		var offset: Vector2 = perp * randf_range(60.0, 200.0) * dist_factor
		blackboard.set_var(&"approach_offset", offset)

	var approach_target: Vector2 = target_pos + blackboard.get_var(&"approach_offset", Vector2.ZERO)

	# Validate target against nav mesh (edge margin + leash)
	var map: RID = nav_agent.get_navigation_map()
	var result: Dictionary = NavTargetValidator.validate_target(map, approach_target, last_known)
	if result.valid:
		approach_target = result.point
	else:
		approach_target = NavigationServer2D.map_get_closest_point(map, last_known)

	nav_agent.target_position = approach_target

	var dist_to_target: float = agent.global_position.distance_to(approach_target)

	# Transition to search if we arrive at the intercept/flank point
	if dist_to_target <= tolerance or nav_agent.is_navigation_finished():
		blackboard.set_var(&"search_anchor", target_pos) # Search the INTERCEPT point
		blackboard.set_var(&"is_searching", true)
		blackboard.set_var(&"last_known_position", Vector2.ZERO)
		# Clear offset for next time
		blackboard.erase_var(&"approach_offset")
		return SUCCESS

	var movement = agent.get_node_or_null("%MovementComponent")
	var animation = agent.get_node_or_null("%AnimationComponent")
	
	var next_path_pos: Vector2 = nav_agent.get_next_path_position()
	var dir: Vector2 = agent.global_position.direction_to(next_path_pos)
	
	# Calculate speed with multiplier
	var speed = agent.stats.move_speed * speed_multiplier
		
	var vel = dir * speed
	nav_agent.set_velocity(vel)
	
	return RUNNING

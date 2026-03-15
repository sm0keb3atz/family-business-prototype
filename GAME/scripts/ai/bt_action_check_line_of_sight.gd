@tool
extends BTAction
class_name BTActionCheckLineOfSight

@export var max_distance: float = 600.0

## Throttle interval — raycasts happen at most this often (seconds).
const LOS_CHECK_INTERVAL: float = 0.15

var _last_check_time: float = 0.0
var _cached_result: bool = false

func _enter() -> void:
	_last_check_time = 0.0
	_cached_result = false

func _tick(delta: float) -> Status:
	if not agent or not blackboard:
		return FAILURE

	var raw_target = blackboard.get_var(&"target", null)
	if not raw_target or not is_instance_valid(raw_target):
		return FAILURE
	var target := raw_target as Node2D
	if not target:
		return FAILURE

	# ── Throttle: return cached result if checked recently ────────────
	var now: float = Time.get_ticks_msec() / 1000.0
	if _last_check_time > 0.0 and (now - _last_check_time) < LOS_CHECK_INTERVAL:
		return SUCCESS if _cached_result else FAILURE
	_last_check_time = now

	# ── Distance check ────────────────────────────────────────────────
	var detection_dist: float = max_distance
	var pol_comp = agent.get_node_or_null("PoliceDetectionComponent")
	var dlr_comp = agent.get_node_or_null("DealerDetectionComponent")
	if pol_comp:
		detection_dist = pol_comp.detection_radius
	elif dlr_comp:
		detection_dist = dlr_comp.detection_radius

	var distance: float = agent.global_position.distance_to(target.global_position)
	if distance > detection_dist:
		_cached_result = false
		blackboard.set_var(&"has_line_of_sight", false)
		return FAILURE

	# ── Raycast ───────────────────────────────────────────────────────
	var space_state = agent.get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(agent.global_position, target.global_position, 1)
	query.exclude = [agent.get_rid()]
	var result = space_state.intersect_ray(query)

	if result:
		# Hit a wall — no LOS
		_cached_result = false
		blackboard.set_var(&"has_line_of_sight", false)
		return FAILURE
	else:
		# Clear LOS
		_cached_result = true
		blackboard.set_var(&"has_line_of_sight", true)
		blackboard.set_var(&"last_known_position", target.global_position)
		blackboard.set_var(&"last_seen_time", now)

		# ── Confidence: fresh sighting = high confidence ──────────
		var conf: float = IntelConfidence.calculate_confidence(distance, true)
		blackboard.set_var(&"confidence", conf)

		# Hysteresis: only clear is_searching if cooldown period expired
		var search_cooldown_until: float = blackboard.get_var(&"search_cooldown_until", 0.0)
		if now > search_cooldown_until:
			blackboard.set_var(&"is_searching", false)

		# Shared Intel: Broadcast to all police (Police only)
		if agent.role == NPC.Role.POLICE and agent.has_node("/root/HeatManager"):
			var vel: Vector2 = target.velocity if target is CharacterBody2D else Vector2.ZERO
			agent.get_node("/root/HeatManager").broadcast_player_position(target.global_position, vel)

		return SUCCESS

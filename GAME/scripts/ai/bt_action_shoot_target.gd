@tool
extends BTAction
class_name BTActionShootTarget

@export var preferred_min_range: float = 150.0
@export var preferred_max_range: float = 320.0
@export var strafe_interval_min: float = 0.45
@export var strafe_interval_max: float = 1.2
@export var burst_shots_min: int = 2
@export var burst_shots_max: int = 5
@export var burst_pause_min: float = 0.2
@export var burst_pause_max: float = 0.75
@export var aim_jitter_degrees: float = 5.0
@export var speed_multiplier: float = 0.85

const NEXT_FIRE_TIME_KEY: StringName = &"_combat_next_fire_time"
const BURST_SHOTS_LEFT_KEY: StringName = &"_combat_burst_shots_left"
const BURST_END_TIME_KEY: StringName = &"_combat_burst_end_time"
const NEXT_STRAFE_TIME_KEY: StringName = &"_combat_next_strafe_time"
const CURRENT_STRAFE_DIR_KEY: StringName = &"_combat_strafe_direction"
const AGGRESSION_KEY: StringName = &"_combat_aggression"
const REACTION_KEY: StringName = &"_combat_reaction"
const JITTER_KEY: StringName = &"_combat_aim_jitter"

func _enter() -> void:
	if not blackboard:
		return
	_ensure_combat_profile()

func _tick(delta: float) -> Status:
	if not agent or not blackboard:
		return FAILURE
		
	var raw_target = blackboard.get_var(&"target", null)
	if not raw_target or not is_instance_valid(raw_target):
		return FAILURE
	var target := raw_target as Node2D
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
		
	# Leniency Check: Don't shoot if the player is no longer at combat heat level (Police only)
	if agent.role == NPC.Role.POLICE:
		var hm = agent.get_node_or_null("/root/HeatManager")
		if hm and hm.wanted_stars < 2:
			return FAILURE
		
	var weapon_holder = agent.get_node_or_null("%WeaponHolderComponent")
	if not weapon_holder or not weapon_holder.current_weapon:
		return FAILURE
		
	# Real-time Line of Sight check (populated by detection components)
	if not blackboard.get_var(&"has_line_of_sight", false):
		return FAILURE
		
	# Real-time Range check (against detection components)
	var detection_dist: float = 600.0 # Default fallback
	var pol_comp = agent.get_node_or_null("PoliceDetectionComponent")
	var dlr_comp = agent.get_node_or_null("DealerDetectionComponent")
	if pol_comp:
		detection_dist = pol_comp.detection_radius
	elif dlr_comp:
		detection_dist = dlr_comp.detection_radius
		
	var distance: float = agent.global_position.distance_to(target.global_position)
	if distance > detection_dist:
		return FAILURE
		
	var now: float = Time.get_ticks_msec() / 1000.0
	var weapon_pivot = agent.get_node_or_null("%WeaponPivot")
	if weapon_pivot:
		var jitter = blackboard.get_var(JITTER_KEY, aim_jitter_degrees)
		var offset: Vector2 = (target.global_position - weapon_pivot.global_position).normalized()
		offset = offset.rotated(deg_to_rad(randf_range(-jitter, jitter)))
		weapon_pivot.look_at(weapon_pivot.global_position + offset)

	var nav_agent = agent.get_node_or_null("%NavigationAgent2D")
	var movement = agent.get_node_or_null("%MovementComponent")
	var animation = agent.get_node_or_null("%AnimationComponent")
	_update_combat_movement(target, now, nav_agent, movement, animation)

	if _can_fire_now(now):
		weapon_holder.fire()
		_schedule_next_shot(now, weapon_holder)
	
	return RUNNING

func _ensure_combat_profile() -> void:
	if blackboard.has_var(AGGRESSION_KEY):
		return

	# Per-officer profile avoids synchronized movement/firing.
	blackboard.set_var(AGGRESSION_KEY, randf_range(0.85, 1.2))
	blackboard.set_var(REACTION_KEY, randf_range(0.9, 1.25))
	blackboard.set_var(JITTER_KEY, randf_range(maxf(1.0, aim_jitter_degrees * 0.4), aim_jitter_degrees * 1.25))
	blackboard.set_var(CURRENT_STRAFE_DIR_KEY, 1.0 if randf() < 0.5 else -1.0)
	blackboard.set_var(BURST_SHOTS_LEFT_KEY, 0)
	blackboard.set_var(NEXT_FIRE_TIME_KEY, 0.0)
	blackboard.set_var(BURST_END_TIME_KEY, 0.0)
	blackboard.set_var(NEXT_STRAFE_TIME_KEY, 0.0)

func _update_combat_movement(target: Node2D, now: float, nav_agent: NavigationAgent2D, movement: Node, animation: Node) -> void:
	if not nav_agent:
		if movement:
			movement.move_velocity(Vector2.ZERO)
		if animation:
			animation.update_animation(Vector2.ZERO)
		return

	var to_target: Vector2 = target.global_position - agent.global_position
	var dist: float = to_target.length()
	if dist <= 0.001:
		return

	var dir_to_target: Vector2 = to_target / dist
	var strafe_dir: float = blackboard.get_var(CURRENT_STRAFE_DIR_KEY, 1.0)
	if now >= blackboard.get_var(NEXT_STRAFE_TIME_KEY, 0.0):
		if randf() < 0.65:
			strafe_dir *= -1.0
		blackboard.set_var(CURRENT_STRAFE_DIR_KEY, strafe_dir)
		blackboard.set_var(NEXT_STRAFE_TIME_KEY, now + randf_range(strafe_interval_min, strafe_interval_max))

	var aggression: float = blackboard.get_var(AGGRESSION_KEY, 1.0)
	var desired: Vector2 = Vector2.ZERO

	if dist < preferred_min_range:
		desired = -dir_to_target
	elif dist > preferred_max_range:
		desired = dir_to_target
	else:
		var orbit: Vector2 = Vector2(-dir_to_target.y, dir_to_target.x) * strafe_dir
		desired = orbit + (dir_to_target * 0.15 * strafe_dir)

	desired = desired.normalized() * agent.stats.move_speed * speed_multiplier * aggression
	nav_agent.set_velocity(desired)

func _can_fire_now(now: float) -> bool:
	if not blackboard:
		return true

	var burst_end_time: float = blackboard.get_var(BURST_END_TIME_KEY, 0.0)
	if burst_end_time > now:
		return false

	var next_fire_time: float = blackboard.get_var(NEXT_FIRE_TIME_KEY, 0.0)
	return now >= next_fire_time

func _schedule_next_shot(now: float, weapon_holder: Node) -> void:
	if not blackboard:
		return

	var shots_left: int = blackboard.get_var(BURST_SHOTS_LEFT_KEY, 0)
	if shots_left <= 0:
		shots_left = randi_range(burst_shots_min, burst_shots_max)

	shots_left -= 1
	blackboard.set_var(BURST_SHOTS_LEFT_KEY, shots_left)

	var fire_rate: float = 0.2
	if weapon_holder and weapon_holder.current_weapon:
		var w_data = weapon_holder.current_weapon.get("weapon_data")
		if w_data:
			fire_rate = w_data.fire_rate

	var reaction: float = blackboard.get_var(REACTION_KEY, 1.0)
	var cadence_jitter: float = randf_range(0.85, 1.2)
	blackboard.set_var(NEXT_FIRE_TIME_KEY, now + (fire_rate * reaction * cadence_jitter))

	if shots_left <= 0:
		blackboard.set_var(BURST_END_TIME_KEY, now + randf_range(burst_pause_min, burst_pause_max))

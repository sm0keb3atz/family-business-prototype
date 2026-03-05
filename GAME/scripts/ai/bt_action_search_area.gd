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
var _original_anchor: Vector2 = Vector2.ZERO
var _scan_pause: float = 0.0 # Remaining time for stop-and-scan

## Maximum distance the search anchor may drift from its starting position.
const MAX_ANCHOR_DRIFT: float = 800.0
## Search phase timing thresholds (seconds).
const PHASE_A_END: float = 3.0   # Secure last known position
const PHASE_B_END: float = 12.0  # Directed sweep along velocity cone
const PHASE_C_END: float = 30.0  # Expanding ring search
## After PHASE_C_END, de-escalate (return SUCCESS).

## Stop-and-scan duration at anchor (Phase A).
const SCAN_DURATION: float = 1.2

func _generate_name() -> String:
	return "Search Area (radius: %s)" % search_radius

func _enter() -> void:
	_target_set = false
	_time_searching = 0.0
	_scan_pause = 0.0
	# Snapshot the original anchor so we can cap drift
	_original_anchor = Vector2.ZERO
	if blackboard:
		_original_anchor = blackboard.get_var(&"search_anchor", Vector2.ZERO)
		# Set search cooldown so LOS flicker doesn't instantly cancel us
		blackboard.set_var(&"search_cooldown_until", (Time.get_ticks_msec() / 1000.0) + 2.0)
	# Give this NPC a unique search bias and glide variance
	if blackboard:
		var off: Vector2 = Vector2(randf_range(-400, 400), randf_range(-400, 400))
		blackboard.set_var(&"search_offset", off)
		var g_var: float = randf_range(0.2, 0.9)
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
	
	# ── Phase D: De-escalate ──────────────────────────────────────────
	if _time_searching > PHASE_C_END:
		if npc.movement_component: npc.movement_component.move_velocity(Vector2.ZERO)
		if npc.animation_component: npc.animation_component.update_animation(Vector2.ZERO)
		return SUCCESS # Let parent handle de-escalation
	
	# ── Phase A: Secure — move to anchor, then stop-and-scan ─────────
	if _time_searching <= PHASE_A_END:
		return _phase_secure(delta, npc, anchor)
	
	# ── Phase B & C: Directed sweep / Expanding ring ─────────────────
	return _phase_sweep(delta, npc, anchor)

## Phase A: Move to the search anchor, then pause for a scan.
func _phase_secure(delta: float, npc: NPC, anchor: Vector2) -> Status:
	if blackboard.get_var(&"is_interacting", false):
		if npc.movement_component: npc.movement_component.move_velocity(Vector2.ZERO)
		return RUNNING
	
	# If within arrival tolerance OR scan already started, do the scan pause
	var dist_to_anchor: float = npc.global_position.distance_to(anchor)
	if dist_to_anchor <= 50.0 or _scan_pause > 0.0:
		# Stop and scan
		if npc.movement_component: npc.movement_component.move_velocity(Vector2.ZERO)
		if npc.animation_component: npc.animation_component.update_animation(Vector2.ZERO)
		if _scan_pause <= 0.0:
			_scan_pause = SCAN_DURATION
		_scan_pause -= delta
		return RUNNING
	
	# Move toward anchor
	npc.nav_agent.target_position = anchor
	if npc.nav_agent.is_navigation_finished():
		_scan_pause = SCAN_DURATION
		return RUNNING
	
	var next_pos: Vector2 = npc.nav_agent.get_next_path_position()
	var direction: Vector2 = npc.global_position.direction_to(next_pos)
	npc.nav_agent.set_velocity(direction * npc.stats.move_speed)
	blackboard.set_var(direction_var, direction)
	return RUNNING

## Phase B (directed sweep) and Phase C (expanding ring).
func _phase_sweep(delta: float, npc: NPC, anchor: Vector2) -> Status:
	var lkv: Vector2 = blackboard.get_var(&"last_known_velocity", Vector2.ZERO)
	
	# Drift anchor along velocity (capped)
	if lkv.length() > 20.0:
		var glide_factor: float = blackboard.get_var(&"glide_variance", 0.4)
		var new_anchor: Vector2 = anchor + (lkv * glide_factor * delta)
		if _original_anchor != Vector2.ZERO and new_anchor.distance_to(_original_anchor) > MAX_ANCHOR_DRIFT:
			new_anchor = _original_anchor + (_original_anchor.direction_to(new_anchor) * MAX_ANCHOR_DRIFT)
		blackboard.set_var(&"search_anchor", new_anchor)
		anchor = new_anchor

	# Determine search radius based on phase
	var is_phase_b: bool = _time_searching <= PHASE_B_END
	var current_radius: float
	if is_phase_b:
		# Phase B: Fixed radius, strong directional bias
		current_radius = search_radius
	else:
		# Phase C: Expanding radius, relaxed bias
		var expansion_rate: float = 15.0
		current_radius = search_radius + ((_time_searching - PHASE_B_END) * expansion_rate)
		current_radius = min(current_radius, search_radius * 5.0)
	
	# Apply individual offset
	var offset: Vector2 = blackboard.get_var(&"search_offset", Vector2.ZERO)
	var effective_anchor: Vector2 = anchor + offset

	if not _target_set:
		var min_radius: float = current_radius * 0.3
		var valid_point_found: bool = false
		var attempts: int = 0
		var map: RID = npc.nav_agent.get_navigation_map()
		var search_role: String = blackboard.get_var(&"search_role", "sweeper")
		
		while not valid_point_found and attempts < 20:
			var random_dir: Vector2 = _get_search_direction(lkv, search_role, is_phase_b)
			var random_dist: float = randf_range(min_radius, current_radius)
			var desired_point: Vector2 = effective_anchor + (random_dir * random_dist)
			
			# Validate through NavTargetValidator
			var result: Dictionary = NavTargetValidator.validate_target(
				map, desired_point, anchor, current_radius * 2.0
			)
			
			if not result.valid:
				attempts += 1
				continue
			
			var valid_point: Vector2 = result.point
			
			# Avoid shuffling — require minimum travel distance
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
		if npc.movement_component: npc.movement_component.move_velocity(Vector2.ZERO)
		if npc.animation_component: npc.animation_component.update_animation(Vector2.ZERO)
		_target_set = false
		return RUNNING

	var next_pos: Vector2 = npc.nav_agent.get_next_path_position()
	var direction: Vector2 = npc.global_position.direction_to(next_pos)
	var desired_velocity: Vector2 = direction * (npc.stats.move_speed * speed_multiplier)
	npc.nav_agent.set_velocity(desired_velocity)
	blackboard.set_var(direction_var, direction)
	return RUNNING

## Returns a biased search direction based on the officer's role and phase.
func _get_search_direction(lkv: Vector2, role: String, is_directed: bool) -> Vector2:
	var random_dir: Vector2 = Vector2.RIGHT.rotated(randf_range(0, TAU))
	
	if lkv.length() < 20.0:
		return random_dir
	
	var momentum_dir: Vector2 = lkv.normalized()
	
	match role:
		"tracker":
			# Strongly biased along momentum corridor (90% in 90° cone)
			if randf() < 0.9:
				var base_angle: float = momentum_dir.angle()
				random_dir = Vector2.RIGHT.rotated(base_angle + randf_range(-PI/4.0, PI/4.0))
		"cutoff":
			# Biased perpendicular to momentum (intercept exits)
			if randf() < 0.85:
				var perp_angle: float = momentum_dir.angle() + (PI / 2.0 if randf() < 0.5 else -PI / 2.0)
				random_dir = Vector2.RIGHT.rotated(perp_angle + randf_range(-PI/6.0, PI/6.0))
		"sweeper", _:
			# Phase B: 80% in 120° cone. Phase C: uniform random.
			if is_directed and randf() < 0.8:
				var base_angle: float = momentum_dir.angle()
				random_dir = Vector2.RIGHT.rotated(base_angle + randf_range(-PI/3.0, PI/3.0))
	
	return random_dir

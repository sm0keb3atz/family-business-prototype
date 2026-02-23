@tool
extends BTAction
## Walks to the NEXT waypoint in the path and returns SUCCESS on arrival.
## Each NPC gets a random lateral offset so they spread across the sidewalk.

@export var path_markers_var: StringName = &"path_markers"
@export var current_target_var: StringName = &"current_target_index"
@export var direction_var: StringName = &"path_direction"
## How far NPCs can spread sideways from the path center (pixels).
@export var sidewalk_spread: float = 30.0

var _markers: Array = []
var _current_index: int = 0
var _direction: int = 1
var _initialized: bool = false
var _lateral_offset: float = 0.0 # Per-NPC random offset, set once

func _generate_name() -> String:
	return "Follow Path (markers: %s)" % path_markers_var

func _enter() -> void:
	_markers = blackboard.get_var(path_markers_var, [])
	
	if _markers.size() == 0:
		return
	
	if not _initialized:
		# First time: pick random start, direction, and sidewalk position
		_current_index = randi() % _markers.size()
		_direction = 1 if randf() > 0.5 else -1
		_lateral_offset = randf_range(-sidewalk_spread, sidewalk_spread)
		blackboard.set_var(direction_var, _direction)
		_initialized = true
	else:
		# Advance to next waypoint
		_current_index = blackboard.get_var(current_target_var, _current_index)
		_direction = blackboard.get_var(direction_var, _direction)
		_current_index += _direction
		# Wrap around
		if _current_index >= _markers.size():
			_current_index = 0
		elif _current_index < 0:
			_current_index = _markers.size() - 1
	
	blackboard.set_var(current_target_var, _current_index)
	_set_target(_current_index)

func _tick(_delta: float) -> Status:
	var npc: NPC = agent as NPC
	if not npc or not npc.nav_agent or _markers.size() == 0:
		return FAILURE

	# Pause movement while interacting with the player
	if blackboard.get_var(&"is_interacting", false):
		npc.nav_agent.set_velocity(Vector2.ZERO)
		return RUNNING

	# Arrived at waypoint — return SUCCESS so sequence advances to chat/wait
	if npc.nav_agent.is_navigation_finished():
		npc.nav_agent.set_velocity(Vector2.ZERO)
		return SUCCESS

	# Walk toward target
	var next_pos: Vector2 = npc.nav_agent.get_next_path_position()
	var direction: Vector2 = (next_pos - npc.global_position).normalized()
	var desired_velocity: Vector2 = direction * npc.stats.move_speed
	
	npc.nav_agent.set_velocity(desired_velocity)

	return RUNNING

func _set_target(index: int) -> void:
	var npc: NPC = agent as NPC
	var marker_pos: Vector2
	var marker = _markers[index]
	if marker is Marker2D:
		marker_pos = marker.global_position
	elif marker is Vector2:
		marker_pos = marker
	else:
		return
	
	# Calculate perpendicular offset to spread NPCs across the sidewalk
	var next_idx: int = index + _direction
	if next_idx >= _markers.size():
		next_idx = 0
	elif next_idx < 0:
		next_idx = _markers.size() - 1
	
	var next_marker = _markers[next_idx]
	var next_pos: Vector2
	if next_marker is Marker2D:
		next_pos = next_marker.global_position
	elif next_marker is Vector2:
		next_pos = next_marker
	else:
		next_pos = marker_pos + Vector2(1, 0)
	
	# Perpendicular direction to the path segment
	var path_dir: Vector2 = (next_pos - marker_pos).normalized()
	var perp: Vector2 = Vector2(-path_dir.y, path_dir.x)
	
	npc.nav_agent.target_position = marker_pos + perp * _lateral_offset

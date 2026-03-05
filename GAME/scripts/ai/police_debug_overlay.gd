extends Node2D
class_name PoliceDebugOverlay
## Toggleable debug overlay for police NPCs.
## Draws search anchor, nav destination, intercept point, and current BT mode.
## Enable/disable globally via the static DEBUG_POLICE flag.

## Master toggle — set to true to see all police debug visuals.
static var DEBUG_POLICE: bool = true

var _npc: NPC = null
var _font: Font = null

func _ready() -> void:
	_npc = get_parent() as NPC
	z_index = 100
	# Use a default font
	_font = ThemeDB.fallback_font

func _process(_delta: float) -> void:
	if not DEBUG_POLICE or not _npc:
		visible = false
		return
	visible = true
	queue_redraw()

func _draw() -> void:
	if not DEBUG_POLICE or not _npc or not _npc.blackboard:
		return
	
	var origin: Vector2 = Vector2.ZERO # Draw relative to parent NPC
	
	# --- Search Anchor (blue circle) ---
	var search_anchor: Vector2 = _npc.blackboard.get_var(&"search_anchor", Vector2.ZERO)
	if search_anchor != Vector2.ZERO:
		var local_anchor: Vector2 = search_anchor - _npc.global_position
		draw_circle(local_anchor, 12.0, Color(0.2, 0.4, 1.0, 0.6))
		draw_arc(local_anchor, 12.0, 0, TAU, 32, Color(0.3, 0.5, 1.0, 0.9), 2.0)
	
	# --- Nav Destination (green dot) ---
	if _npc.nav_agent and not _npc.nav_agent.is_navigation_finished():
		var dest: Vector2 = _npc.nav_agent.target_position - _npc.global_position
		draw_circle(dest, 6.0, Color(0.2, 1.0, 0.3, 0.7))
	
	# --- Last Known Position (yellow cross) ---
	var lkp: Vector2 = _npc.blackboard.get_var(&"last_known_position", Vector2.ZERO)
	if lkp != Vector2.ZERO:
		var local_lkp: Vector2 = lkp - _npc.global_position
		var cross_size: float = 8.0
		draw_line(local_lkp + Vector2(-cross_size, -cross_size), local_lkp + Vector2(cross_size, cross_size), Color(1.0, 0.9, 0.2, 0.8), 2.0)
		draw_line(local_lkp + Vector2(cross_size, -cross_size), local_lkp + Vector2(-cross_size, cross_size), Color(1.0, 0.9, 0.2, 0.8), 2.0)
	
	# --- BT Mode Label ---
	var mode_text: String = _get_mode_text()
	var role_text: String = _npc.blackboard.get_var(&"search_role", "")
	var label: String = mode_text
	if role_text != "":
		label += " [%s]" % role_text
	
	if _font:
		draw_string(_font, origin + Vector2(-30, -50), label, HORIZONTAL_ALIGNMENT_CENTER, 100, 10, Color(1, 1, 1, 0.9))

func _get_mode_text() -> String:
	if not _npc.blackboard:
		return "?"
	
	var has_los: bool = _npc.blackboard.get_var(&"has_line_of_sight", false)
	var is_searching: bool = _npc.blackboard.get_var(&"is_searching", false)
	var lkp: Vector2 = _npc.blackboard.get_var(&"last_known_position", Vector2.ZERO)
	
	if has_los:
		return "CHASE"
	elif lkp != Vector2.ZERO:
		return "INVESTIGATE"
	elif is_searching:
		return "SEARCH"
	else:
		return "PATROL"

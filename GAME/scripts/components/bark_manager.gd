extends Node
# BarkManager.gd - Autoload
# Manages who is allowed to bark to prevent on-screen clutter.

enum Priority {
	LOW = 0,
	MEDIUM = 1,
	HIGH = 2,
	URGENT = 3 # Top priority for sales
}

const MAX_CONCURRENT_BARKS = 5
const MIN_STICKY_TIME_MS: int = 1500

# Stores active barks: { "npc": node, "priority": int, "time": ms }
var active_barks: Array[Dictionary] = []

# Request permission to bark. Returns true if granted.
# If 'force' is true, it always grants and interrupts the current barker.
func request_bark(npc: Node2D, priority: Priority, force: bool = false) -> bool:
	if not is_instance_valid(npc):
		return false
		
	# 1. If this NPC is already barking, just update it (grant permission)
	for bark in active_barks:
		if bark.npc == npc:
			bark.priority = priority
			bark.time = Time.get_ticks_msec()
			return true
	
	# 2. If we have room, grant it
	if active_barks.size() < MAX_CONCURRENT_BARKS:
		active_barks.append({ "npc": npc, "priority": priority, "time": Time.get_ticks_msec() })
		return true
		
	# 3. If we are full, find someone to replace
	var player = get_tree().get_first_node_in_group("player")
	var npc_dist = npc.global_position.distance_to(player.global_position) if player else 9999.0
	var now = Time.get_ticks_msec()
	
	# Find the "weakest" bark to replace
	var weakest_index = -1
	var lowest_priority = 999
	var oldest_time = now + 1
	var furthest_dist = -1.0
	
	for i in range(active_barks.size()):
		var b = active_barks[i]
		if not is_instance_valid(b.npc): continue
		
		# Priority is the main check
		if b.priority < lowest_priority:
			lowest_priority = b.priority
			weakest_index = i
		elif b.priority == lowest_priority:
			# If same priority, check time and distance
			var b_dist = b.npc.global_position.distance_to(player.global_position) if player else 0.0
			# Replace if it's been long enough AND it's further away
			if (now - b.time) > MIN_STICKY_TIME_MS and b_dist > furthest_dist:
				furthest_dist = b_dist
				weakest_index = i

	# Check if we should override the weakest
	var should_override = force or priority > lowest_priority
	if not should_override and priority == lowest_priority:
		if weakest_index != -1:
			var weakest = active_barks[weakest_index]
			var w_dist = weakest.npc.global_position.distance_to(player.global_position) if player else 0.0
			if (now - weakest.time) > MIN_STICKY_TIME_MS and npc_dist < w_dist - 100.0:
				should_override = true
				
	if should_override and weakest_index != -1:
		var weakest = active_barks[weakest_index]
		# Remove before interrupting to prevent re-entrancy index issues
		active_barks.remove_at(weakest_index)
		
		if is_instance_valid(weakest.npc) and weakest.npc.has_method("interrupt_bark"):
			weakest.npc.interrupt_bark()
		
		active_barks.append({ "npc": npc, "priority": priority, "time": now })
		return true

	return false

# Called by NPC when their bark manually ends or is finished
func clear_bark(npc: Node2D):
	for i in range(active_barks.size() - 1, -1, -1):
		if active_barks[i].npc == npc:
			active_barks.remove_at(i)
			break

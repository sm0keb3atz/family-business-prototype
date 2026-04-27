extends Node2D
## Central Hub for Virtual NPC Simulation.
## Manages a large collection of NPCIdentities as "Ghosts" and realized a subset into "Actors".

@export var realization_radius: float = 2400.0
@export var ghosting_radius: float = 3000.0
@export var max_realized_actors: int = 150
@export var stagger_realization_interval_ms: int = 120 # Increased from 90 to space out promotions
@export var stagger_promotions_per_frame: int = 1 
@export var realizations_per_frame: int = 1
@export var realization_frame_budget_ms: float = 0.5 # Tightened from 0.8
@export var activation_finishes_per_frame: int = 1
@export var activation_finish_budget_ms: float = 0.6 # Tightened from 1.0
@export var post_activation_delay_ms: int = 80 # Increased from 50 to add more buffer
@export var post_activation_finishes_per_frame: int = 1
@export var post_activation_finish_budget_ms: float = 0.3 # Tightened from 0.5
@export var realization_pass_interval: float = 0.25 ## Wall-clock interval for who should realize (not every frame).
@export var spatial_pass_cell_margin: int = 1 ## Extra grid rings around the player so adjacent-territory ghosts farther away still get evaluated.
@export var max_queue_admissions_per_pass: int = 6 ## Prevents stuffing the realization queue in one tick when territory rules flip for many ghosts at once.
@export var dealers_realize_globally: bool = true ## When true, all dealers are realized and never ghostify based on territory.
@export var active_territory_fill_rate: int = 2 ## Max new NPCs to admit to queue per pass for the active territory (forces gradual filling).
@export var neighbor_realization_percent: float = 0.33 ## Fraction of population to maintain in adjacent territories.
@export var debug_realization_logging: bool = false

const GHOST_TICK_RATE: float = 0.1 # Move ghosts every 100ms
@export var ghosts_per_tick: int = 30 # Number of ghosts to move per tick

var identities: Array[NPCIdentity] = []
var realized_count: int = 0
var _ghost_timer: float = 0.0
var _ghost_index: int = 0
var _sync_timer: float = 0.0
const SYNC_INTERVAL: float = 5.0 # Check realized count every 5 seconds

# Master pool of pre-instantiated nodes
var _actor_pool: Array[NPC] = []

# Queue for staggered realization
var _staggered_realization_queue: Array[NPCIdentity] = []
var _realization_queue: Array[NPCIdentity] = []
var _activation_finish_queue: Array[Dictionary] = []
var _post_activation_queue: Array[Dictionary] = []

var _current_territory_id: StringName = &""
## Neighbor territory ids for O(1) lookup (avoid `x in Array` on every NPC when entering a territory).
var _adjacent_territory_set: Dictionary = {}
var _adjacency_map: Dictionary = {} # { territory_id: [neighbor_ids] }
var _identities_by_territory: Dictionary = {} # territory_id -> Array[NPCIdentity]
var _territory_nodes: Dictionary = {} # { territory_id: TerritoryArea }

var _spatial: NPCSpatialHash = NPCSpatialHash.new()
var _dealer_identities: Array[NPCIdentity] = []
## Only identities with a live actor — avoids scanning hundreds of ghosts every frame for ghostify.
var _realized_identities: Array[NPCIdentity] = []

var _queue_admissions_remaining: int = 0
var _territory_transition_cooldown: int = 0
## Cached once per _process to avoid repeated HeatManager lookups in hot paths.
var _player_is_wanted: bool = false
const TRANSITION_RAMP_PASSES: int = 4 ## ~1.0s at 0.25s interval (reduced from 12)
const TRANSITION_ADMISSION_CAP: int = 20 ## Admit up to 20 ghosts to queue per pass (increased from 1)
const TRANSITION_REALIZATIONS_PER_FRAME: int = 5 ## Promote 5 ghosts to actors per frame (increased from 1)
const TRANSITION_ACTIVATIONS_PER_FRAME: int = 5 ## Activate 5 actors (BT/Nav) per frame (increased from 1)
const MAX_GHOSTIFY_PER_FRAME: int = 4 ## Cap ghostify operations per frame to prevent exit-territory spikes.


func _ready() -> void:
	add_to_group("npc_manager")

	# Pre-instantiate the entire master budget at start to eliminate runtime spikes
	call_deferred("_pre_instantiate_pool")
	call_deferred("_initialize_territory_system")

	var pass_timer := Timer.new()
	pass_timer.wait_time = realization_pass_interval
	pass_timer.timeout.connect(_on_realization_pass_timer)
	pass_timer.autostart = true
	add_child(pass_timer)


func _on_realization_pass_timer() -> void:
	_run_realization_desire_pass()


func _pre_instantiate_pool() -> void:
	var npc_scene = load("res://GAME/scenes/characters/npc.tscn")
	# At startup, current_scene may be null (Autoload). Add to self initially.
	# We will lazily reparent them to current_scene on their first realization.
	for i in range(max_realized_actors):
		var npc = npc_scene.instantiate() as NPC
		npc.set_meta(&"managed_by_pool", true)
		
		# Add to tree but keep hidden/disabled
		add_child(npc)
		npc.prewarm_runtime()
		npc.prepare_for_pool()
		_actor_pool.append(npc)
	
	print("NPCManager: Master pool of ", max_realized_actors, " actors created.")

func register_identity(identity: NPCIdentity) -> void:
	if identity.role == NPC.Role.POLICE:
		_log("Registered Police Identity at %s in territory %s" % [identity.global_position, identity.territory_id])
	
	identities.append(identity)
	if identity.role == NPC.Role.DEALER:
		_dealer_identities.append(identity)
	
	# Ensure the ghost has a movement target immediately so it doesn't huddle at the spawn point
	if identity.target_position == Vector2.ZERO:
		_pick_new_ghost_target(identity)
		
	var territory_bucket: Array = _identities_by_territory.get(identity.territory_id, [])
	territory_bucket.append(identity)
	_identities_by_territory[identity.territory_id] = territory_bucket
	_spatial.insert(identity)
	if identity.appearance_data is NPCAppearanceResource:
		(identity.appearance_data as NPCAppearanceResource).bake_for_identity(identity)
	
func unregister_identity(identity: NPCIdentity) -> void:
	if not identity: return
	
	# If currently realized, ghostify him back to the pool
	if identity.is_realized():
		_ghostify(identity)
	
	# If in queue, remove him
	if identity.queued_for_realization:
		var qi := _realization_queue.find(identity)
		if qi >= 0:
			_realization_queue.remove_at(qi)
		identity.queued_for_realization = false
		realized_count -= 1
	if identity.queued_for_staggered_realization:
		var si := _staggered_realization_queue.find(identity)
		if si >= 0:
			_staggered_realization_queue.remove_at(si)
		identity.queued_for_staggered_realization = false
		identity.realization_ready_msec = 0
		realized_count -= 1
	_remove_pending_activation_entries(identity)
	
	_spatial.remove(identity)
	_remove_dealer_tracking(identity)
	_remove_identity_from_territory_index(identity)
	identities.erase(identity)


func _remove_dealer_tracking(identity: NPCIdentity) -> void:
	var idx := _dealer_identities.find(identity)
	if idx >= 0:
		_dealer_identities.remove_at(idx)


func unregister_identities_for_territory(territory_id: StringName, role: int = -1) -> void:
	for i in range(identities.size() - 1, -1, -1):
		var id = identities[i]
		if id.territory_id == territory_id:
			if role == -1 or id.role == role:
				unregister_identity(id)



func count_identities_for_territory(territory_id: StringName, role: int = -1, dealer_kind: StringName = &"") -> int:
	var territory_bucket: Array = _identities_by_territory.get(territory_id, [])
	if role == -1 and dealer_kind == "":
		return territory_bucket.size()
		
	var n: int = 0
	for id in territory_bucket:
		if role != -1 and id.role != role:
			continue
		if role == NPC.Role.DEALER and dealer_kind != &"":
			if id.metadata.get(&"dealer_kind", &"ambient") != dealer_kind:
				continue
		n += 1
	return n


func get_realized_actors_for_territory(territory_id: StringName, role: int = -1) -> Array[NPC]:
	var actors: Array[NPC] = []
	for id in _realized_identities:
		if id.territory_id == territory_id:
			if role == -1 or id.role == role:
				if is_instance_valid(id.current_actor):
					actors.append(id.current_actor)
	return actors


func _check_budget(start_usec: int, budget_ms: float) -> bool:
	return (Time.get_ticks_usec() - start_usec) < (budget_ms * 1000.0)

func _process(delta: float) -> void:
	_player_is_wanted = false
	if has_node("/root/HeatManager"):
		_player_is_wanted = get_node("/root/HeatManager").wanted_stars > 0

	var start_usec = Time.get_ticks_usec()
	# Total manager budget per frame: ~2.0ms
	const TOTAL_BUDGET_MS = 2.0
	
	_process_staggered_realization_queue()
	
	if _check_budget(start_usec, TOTAL_BUDGET_MS):
		_process_activation_finish_queue()
	
	if _check_budget(start_usec, TOTAL_BUDGET_MS):
		_process_post_activation_queue()
		
	if _check_budget(start_usec, TOTAL_BUDGET_MS):
		_process_realization_queue()
	
	_ghost_timer += delta
	if _ghost_timer >= GHOST_TICK_RATE:
		_ghost_timer = 0.0
		_update_ghost_subset()
	
	# Throttle Ghostify Checks (1/10th frequency)
	if Engine.get_frames_drawn() % 10 == 0:
		_refresh_realized_ghostify_only(delta)
	
	_sync_timer += delta
	if _sync_timer >= SYNC_INTERVAL:
		_sync_timer = 0.0
		_recalculate_realized_count()
		if _current_territory_id == &"":
			_initialize_territory_system()


func report_crime(pos: Vector2, radius: float = 2000.0) -> void:
	var radius_sq := radius * radius
	var cell_radius := int(ceili(radius / NPCSpatialHash.CELL_SIZE)) + 1
	var candidates := _spatial.get_nearby(pos, cell_radius)
	var priorities: Array[NPCIdentity] = []
	for id in candidates:
		if id.role != NPC.Role.POLICE or id.is_realized():
			continue
		if id.global_position.distance_squared_to(pos) < radius_sq:
			priorities.append(id)

	# Combat Throttling: Realize at most 3 police per crime report to prevent "Police Flooding"
	const MAX_CRIME_REALIZATIONS := 3
	if priorities.size() > MAX_CRIME_REALIZATIONS:
		priorities.sort_custom(func(a: NPCIdentity, b: NPCIdentity) -> bool:
			return a.global_position.distance_squared_to(pos) < b.global_position.distance_squared_to(pos)
		)
		priorities.resize(MAX_CRIME_REALIZATIONS)

	for id in priorities:
		if id.queued_for_realization or id.queued_for_staggered_realization:
			continue
			
		# Force realization even if at budget limit by displacing a customer
		if realized_count >= max_realized_actors:
			if not _request_displacement():
				continue # Budget is truly full (no displaceable actors)
				
		# Staggered realization is mandatory to prevent frame spikes.
		# We use push_front so crime-responders get into the world ASAP but still staggered.
		id.queued_for_staggered_realization = true
		id.realization_ready_msec = _next_staggered_realization_ready_msec()
		_staggered_realization_queue.push_front(id)
		realized_count += 1


func _recalculate_realized_count() -> void:
	var actual: int = 0
	for id in identities:
		if id.is_realized():
			actual += 1
	realized_count = actual

func _update_ghost_subset() -> void:
	if identities.is_empty(): return
	
	# Update a smaller subset per frame to prevent spikes
	var count_to_process = 5 
	var processed = 0
	
	while processed < count_to_process and processed < identities.size():
		var id = identities[_ghost_index]
		
		if not id.is_realized():
			if id.target_position != Vector2.ZERO:
				var dist_sq = id.global_position.distance_squared_to(id.target_position)
				if dist_sq < 2500.0:
					_pick_new_ghost_target(id)
				else:
					var old_pos: Vector2 = id.global_position
					var dir = (id.target_position - id.global_position).normalized()
					id.global_position += dir * 200.0 * GHOST_TICK_RATE
					_spatial.update_after_move(id, old_pos)
		
		_ghost_index = (_ghost_index + 1) % identities.size()
		processed += 1


func _queue_priority_for_pass(id: NPCIdentity) -> int:
	## Lower = admitted first when max_queue_admissions_per_pass is hit (e.g. crossing a territory border).
	if id.metadata.get("is_girlfriend", false):
		return 0

	# Top priority: Police when wanted
	if id.role == NPC.Role.POLICE and _player_is_wanted:
		return 0
	
	# Normal priorities
	if id.role == NPC.Role.DEALER:
		return 1
	if id.role == NPC.Role.POLICE:
		return 2
	return 3



func _world_pos_for_identity(id: NPCIdentity) -> Vector2:
	if id.is_realized():
		if is_instance_valid(id.current_actor):
			return id.current_actor.global_position
	return id.global_position


func _is_inside_transition_realization_window(player: Node2D, pos: Vector2) -> bool:
	return true


func _compute_should_realize(id: NPCIdentity, player: Node2D = null) -> bool:
	# Persistence for special NPCs (Girlfriends)
	if id.is_realized() and is_instance_valid(id.current_actor):
		if id.current_actor.is_in_group("girlfriend"):
			return true
	if id.metadata.get("is_girlfriend", false):
		return true

	var territory_id = id.territory_id
	var is_active: bool = (territory_id == _current_territory_id and _current_territory_id != &"")
	var is_adjacent: bool = (_current_territory_id != &"" and _adjacent_territory_set.has(territory_id))
	
	if player == null:
		player = get_tree().get_first_node_in_group("player") as Node2D
	
	# Territory-First Realization with Performance Balancing:
	if is_active:
		# Current turf: 100% realization for maximum density and interaction.
		return true
		
	if is_adjacent:
		# Neighboring turf: Realize 33% of the population.
		# This provides visual "padding" and pre-loading without tanking the frame rate.
		# Dealers always realize if in neighbors so they are ready for the player.
		if id.role == NPC.Role.DEALER:
			return true
		return (id.get_instance_id() % 3 == 0)
	
	var pos: Vector2 = _world_pos_for_identity(id)
	
	if id.role == NPC.Role.DEALER:
		if dealers_realize_globally:
			return true
		return is_active
		
	elif id.role == NPC.Role.POLICE:
		# Pursuit Persistence: If a cop is already realized and in combat/pursuit, 
		# keep them realized even if they move out of jurisdiction.
		if id.is_realized() and is_instance_valid(id.current_actor):
			if id.current_actor.blackboard and id.current_actor.blackboard.get_var(&"is_in_combat", false):
				return true
		
		# Standard jurisdiction
		if is_active or is_adjacent:
			return true
			
		# If wanted, allow cops within a tight radius to realize even outside jurisdiction
		if _player_is_wanted and player:
			var dist_sq: float = player.global_position.distance_squared_to(pos)
			if dist_sq < realization_radius * realization_radius:
				# Only realize a subset of distant cops to prevent dog-piling spikes
				return (id.get_instance_id() % 2 == 0)
				
		return false

	# If not in active/adjacent territories, use the standard proximity priming
	if _current_territory_id != &"":
		if player:
			var dist_sq: float = player.global_position.distance_squared_to(pos)
			if dist_sq < (realization_radius * 0.5) * (realization_radius * 0.5):
				return (id.get_instance_id() % 5 == 0) # Priming: 20%

	if _current_territory_id == &"" or territory_id == &"":
		if player:
			var dist_sq: float = player.global_position.distance_squared_to(pos)
			if dist_sq < realization_radius * realization_radius:
				return true
	return false


func _run_realization_desire_pass() -> void:
	if identities.is_empty():
		return
	
	_player_is_wanted = false
	if has_node("/root/HeatManager"):
		_player_is_wanted = get_node("/root/HeatManager").wanted_stars > 0

	var player = get_tree().get_first_node_in_group("player") as Node2D
	if not player:
		return

	# 1. Global Dealer Pass (Optimized O(1) access)
	if dealers_realize_globally:
		var dealer_budget := 15 if _territory_transition_cooldown > 0 else 2
		for id in _dealer_identities:
			if dealer_budget <= 0: break
			if not id.is_realized() and not id.queued_for_realization and not id.queued_for_staggered_realization:
				if realized_count < max_realized_actors:
					id.queued_for_staggered_realization = true
					id.realization_ready_msec = _next_staggered_realization_ready_msec()
					_staggered_realization_queue.append(id)
					realized_count += 1
					dealer_budget -= 1

	# 2. Direct Territory Population (The "Set in Stone" Optimization)
	# Instead of searching the map, we look directly at the buckets for active turfs.
	var p0_candidates: Array[NPCIdentity] = [] # High priority (Wanted Police / Dealers)
	var p1_candidates: Array[NPCIdentity] = [] # Standard NPCs
	
	var active_turfs: Array[StringName] = []
	if _current_territory_id != &"":
		active_turfs.append(_current_territory_id)
		for adj in _adjacent_territory_set:
			active_turfs.append(adj)
			
	for tid in active_turfs:
		var bucket = _identities_by_territory.get(tid, [])
		for id in bucket:
			if id.is_realized() or id.queued_for_realization or id.queued_for_staggered_realization:
				continue
				
			var priority = _queue_priority_for_pass(id)
			if priority <= 1: # Police (wanted) or Dealers
				p0_candidates.append(id)
			else:
				p1_candidates.append(id)

	# 3. Proximity Fallback (For NPCs in transition or between territories)
	var nearby = _spatial.get_nearby(player.global_position, int(ceili(realization_radius / NPCSpatialHash.CELL_SIZE)))
	for id in nearby:
		if id.is_realized() or id.queued_for_realization or id.queued_for_staggered_realization:
			continue
		# Only add if not already covered by territory logic to avoid duplicates
		if not _current_territory_id == id.territory_id and not _adjacent_territory_set.has(id.territory_id):
			var priority = _queue_priority_for_pass(id)
			if priority <= 1:
				p0_candidates.append(id)
			else:
				p1_candidates.append(id)

	# 4. Admission Execution
	# Use the high-speed admission cap we set during transitions
	_queue_admissions_remaining = TRANSITION_ADMISSION_CAP if _territory_transition_cooldown > 0 else max_queue_admissions_per_pass
	
	for bucket in [p0_candidates, p1_candidates]:
		for id in bucket:
			if _queue_admissions_remaining <= 0: break
			
			var should := _compute_should_realize(id, player)
			if should:
				_queue_admissions_remaining -= 1
				id.queued_for_staggered_realization = true
				id.realization_ready_msec = _next_staggered_realization_ready_msec()
				_staggered_realization_queue.append(id)
				realized_count += 1
		if _queue_admissions_remaining <= 0: break
			
	if _territory_transition_cooldown > 0:
		_territory_transition_cooldown -= 1



func _refresh_realized_ghostify_only(_delta: float) -> void:
	if _realized_identities.is_empty():
		return
	for i in range(_realized_identities.size() - 1, -1, -1):
		var rid: NPCIdentity = _realized_identities[i]
		if not is_instance_valid(rid) or not rid.is_realized():
			_realized_identities.remove_at(i)
	var player = get_tree().get_first_node_in_group("player") as Node2D
	
	# If we are transitioning between territories, we need to clear out the OLD NPCs faster
	# to make room for the NEW ones within our 150-actor budget.
	# We use a very high budget here because _ghostify itself is now very cheap, 
	# and we don't want the realization queue blocked by a full realized_count.
	var ghostify_budget: int = 20 if _territory_transition_cooldown > 0 else MAX_GHOSTIFY_PER_FRAME
		
	for id in _realized_identities:
		if ghostify_budget <= 0:
			break
		var should_realize := _compute_should_realize(id, player)
		if id.is_realized() and not should_realize:
			_ghostify(id)
			ghostify_budget -= 1


func _apply_realization_desire_impl(id: NPCIdentity, player: Node2D, should_realize: bool) -> void:
	if id.is_realized():
		if not should_realize:
			_ghostify(id)
	else:
		if should_realize and realized_count < max_realized_actors:
			if id.queued_for_realization or id.queued_for_staggered_realization:
				return
			if _queue_admissions_remaining <= 0:
				return
			_queue_admissions_remaining -= 1
			id.queued_for_staggered_realization = true
			id.realization_ready_msec = _next_staggered_realization_ready_msec()
			_staggered_realization_queue.append(id)
			realized_count += 1
		elif should_realize and id.role == NPC.Role.POLICE:
			# Police can displace customers even during normal patrol to prevent starvation
			if _queue_admissions_remaining > 0 and _request_displacement():
				_queue_admissions_remaining -= 1
				id.queued_for_staggered_realization = true
				id.realization_ready_msec = _next_staggered_realization_ready_msec()
				_staggered_realization_queue.append(id)
				realized_count += 1


func _request_displacement() -> bool:
	# Priority 1: Idle Customers that are far away.
	# Priority 2: Any Customer not currently in a solicitation/interaction.
	var candidates: Array[NPCIdentity] = []
	for id in _realized_identities:
		if id.role == NPC.Role.CUSTOMER:
			# Never displace girlfriends
			if id.metadata.get("is_girlfriend", false):
				continue
				
			# If they have an actor, check if they are actually interacting/solicited
			if is_instance_valid(id.current_actor):
				if id.current_actor.blackboard and id.current_actor.blackboard.get_var(&"is_solicited", false):
					continue # Don't displace customers the player is currently dealing with
			candidates.append(id)
	
	if candidates.is_empty():
		return false
		
	# Pick the one farthest from the player
	var player = get_tree().get_first_node_in_group("player") as Node2D
	if not player: return false
	
	var best_id: NPCIdentity = null
	var max_dist_sq: float = -1.0
	
	for id in candidates:
		var d_sq = player.global_position.distance_squared_to(_world_pos_for_identity(id))
		if d_sq > max_dist_sq:
			max_dist_sq = d_sq
			best_id = id
	
	if best_id:
		_ghostify(best_id)
		return true
	
	return false


func _next_staggered_realization_ready_msec() -> int:
	var base_msec: int = Time.get_ticks_msec()
	if _staggered_realization_queue.is_empty():
		return base_msec
	
	# Speed up staggered entries significantly during territory transitions
	var interval = 10 if _territory_transition_cooldown > 0 else stagger_realization_interval_ms
	
	var last_ready: int = _staggered_realization_queue[_staggered_realization_queue.size() - 1].realization_ready_msec
	return maxi(base_msec, last_ready + interval)


func _process_staggered_realization_queue() -> void:
	if _staggered_realization_queue.is_empty():
		return
	var now_msec: int = Time.get_ticks_msec()
	var promoted: int = 0
	while not _staggered_realization_queue.is_empty() and promoted < stagger_promotions_per_frame:
		var id: NPCIdentity = _staggered_realization_queue[0]
		if id.realization_ready_msec > now_msec:
			break
		_staggered_realization_queue.pop_front()
		if id.is_realized():
			continue
		if not id.queued_for_staggered_realization:
			continue
		id.queued_for_staggered_realization = false
		id.realization_ready_msec = 0
		id.queued_for_realization = true
		if id.role == NPC.Role.DEALER or id.role == NPC.Role.POLICE:
			_realization_queue.push_front(id)
		else:
			_realization_queue.append(id)
		promoted += 1

	if debug_realization_logging and promoted > 0:
		_log_realization_activity(0, 0, 0, promoted)

func _process_realization_queue() -> void:
	if _realization_queue.is_empty(): return
	
	var processed = 0
	var max_this_frame: int = TRANSITION_REALIZATIONS_PER_FRAME if _territory_transition_cooldown > 0 else realizations_per_frame
	
	while not _realization_queue.is_empty() and processed < max_this_frame:
		var id = _realization_queue.pop_front()
		id.queued_for_realization = false
		_realize(id)
		processed += 1

	if debug_realization_logging and processed > 0:
		_log_realization_activity(processed, 0)

# ... (similar for _process_activation_finish_queue and _process_post_activation_queue)

func _realize(identity: NPCIdentity) -> void:
	# TerritorySpawner already snaps ghosts to the navmesh at registration; ghost motion is small.
	# Skipping NavigationServer2D here avoids synchronous nav queries during the hot realization path.
	var actor = _pop_actor_from_pool()
	if not actor:
		realized_count -= 1
		return

	_spatial.remove(identity)

	# Lazy reparent: only reparent to world the first time this pool actor is used.
	# Ghostify leaves them in the world, so this only happens once per actor per session.
	var world = get_tree().current_scene
	if world and actor.get_parent() != world:
		actor.reparent(world)

	identity.current_actor = actor
	actor.realize_from_identity(identity)
	
	# Tag actor with territory node for components that rely on metadata
	var t_node = _territory_nodes.get(identity.territory_id)
	if t_node:
		actor.set_meta(&"territory", t_node)
	
	_activation_finish_queue.append({
		"identity": identity,
		"actor": actor,
	})
	if _realized_identities.find(identity) < 0:
		_realized_identities.append(identity)

func _ghostify(identity: NPCIdentity) -> void:
	if not identity.is_realized(): return

	var ri := _realized_identities.find(identity)
	if ri >= 0:
		_realized_identities.remove_at(ri)

	var actor = identity.current_actor
	identity.global_position = actor.global_position
	identity.velocity = actor.velocity

	# Return to the pool — actor stays parented to the world (no reparent needed)
	identity.current_actor = null
	_remove_pending_activation_entries(identity)
	actor.etherealize_to_pool()
	
	_push_actor_to_pool(actor)
	_spatial.insert(identity)
	realized_count -= 1



func _pop_actor_from_pool() -> NPC:
	while not _actor_pool.is_empty():
		var maybe = _actor_pool.pop_back()
		if is_instance_valid(maybe):
			return maybe as NPC
	
	printerr("NPCManager: CRITICAL - Actor pool exhausted (max_realized_actors=%d). Cannot realize more NPCs." % max_realized_actors)
	return null

func _push_actor_to_pool(actor: NPC) -> void:
	_actor_pool.append(actor)


func _process_activation_finish_queue() -> void:
	if _activation_finish_queue.is_empty():
		return

	var processed: int = 0
	var max_this_frame: int = TRANSITION_ACTIVATIONS_PER_FRAME if _territory_transition_cooldown > 0 else activation_finishes_per_frame

	while not _activation_finish_queue.is_empty() and processed < max_this_frame:
		var entry: Dictionary = _activation_finish_queue.pop_front()
		var identity: NPCIdentity = entry.get("identity", null)
		var actor: NPC = entry.get("actor", null)
		if not identity or not is_instance_valid(actor):
			continue
		if identity.current_actor != actor:
			continue
		actor.finish_realization()
		_post_activation_queue.append({
			"identity": identity,
			"actor": actor,
			"ready_at_msec": Time.get_ticks_msec() + post_activation_delay_ms,
		})
		processed += 1

	if debug_realization_logging and processed > 0:
		_log_realization_activity(0, processed)


func _process_post_activation_queue() -> void:
	if _post_activation_queue.is_empty():
		return

	var processed: int = 0
	var now_msec: int = Time.get_ticks_msec()

	while not _post_activation_queue.is_empty() and processed < post_activation_finishes_per_frame:
		var entry: Dictionary = _post_activation_queue[0]
		if int(entry.get("ready_at_msec", 0)) > now_msec:
			break
		_post_activation_queue.pop_front()
		var identity: NPCIdentity = entry.get("identity", null)
		var actor: NPC = entry.get("actor", null)
		if not identity or not is_instance_valid(actor):
			continue
		if identity.current_actor != actor:
			continue
		actor.complete_realization()
		processed += 1

	if debug_realization_logging and processed > 0:
		_log_realization_activity(0, 0, processed)


func _remove_pending_activation_entries(identity: NPCIdentity) -> void:
	for i in range(_activation_finish_queue.size() - 1, -1, -1):
		var queued_identity: NPCIdentity = _activation_finish_queue[i].get("identity", null)
		if queued_identity == identity:
			_activation_finish_queue.remove_at(i)
	for i in range(_post_activation_queue.size() - 1, -1, -1):
		var queued_identity: NPCIdentity = _post_activation_queue[i].get("identity", null)
		if queued_identity == identity:
			_post_activation_queue.remove_at(i)


func _log(message: String) -> void:
	if debug_realization_logging:
		print("NPCManager: ", message)


func _remove_identity_from_territory_index(identity: NPCIdentity) -> void:
	var territory_bucket: Array = _identities_by_territory.get(identity.territory_id, [])
	if territory_bucket.is_empty():
		return
	territory_bucket.erase(identity)
	if territory_bucket.is_empty():
		_identities_by_territory.erase(identity.territory_id)
	else:
		_identities_by_territory[identity.territory_id] = territory_bucket


func _log_realization_activity(realized_this_frame: int, activations_this_frame: int, post_activations_this_frame: int = 0, staggered_promotions_this_frame: int = 0) -> void:
	print(
		"NPCManager: stagger_q=%d realization_q=%d activation_q=%d post_activation_q=%d promoted=%d realized=%d activated=%d finalized=%d current_realized=%d" % [
			_staggered_realization_queue.size(),
			_realization_queue.size(),
			_activation_finish_queue.size(),
			_post_activation_queue.size(),
			staggered_promotions_this_frame,
			realized_this_frame,
			activations_this_frame,
			post_activations_this_frame,
			realized_count,
		]
	)

# --- Territory System ---

var _territory_system_initialized: bool = false
func _initialize_territory_system() -> void:
	# Only mark as initialized if we actually find territories. 
	# Autoloads run before the scene, so the first few calls will likely find nothing.
	var territories = get_tree().get_nodes_in_group("territories")
	if territories.is_empty():
		return
		
	_territory_system_initialized = true
	_territory_nodes.clear()
	for t in territories:
		if t is TerritoryArea:
			_territory_nodes[t.get_territory_id()] = t
			if not t.player_entered.is_connected(_on_player_entered_territory):
				t.player_entered.connect(_on_player_entered_territory)
	
	_rebuild_adjacency_map()
	
	# Initial check: what territory is the player currently in?
	var player = get_tree().get_first_node_in_group("player") as Node2D
	if player:
		var found := false
		for t in territories:
			if t is TerritoryArea and t.overlaps_body(player):
				_on_player_entered_territory(t.get_territory_id())
				found = true
				break
		
		if not found:
			# Fallback: pick the nearest territory center so the realization system
			# starts working immediately instead of leaving _current_territory_id empty
			# (which prevents all territory-based realization until the player walks
			# into a collision shape, causing a lag spike on first entry).
			var best_dist_sq: float = INF
			var best_id: StringName = &""
			for t in territories:
				if t is TerritoryArea:
					var d: float = player.global_position.distance_squared_to(t.global_position)
					if d < best_dist_sq:
						best_dist_sq = d
						best_id = t.get_territory_id()
			if best_id != &"":
				print("NPCManager: Player not inside any territory shape, using nearest: ", best_id)
				_on_player_entered_territory(best_id)
			else:
				print("NPCManager: No territories found at all, retrying in 1s...")
				get_tree().create_timer(1.0).timeout.connect(_initialize_territory_system)

func _rebuild_adjacency_map() -> void:
	var territories = get_tree().get_nodes_in_group("territories")
	_adjacency_map.clear()

	# Increased distance threshold to ensure grid neighbors (including diagonals) are caught.
	# A 4500px threshold is safer for large territory shapes to ensure they detect each other.
	const ADJ_SQ := 5500.0 * 5500.0
	for t1 in territories:
		if not t1 is TerritoryArea: continue
		var id1 = t1.get_territory_id()
		_adjacency_map[id1] = []

		for t2 in territories:
			if not t2 is TerritoryArea or t1 == t2: continue
			var id2 = t2.get_territory_id()

			if t1.global_position.distance_squared_to(t2.global_position) < ADJ_SQ:
				_adjacency_map[id1].append(id2)

	print("NPCManager: Adjacency map rebuilt for ", territories.size(), " territories.")
func _on_player_entered_territory(territory_id: StringName) -> void:
	if _current_territory_id == territory_id: return
	
	_current_territory_id = territory_id
	_adjacent_territory_set.clear()
	for adj_id in _adjacency_map.get(territory_id, []):
		_adjacent_territory_set[adj_id] = true
	
	# Spread the realization surge over several desire passes to prevent a single-frame spike,
	# but do it much faster than the standard background trickle.
	_territory_transition_cooldown = TRANSITION_RAMP_PASSES
	
	# Trigger an immediate pass logic to start the population surge instantly
	_run_realization_desire_pass()
	
	print("NPCManager: Player entered ", territory_id, ". Adjacent: ", _adjacent_territory_set.keys())


func _pick_new_ghost_target(id: NPCIdentity) -> void:
	# Dealers stay at their posts and don't wander as ghosts
	if id.role == NPC.Role.DEALER:
		id.target_position = id.global_position
		return
		
	var t_node: TerritoryArea = _territory_nodes.get(id.territory_id)
	if t_node:
		id.target_position = t_node.get_random_point_inside()
	else:
		# Fallback: small random wander
		id.target_position = id.global_position + Vector2(randf_range(-800, 800), randf_range(-800, 800))

extends Node2D
## Central Hub for Virtual NPC Simulation.
## Manages a large collection of NPCIdentities as "Ghosts" and realized a subset into "Actors".

@export var realization_radius: float = 2400.0
@export var ghosting_radius: float = 3000.0
@export var max_realized_actors: int = 70
@export var dealer_realization_radius: float = 1100.0 # Dealers can wake closer to the player than general NPCs to avoid border spikes around dealer posts.
@export var transition_realization_radius_scale: float = 0.70 # During territory switches, only wake the inner ring first and let the rest fill in over time.
@export var stagger_realization_interval_ms: int = 90 # Gap between newly eligible NPCs entering the live realization queue.
@export var stagger_promotions_per_frame: int = 1 # How many delayed NPCs can be promoted into the live queue per frame.
@export var realizations_per_frame: int = 2 # Stagger to prevent spikes
@export var realization_frame_budget_ms: float = 1.0 # Max time to spend on realizations per frame
@export var activation_finishes_per_frame: int = 2 # Budgeted stage-2 activation work after cheap bind-only realization.
@export var activation_finish_budget_ms: float = 1.0 # Max time to spend on BT/detection/UI activation per frame.
@export var post_activation_delay_ms: int = 50 # Small buffer before full sensing/interact/tier restore to smooth the last micro-stutter.
@export var post_activation_finishes_per_frame: int = 1 # Final restore step should stay tiny and predictable.
@export var post_activation_finish_budget_ms: float = 0.5 # Keep the final activation step very cheap per frame.
@export var realization_pass_interval: float = 0.25 ## Wall-clock interval for who should realize (not every frame).
@export var spatial_pass_cell_margin: int = 1 ## Extra grid rings around the player so adjacent-territory ghosts farther away still get evaluated.
@export var max_queue_admissions_per_pass: int = 6 ## Prevents stuffing the realization queue in one tick when territory rules flip for many ghosts at once.
@export var dealers_realize_globally: bool = false ## When false, dealers use current/adjacent territory + distance (same idea as police). True = legacy: every dealer ghost is always eligible (very expensive in open world).
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

var _spatial: NPCSpatialHash = NPCSpatialHash.new()
var _dealer_identities: Array[NPCIdentity] = []
## Only identities with a live actor — avoids scanning hundreds of ghosts every frame for ghostify.
var _realized_identities: Array[NPCIdentity] = []

var _queue_admissions_remaining: int = 0
var _territory_transition_cooldown: int = 0
const TRANSITION_RAMP_PASSES: int = 8 ## ~2.0s at 0.25s interval — spread territory-entry surge over several desire passes.
const TRANSITION_ADMISSION_CAP: int = 2 ## Max queue admissions per pass during the ramp-up period.
const TRANSITION_REALIZATIONS_PER_FRAME: int = 1 ## Reduced realizations per frame during transition (normally 4).
const TRANSITION_ACTIVATIONS_PER_FRAME: int = 1 ## Clamp expensive BT/detection activation even harder during border crossings.
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
	identities.append(identity)
	if identity.role == NPC.Role.DEALER:
		_dealer_identities.append(identity)
	var territory_bucket: Array = _identities_by_territory.get(identity.territory_id, [])
	territory_bucket.append(identity)
	_identities_by_territory[identity.territory_id] = territory_bucket
	_spatial.insert(identity)
	if identity.appearance_data is NPCAppearanceResource:
		(identity.appearance_data as NPCAppearanceResource).bake_for_identity(identity)
	# Give the ghost an initial target so it starts moving immediately in the background
	_pick_new_ghost_target(identity)

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
	var n: int = 0
	for id in territory_bucket:
		if role != -1 and id.role != role:
			continue
		if role == NPC.Role.DEALER and dealer_kind != &"":
			if id.metadata.get(&"dealer_kind", &"ambient") != dealer_kind:
				continue
		n += 1
	return n


func _process(delta: float) -> void:
	_process_staggered_realization_queue()
	_process_post_activation_queue()
	_process_activation_finish_queue()
	_process_realization_queue()
	
	_ghost_timer += delta
	if _ghost_timer >= GHOST_TICK_RATE:
		_ghost_timer = 0.0
		_update_ghost_subset()
	
	_refresh_realized_ghostify_only(delta)
	
	_sync_timer += delta
	if _sync_timer >= SYNC_INTERVAL:
		_sync_timer = 0.0
		_recalculate_realized_count()
		# Periodic check to see if we've "lost" the player's territory
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
	
	for id in priorities:
		if id.queued_for_realization:
			continue
		if realized_count < max_realized_actors:
			id.queued_for_realization = true
			_realization_queue.push_front(id)
			realized_count += 1


func _recalculate_realized_count() -> void:
	var actual: int = 0
	for id in identities:
		if id.is_realized():
			actual += 1
	realized_count = actual

func _update_ghost_subset() -> void:
	if identities.is_empty(): return
	
	var count = identities.size()
	var processed = 0
	while processed < ghosts_per_tick and processed < count:
		_ghost_index = _ghost_index % count
		var id = identities[_ghost_index]
		
		if not id.is_realized():
			# Ghost simulation: simple linear movement towards target
			if id.target_position != Vector2.ZERO:
				var dist_sq = id.global_position.distance_squared_to(id.target_position)
				if dist_sq < 2500.0: # 50 px
					_pick_new_ghost_target(id)
				else:
					var old_pos: Vector2 = id.global_position
					var dir = (id.target_position - id.global_position).normalized()
					var speed = 200.0
					# Since we tick every 100ms on average (though staggered), 
					# we use the GHOST_TICK_RATE for consistent speed calculation
					id.global_position += dir * speed * GHOST_TICK_RATE
					_spatial.update_after_move(id, old_pos)
		
		_ghost_index += 1
		processed += 1


func _queue_priority_for_pass(role: int) -> int:
	## Lower = admitted first when max_queue_admissions_per_pass is hit (e.g. crossing a territory border).
	if role == NPC.Role.POLICE:
		return 0
	if role == NPC.Role.CUSTOMER:
		return 1
	return 2


func _world_pos_for_identity(id: NPCIdentity) -> Vector2:
	if id.is_realized():
		if is_instance_valid(id.current_actor):
			return id.current_actor.global_position
	return id.global_position


func _is_inside_transition_realization_window(player: Node2D, pos: Vector2) -> bool:
	if _territory_transition_cooldown <= 0 or not player:
		return true
	var transition_radius: float = realization_radius * transition_realization_radius_scale
	return player.global_position.distance_squared_to(pos) <= transition_radius * transition_radius


func _compute_should_realize(id: NPCIdentity, player: Node2D = null) -> bool:
	var territory_id = id.territory_id
	var is_active: bool = (territory_id == _current_territory_id and _current_territory_id != &"")
	var is_adjacent: bool = (_current_territory_id != &"" and _adjacent_territory_set.has(territory_id))
	if player == null:
		player = get_tree().get_first_node_in_group("player") as Node2D
	var pos: Vector2 = _world_pos_for_identity(id)
	var inside_transition_window: bool = _is_inside_transition_realization_window(player, pos)
	
	if id.role == NPC.Role.DEALER:
		if dealers_realize_globally:
			return true
		if not player:
			return is_active
		var dealer_dist_sq: float = player.global_position.distance_squared_to(pos)
		if is_active and dealer_dist_sq < dealer_realization_radius * dealer_realization_radius:
			return true
		return false
	elif id.role == NPC.Role.POLICE:
		if is_active or is_adjacent:
			if not inside_transition_window:
				return false
			return true
	elif is_active:
		if not inside_transition_window:
			return false
		return true
	elif is_adjacent:
		if not inside_transition_window:
			return false
		return (id.get_instance_id() % 4 == 0)

	if _current_territory_id == &"" or territory_id == &"":
		if player:
			var dist_sq: float = player.global_position.distance_squared_to(pos)
			if dist_sq < realization_radius * realization_radius:
				return true
	return false


func _run_realization_desire_pass() -> void:
	if identities.is_empty():
		return
	var player = get_tree().get_first_node_in_group("player") as Node2D
	if not player:
		return

	_queue_admissions_remaining = maxi(0, max_queue_admissions_per_pass)
	# During a territory transition, throttle admissions to prevent a realization surge
	if _territory_transition_cooldown > 0:
		_queue_admissions_remaining = mini(_queue_admissions_remaining, TRANSITION_ADMISSION_CAP)
		_territory_transition_cooldown -= 1

	# Ghostify work is handled elsewhere for already-realized actors, so the desire pass
	# only needs to scan the local realization window instead of the larger ghosting radius.
	var pass_query_radius := maxf(realization_radius, dealer_realization_radius)
	var cell_radius := int(ceili(pass_query_radius / NPCSpatialHash.CELL_SIZE)) + 1 + spatial_pass_cell_margin
	var nearby := _spatial.get_nearby(player.global_position, cell_radius)
	var police_candidates: Array[NPCIdentity] = []
	var customer_candidates: Array[NPCIdentity] = []
	var dealer_candidates: Array[NPCIdentity] = []
	for id in nearby:
		match _queue_priority_for_pass(id.role):
			0:
				police_candidates.append(id)
			1:
				customer_candidates.append(id)
			_:
				dealer_candidates.append(id)

	for bucket in [police_candidates, customer_candidates, dealer_candidates]:
		for id in bucket:
			var should := _compute_should_realize(id, player)
			_apply_realization_desire_impl(id, player, should)
			if _queue_admissions_remaining <= 0 and _territory_transition_cooldown > 0:
				break
		if _queue_admissions_remaining <= 0 and _territory_transition_cooldown > 0:
			break

	if dealers_realize_globally:
		for id in _dealer_identities:
			if id.is_realized():
				continue
			var should_dealer := _compute_should_realize(id, player)
			_apply_realization_desire_impl(id, player, should_dealer)


func _refresh_realized_ghostify_only(_delta: float) -> void:
	if _realized_identities.is_empty():
		return
	for i in range(_realized_identities.size() - 1, -1, -1):
		var rid: NPCIdentity = _realized_identities[i]
		if not is_instance_valid(rid) or not rid.is_realized():
			_realized_identities.remove_at(i)
	var player = get_tree().get_first_node_in_group("player") as Node2D
	var ghostify_budget: int = MAX_GHOSTIFY_PER_FRAME
	for id in _realized_identities:
		if ghostify_budget <= 0:
			break
		var should_realize := _compute_should_realize(id, player)
		if id.is_realized() and not should_realize:
			# Only count actual ghostify candidates against the budget
			if player:
				var pos: Vector2 = _world_pos_for_identity(id)
				var dist_sq = player.global_position.distance_squared_to(pos)
				if dist_sq > ghosting_radius * ghosting_radius:
					_ghostify(id)
					ghostify_budget -= 1
			else:
				_ghostify(id)
				ghostify_budget -= 1


func _apply_realization_desire_impl(id: NPCIdentity, player: Node2D, should_realize: bool) -> void:
	if id.is_realized():
		if not should_realize:
			if player:
				var pos: Vector2 = _world_pos_for_identity(id)
				var dist_sq = player.global_position.distance_squared_to(pos)
				if dist_sq > ghosting_radius * ghosting_radius:
					_ghostify(id)
			else:
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


func _next_staggered_realization_ready_msec() -> int:
	var base_msec: int = Time.get_ticks_msec()
	if _staggered_realization_queue.is_empty():
		return base_msec
	var last_ready: int = _staggered_realization_queue[_staggered_realization_queue.size() - 1].realization_ready_msec
	return maxi(base_msec, last_ready + stagger_realization_interval_ms)


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
	
	var start_usec = Time.get_ticks_usec()
	var budget_usec = realization_frame_budget_ms * 1000.0
	var processed = 0
	# During territory transitions, reduce realizations per frame to spread the cost
	var max_this_frame: int = TRANSITION_REALIZATIONS_PER_FRAME if _territory_transition_cooldown > 0 else realizations_per_frame
	
	while not _realization_queue.is_empty() and processed < max_this_frame:
		# If we've spent more than our budget, stop for this frame to preserve FPS
		if Time.get_ticks_usec() - start_usec > budget_usec:
			break

		var id = _realization_queue.pop_front()
		id.queued_for_realization = false
		_realize(id)
		processed += 1

	if debug_realization_logging and processed > 0:
		_log_realization_activity(processed, 0)

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

func _pick_new_ghost_target(identity: NPCIdentity) -> void:
	if identity.path_markers.is_empty(): return
	identity.target_position = identity.path_markers.pick_random().global_position

func _pop_actor_from_pool() -> NPC:
	while not _actor_pool.is_empty():
		# Receive as Variant to avoid "assigning freed instance to typed var" error
		var maybe = _actor_pool.pop_back()
		if is_instance_valid(maybe):
			return maybe as NPC
	return null

func _push_actor_to_pool(actor: NPC) -> void:
	_actor_pool.append(actor)


func _process_activation_finish_queue() -> void:
	if _activation_finish_queue.is_empty():
		return

	var start_usec: int = Time.get_ticks_usec()
	var budget_usec: float = activation_finish_budget_ms * 1000.0
	var processed: int = 0
	var max_this_frame: int = TRANSITION_ACTIVATIONS_PER_FRAME if _territory_transition_cooldown > 0 else activation_finishes_per_frame

	while not _activation_finish_queue.is_empty() and processed < max_this_frame:
		if Time.get_ticks_usec() - start_usec > budget_usec:
			break
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

	var start_usec: int = Time.get_ticks_usec()
	var budget_usec: float = post_activation_finish_budget_ms * 1000.0
	var processed: int = 0
	var now_msec: int = Time.get_ticks_msec()

	while not _post_activation_queue.is_empty() and processed < post_activation_finishes_per_frame:
		if Time.get_ticks_usec() - start_usec > budget_usec:
			break
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

func _initialize_territory_system() -> void:
	var territories = get_tree().get_nodes_in_group("territories")
	for t in territories:
		if t is TerritoryArea:
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
	
	# Simple distance-based adjacency (neighbor centers within 3000px)
	const ADJ_SQ := 3500.0 * 3500.0
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
	
	# Spread the realization surge over several desire passes to prevent a frame spike
	_territory_transition_cooldown = TRANSITION_RAMP_PASSES
	
	print("NPCManager: Player entered ", territory_id, ". Adjacent: ", _adjacent_territory_set.keys())

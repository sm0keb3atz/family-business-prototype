extends Node2D
## Central Hub for Virtual NPC Simulation.
## Manages a large collection of NPCIdentities as "Ghosts" and realized a subset into "Actors".

@export var realization_radius: float = 2400.0
@export var ghosting_radius: float = 3000.0
@export var max_realized_actors: int = 70
@export var realizations_per_frame: int = 4 # Stagger to prevent spikes
@export var realization_frame_budget_ms: float = 1.5 # Max time to spend on realizations per frame

const GHOST_TICK_RATE: float = 0.1 # Move ghosts every 100ms
@export var ghosts_per_tick: int = 30 # Number of ghosts to move per tick
@export var realization_checks_per_tick: int = 20 # Number of distance checks per tick

var identities: Array[NPCIdentity] = []
var realized_count: int = 0
var _ghost_timer: float = 0.0
var _ghost_index: int = 0
var _realization_index: int = 0
var _sync_timer: float = 0.0
const SYNC_INTERVAL: float = 5.0 # Check realized count every 5 seconds

# Master pool of pre-instantiated nodes
var _actor_pool: Array[NPC] = []

# Queue for staggered realization
var _realization_queue: Array[NPCIdentity] = []

var _current_territory_id: StringName = &""
var _adjacent_territory_ids: Array[StringName] = []
var _adjacency_map: Dictionary = {} # { territory_id: [neighbor_ids] }

func _ready() -> void:
	add_to_group("npc_manager")
	
	# Pre-instantiate the entire master budget at start to eliminate runtime spikes
	call_deferred("_pre_instantiate_pool")
	call_deferred("_initialize_territory_system")

func _pre_instantiate_pool() -> void:
	var npc_scene = load("res://GAME/scenes/characters/npc.tscn")
	for i in range(max_realized_actors):
		var npc = npc_scene.instantiate() as NPC
		npc.set_meta(&"managed_by_pool", true)
		
		# Add to tree but keep hidden/disabled
		add_child(npc)
		npc.prepare_for_pool()
		_actor_pool.append(npc)
	
	print("NPCManager: Master pool of ", max_realized_actors, " actors created.")

func register_identity(identity: NPCIdentity) -> void:
	identities.append(identity)
	# Give the ghost an initial target so it starts moving immediately in the background
	_pick_new_ghost_target(identity)

func unregister_identity(identity: NPCIdentity) -> void:
	if not identity: return
	
	# If currently realized, ghostify him back to the pool
	if identity.is_realized():
		_ghostify(identity)
	
	# If in queue, remove him
	if _realization_queue.has(identity):
		_realization_queue.erase(identity)
		realized_count -= 1
	
	identities.erase(identity)

func unregister_identities_for_territory(territory_id: StringName, role: int = -1) -> void:
	for i in range(identities.size() - 1, -1, -1):
		var id = identities[i]
		if id.territory_id == territory_id:
			if role == -1 or id.role == role:
				unregister_identity(id)

func _process(delta: float) -> void:
	_process_realization_queue()
	
	_ghost_timer += delta
	if _ghost_timer >= GHOST_TICK_RATE:
		_ghost_timer = 0.0
		_update_ghost_subset()
	
	_refresh_realization_subset()
	
	_sync_timer += delta
	if _sync_timer >= SYNC_INTERVAL:
		_sync_timer = 0.0
		_recalculate_realized_count()
		# Periodic check to see if we've "lost" the player's territory
		if _current_territory_id == &"":
			_initialize_territory_system()

func report_crime(pos: Vector2, radius: float = 2000.0) -> void:
	# Force-realize any nearby police ghosts immediately
	var priorities: Array[NPCIdentity] = []
	for id in identities:
		if id.role == NPC.Role.POLICE and not id.is_realized():
			if id.global_position.distance_to(pos) < radius:
				priorities.append(id)
	
	# Push to front of queue
	for id in priorities:
		if not _realization_queue.has(id):
			if realized_count < max_realized_actors:
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
					var dir = (id.target_position - id.global_position).normalized()
					var speed = 200.0
					# Since we tick every 100ms on average (though staggered), 
					# we use the GHOST_TICK_RATE for consistent speed calculation
					id.global_position += dir * speed * GHOST_TICK_RATE
		
		_ghost_index += 1
		processed += 1

func _refresh_realization_subset() -> void:
	if identities.is_empty(): return
	
	var count = identities.size()
	var processed = 0
	while processed < realization_checks_per_tick and processed < count:
		_realization_index = _realization_index % count
		var id = identities[_realization_index]
		
		var territory_id = id.territory_id
		var is_active = (territory_id == _current_territory_id and _current_territory_id != &"")
		var is_adjacent = (territory_id in _adjacent_territory_ids and _current_territory_id != &"")
		
		var should_realize = false
		if id.role == NPC.Role.DEALER:
			# Dealers are ALWAYS realized globally as per user request to ensure they are ready at all times
			should_realize = true
		elif id.role == NPC.Role.POLICE:
			# Police are priority in active and adjacent territories (100% realization)
			if is_active or is_adjacent:
				should_realize = true
		elif is_active:
			should_realize = true
		elif is_adjacent:
			# Stable 25% selection for other NPCs in adjacent territories using instance ID
			should_realize = (id.get_instance_id() % 4 == 0)
		
		# FALLBACK: If we are not in a detected territory, use traditional distance-based realization
		if not should_realize and (_current_territory_id == &"" or territory_id == &""):
			var player = get_tree().get_first_node_in_group("player") as Node2D
			if player:
				var dist_sq = player.global_position.distance_squared_to(id.global_position)
				if dist_sq < realization_radius * realization_radius:
					should_realize = true
		
		# Ensure we don't exceed max realized count if trying to realize
		if id.is_realized():
			# Ghostify if we shouldn't be realized anymore
			# But add a bit of hysteresis to prevents flickering
			if not should_realize:
				var player = get_tree().get_first_node_in_group("player") as Node2D
				if player:
					var dist_sq = player.global_position.distance_squared_to(id.global_position)
					if dist_sq > ghosting_radius * ghosting_radius:
						_ghostify(id)
				else:
					_ghostify(id)
		else:
			if should_realize and realized_count < max_realized_actors:
				if not _realization_queue.has(id):
					# Dealers and Police are priority: insert at front of queue
					if id.role == NPC.Role.DEALER or id.role == NPC.Role.POLICE:
						_realization_queue.push_front(id)
					else:
						_realization_queue.append(id)
					realized_count += 1 
		
		_realization_index += 1
		processed += 1

func _process_realization_queue() -> void:
	if _realization_queue.is_empty(): return
	
	var start_usec = Time.get_ticks_usec()
	var budget_usec = realization_frame_budget_ms * 1000.0
	var processed = 0
	
	while not _realization_queue.is_empty() and processed < realizations_per_frame:
		# If we've spent more than our budget, stop for this frame to preserve FPS
		if Time.get_ticks_usec() - start_usec > budget_usec:
			break
			
		var id = _realization_queue.pop_front()
		_realize(id)
		processed += 1

func _realize(identity: NPCIdentity) -> void:
	# FAIL-SAFE: Final post-realization navmesh check. 
	# If the ghost somehow drifted into a building or was born there, abort realization.
	var map = get_world_2d().get_navigation_map()
	var closest = NavigationServer2D.map_get_closest_point(map, identity.global_position)
	if closest.distance_to(identity.global_position) > 50.0:
		# If it moved too far from navmesh, it's unsafe. 
		# We don't realize it, and it will be re-evaluated in the next subset tick.
		realized_count -= 1
		return

	var actor = _pop_actor_from_pool()
	if not actor:
		realized_count -= 1
		return
	
	# Realize into the world scene for proper Y-sorting with player/environment
	var world = get_tree().current_scene
	if actor.get_parent() != world:
		actor.reparent(world)
	
	identity.current_actor = actor
	actor.realize_from_identity(identity)

func _ghostify(identity: NPCIdentity) -> void:
	if not identity.is_realized(): return
	
	var actor = identity.current_actor
	identity.global_position = actor.global_position
	identity.velocity = actor.velocity
	
	# Return to the pool and reparent to manager (taking it out of the world)
	identity.current_actor = null
	actor.etherealize_to_pool()
	
	if actor.get_parent() != self:
		actor.reparent(self)
		
	_push_actor_to_pool(actor)
	realized_count -= 1

func _pick_new_ghost_target(identity: NPCIdentity) -> void:
	if identity.path_markers.is_empty(): return
	identity.target_position = identity.path_markers.pick_random().global_position

func _pop_actor_from_pool() -> NPC:
	if _actor_pool.is_empty():
		return null
	return _actor_pool.pop_back()

func _push_actor_to_pool(actor: NPC) -> void:
	_actor_pool.append(actor)

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
			# If player is in "no-mans-land" between territories at start, 
			# try again in a few frames to give physics/positioning time to settle.
			get_tree().create_timer(1.0).timeout.connect(_initialize_territory_system)
			print("NPCManager: Player not in any territory yet, retrying in 1s...")

func _rebuild_adjacency_map() -> void:
	var territories = get_tree().get_nodes_in_group("territories")
	_adjacency_map.clear()
	
	# Simple distance-based adjacency (neighbor centers within 3000px)
	for t1 in territories:
		if not t1 is TerritoryArea: continue
		var id1 = t1.get_territory_id()
		_adjacency_map[id1] = []
		
		for t2 in territories:
			if not t2 is TerritoryArea or t1 == t2: continue
			var id2 = t2.get_territory_id()
			
			var dist = t1.global_position.distance_to(t2.global_position)
			if dist < 3500.0: # Adjust as needed for map scale
				_adjacency_map[id1].append(id2)
	
	print("NPCManager: Adjacency map rebuilt for ", territories.size(), " territories.")

func _on_player_entered_territory(territory_id: StringName) -> void:
	if _current_territory_id == territory_id: return
	
	_current_territory_id = territory_id
	_adjacent_territory_ids.clear()
	_adjacent_territory_ids.assign(_adjacency_map.get(territory_id, []))
	
	print("NPCManager: Player entered ", territory_id, ". Adjacent: ", _adjacent_territory_ids)
	
	# We don't force-clear or force-realize here because _refresh_realization_subset 
	# will handle it over many frames via the staggered evaluation loop.

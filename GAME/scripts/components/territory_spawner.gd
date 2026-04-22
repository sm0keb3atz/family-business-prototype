extends Node2D
class_name TerritorySpawner

@export_group("NPC Scenes")
@export var dealer_scene: PackedScene
@export var police_scene: PackedScene
@export var customer_scene: PackedScene
signal initial_spawn_complete

@export_group("AI Resources")
@export var dealer_bt: BehaviorTree
@export var police_bt: BehaviorTree
@export var customer_bt: BehaviorTree
@export var appearance_data: NPCAppearanceResource = preload("res://GAME/resources/npc/appearance_data.tres")

@export_group("Stats")
@export var dealer_stats: CharacterStatsResource = preload("res://GAME/resources/npc/dealer_stats.tres")
@export var police_stats: CharacterStatsResource = preload("res://GAME/resources/npc/police_stats.tres")
@export var customer_stats: CharacterStatsResource = preload("res://GAME/resources/npc/civilian_stats.tres")

@export_group("Startup Tuning")
@export var spawns_per_frame: int = 4
@export var respawn_interval: float = 3.0
@export var population_check_interval: float = 1.0
@export var dealer_spawn_spacing: float = 90.0
@export var dealer_spawn_spacing_search_radius: float = 220.0

# Radius based pooling is disabled in favor of world-wide LOD
var territory_preload_radius: float = 999999.0 
var territory_unload_radius: float = 999999.0

@export_group("Debug")
@export var debug_logging: bool = false

const MAX_HIRED_DEALERS: int = 4
const KIND_WARM_POOL_CREATE: StringName = &"warm_pool_create"
const KIND_ACTIVATE_FROM_POOL: StringName = &"activate_from_pool"
const KIND_EXPAND_POOL: StringName = &"expand_pool"

var _active_customers: Array[NPC] = []
var _active_police: Array[NPC] = []
var _active_dealers: Array[NPC] = []

var _customer_pool: Array[NPC] = []
var _police_pool: Array[NPC] = []
var _dealer_pool: Array[NPC] = []

var _dealer_tier_cycle: int = 1
var _suspend_npc_removed_respawn: bool = false
var _is_preloading: bool = true
var _territory_should_be_active: bool = false
var _population_refresh_accumulator: float = 0.0

var _spawn_queue: Array[Dictionary] = []

@onready var parent_territory: TerritoryArea = get_parent() as TerritoryArea

func _ready() -> void:
	add_to_group("territory_spawner")
	if not parent_territory:
		push_error("TerritorySpawner must be a child of a TerritoryArea")
		initial_spawn_complete.emit()
		return

	if appearance_data:
		_log("Prescanning appearance data")
		appearance_data.prescan_all()

	if not NetworkManager.territory_control_changed.is_connected(_on_territory_control_changed):
		NetworkManager.territory_control_changed.connect(_on_territory_control_changed)
	if not NetworkManager.hired_dealers_changed.is_connected(_on_hired_dealers_changed):
		NetworkManager.hired_dealers_changed.connect(_on_hired_dealers_changed)

	set_process(true)
	if is_inside_tree():
		# Wait 0.5s for NavMesh to settle before scattering ghosts
		get_tree().create_timer(0.5).timeout.connect(_initial_spawn)
	else:
		ready.connect(_on_ready_deferred_spawn, CONNECT_ONE_SHOT)

func _on_ready_deferred_spawn() -> void:
	call_deferred("_initial_spawn")

func _initial_spawn() -> void:
	_is_preloading = true
	_population_refresh_accumulator = 0.0
	_build_warm_pool_queue()
	if _spawn_queue.is_empty():
		_finish_preload()

func _process(delta: float) -> void:
	var rate: int = spawns_per_frame
	var processed: int = 0
	var started_usec: int = Time.get_ticks_usec()

	while _spawn_queue.size() > 0 and processed < rate:
		var item: Dictionary = _spawn_queue.pop_front()
		_process_spawn_item(item)
		processed += 1

	if processed > 0 and debug_logging:
		var elapsed_ms := float(Time.get_ticks_usec() - started_usec) / 1000.0
		_log("Processed %d queued jobs in %.2fms (remaining=%d)" % [processed, elapsed_ms, _spawn_queue.size()])

	if _is_preloading and _spawn_queue.is_empty():
		_finish_preload()

	if not _is_preloading:
		_population_refresh_accumulator += delta
		if _population_refresh_accumulator >= population_check_interval and _spawn_queue.is_empty():
			_population_refresh_accumulator = 0.0
			_refresh_population_requests()

func _finish_preload() -> void:
	if not _is_preloading:
		return
	_is_preloading = false
	_log("Warm preload complete. %s" % _format_pool_counts())
	initial_spawn_complete.emit()
	call_deferred("_refresh_population_requests", true)

func _build_warm_pool_queue() -> void:
	_spawn_queue.clear()
	if not parent_territory or not parent_territory.territory_data:
		initial_spawn_complete.emit()
		return

	var data := parent_territory.territory_data
	_cleanup_active_npcs()

	for _i in range(data.max_customers):
		_enqueue_spawn_item(_make_spawn_item(KIND_WARM_POOL_CREATE, NPC.Role.CUSTOMER, &"warm_preload"))
	for _i in range(data.max_police):
		_enqueue_spawn_item(_make_spawn_item(KIND_WARM_POOL_CREATE, NPC.Role.POLICE, &"warm_preload"))
	var is_controlled := NetworkManager.is_territory_controlled(data.territory_id)
	if not is_controlled:
		for _i in range(data.max_dealers):
			var warm_item := _make_spawn_item(KIND_WARM_POOL_CREATE, NPC.Role.DEALER, &"warm_preload")
			warm_item["dealer_kind"] = &"ambient"
			_enqueue_spawn_item(warm_item)
	
	# We no longer expand the pool here; NPCManager handles a global master budget.

func _refresh_population_requests(force: bool = false) -> void:
	if not parent_territory or not parent_territory.territory_data:
		return

	_cleanup_active_npcs()
	# Radius based pooling is disabled, territory is always "active"
	_territory_should_be_active = true
	
	# Top up budget: how many can we spawn this tick?
	var budget := 4 
	_queue_population_fill(&"refresh", budget)

func _virtual_or_active_count(role: NPC.Role, dealer_kind: StringName = &"") -> int:
	## Virtual NPCs live in NPCManager only; _active_* lists stay empty, so counting actives alone spawns duplicates forever.
	if NPCManager:
		var tid: StringName = parent_territory.get_territory_id()
		if dealer_kind != &"":
			return NPCManager.count_identities_for_territory(tid, int(role), dealer_kind)
		return NPCManager.count_identities_for_territory(tid, int(role))
	match role:
		NPC.Role.CUSTOMER:
			return _active_customers.size()
		NPC.Role.POLICE:
			return _active_police.size()
		NPC.Role.DEALER:
			return _active_dealers.size()
		_:
			return 0


func _queue_population_fill(reason: StringName, budget_left: int) -> void:
	var data := parent_territory.territory_data
	if not data:
		return

	var territory_id: StringName = data.territory_id
	var controlled: bool = NetworkManager.is_territory_controlled(territory_id)

	var customer_pending: int = _count_pending_activation_requests(NPC.Role.CUSTOMER)
	var customer_registered: int = _virtual_or_active_count(NPC.Role.CUSTOMER)
	var customer_needed: int = maxi(0, data.max_customers - customer_registered - customer_pending)
	var customer_to_queue: int = mini(customer_needed, budget_left)
	for _i in range(customer_to_queue):
		_enqueue_spawn_item(_make_spawn_item(KIND_ACTIVATE_FROM_POOL, NPC.Role.CUSTOMER, reason))
	budget_left -= customer_to_queue

	var police_pending: int = _count_pending_activation_requests(NPC.Role.POLICE)
	var police_registered: int = _virtual_or_active_count(NPC.Role.POLICE)
	var police_needed: int = maxi(0, data.max_police - police_registered - police_pending)
	var police_to_queue: int = mini(police_needed, budget_left)
	for _i in range(police_to_queue):
		_enqueue_spawn_item(_make_spawn_item(KIND_ACTIVATE_FROM_POOL, NPC.Role.POLICE, reason))
	budget_left -= police_to_queue

	if controlled:
		_remove_ambient_dealers()
		_queue_hired_dealers(territory_id, reason, budget_left)
	else:
		_remove_hired_dealers()
		var ambient_pending: int = _count_pending_activation_requests(NPC.Role.DEALER, &"ambient")
		var ambient_registered: int = _virtual_or_active_count(NPC.Role.DEALER, &"ambient")
		var ambient_needed: int = maxi(0, data.max_dealers - ambient_registered - ambient_pending)
		var ambient_to_queue: int = mini(ambient_needed, budget_left)
		for _i in range(ambient_to_queue):
			var activate_item := _make_spawn_item(KIND_ACTIVATE_FROM_POOL, NPC.Role.DEALER, reason)
			activate_item["dealer_kind"] = &"ambient"
			_enqueue_spawn_item(activate_item)

func _queue_hired_dealers(territory_id: StringName, reason: StringName, budget_left: int) -> void:
	var slots: Array[HiredDealerSlot] = NetworkManager.get_hired_dealer_slots(territory_id)
	var hired_active: int = 0
	if NPCManager:
		hired_active = NPCManager.count_identities_for_territory(territory_id, NPC.Role.DEALER, &"hired")
	else:
		for npc in _active_dealers:
			if is_instance_valid(npc) and npc.get_meta(&"dealer_spawn_kind", &"") == &"hired":
				hired_active += 1

	var hired_pending: int = _count_pending_activation_requests(NPC.Role.DEALER, &"hired")
	var to_add: int = maxi(0, slots.size() - hired_active - hired_pending)
	to_add = mini(to_add, budget_left)
	for i in range(to_add):
		var slot_index: int = hired_active + i
		if slot_index >= slots.size():
			break
		var activate_item := _make_spawn_item(KIND_ACTIVATE_FROM_POOL, NPC.Role.DEALER, reason)
		activate_item["dealer_kind"] = &"hired"
		activate_item["slot"] = slots[slot_index]
		_enqueue_spawn_item(activate_item)

	while hired_active > slots.size():
		var dealer_to_pool: NPC = _pop_last_dealer_of_kind(&"hired")
		if not is_instance_valid(dealer_to_pool):
			break
		_return_to_pool(dealer_to_pool, _dealer_pool)
		hired_active -= 1

func _make_spawn_item(kind: StringName, role: NPC.Role, reason: StringName) -> Dictionary:
	return {
		"kind": kind,
		"role": int(role),
		"reason": reason,
	}

func _enqueue_spawn_item(item: Dictionary) -> void:
	_spawn_queue.append(item)

func _count_pending_activation_requests(role: NPC.Role, dealer_kind: StringName = &"") -> int:
	var count: int = 0
	for item in _spawn_queue:
		if item.get("kind", &"") != KIND_ACTIVATE_FROM_POOL:
			continue
		if item.get("role", NPC.Role.CUSTOMER) != role:
			continue
		if role == NPC.Role.DEALER and dealer_kind != &"" and item.get("dealer_kind", &"ambient") != dealer_kind:
			continue
		count += 1
	return count

func _process_spawn_item(item: Dictionary) -> void:
	match item.get("kind", &""):
		KIND_WARM_POOL_CREATE:
			_register_virtual_npc(item.get("role", NPC.Role.CUSTOMER), item)
		KIND_EXPAND_POOL:
			_spawn_and_pool_npc(item.get("role", NPC.Role.CUSTOMER))
		KIND_ACTIVATE_FROM_POOL:
			# In virtual mode, activation is handled by NPCManager's realization logic.
			# If we are here, it means the identity doesn't exist yet (respawn)
			_register_virtual_npc(item.get("role", NPC.Role.CUSTOMER), item)

func get_active_dealers() -> Array[NPC]:
	return _active_dealers.duplicate()

func get_active_customers() -> Array[NPC]:
	return _active_customers.duplicate()

func get_active_customer_count() -> int:
	_cleanup_active_npcs()
	return _active_customers.size()

func get_active_hired_dealer_count() -> int:
	_cleanup_active_npcs()
	var count: int = 0
	for npc in _active_dealers:
		if is_instance_valid(npc) and npc.get_meta(&"dealer_spawn_kind", &"") == &"hired":
			count += 1
	return count

func get_active_ambient_dealer_count() -> int:
	_cleanup_active_npcs()
	var count: int = 0
	for npc in _active_dealers:
		if is_instance_valid(npc) and npc.get_meta(&"dealer_spawn_kind", &"") == &"ambient":
			count += 1
	return count

func _territory_id_matches(territory_id: StringName) -> bool:
	return is_instance_valid(parent_territory) and parent_territory.territory_data and parent_territory.territory_data.territory_id == territory_id

func _on_territory_control_changed(territory_id: StringName, _controlled: bool) -> void:
	if not _territory_id_matches(territory_id):
		return
	if NPCManager:
		NPCManager.unregister_identities_for_territory(territory_id, NPC.Role.DEALER)
	_despawn_all_dealers()
	call_deferred("_refresh_population_requests", true)

func _on_hired_dealers_changed(territory_id: StringName) -> void:
	if not _territory_id_matches(territory_id):
		return
	if NPCManager:
		NPCManager.unregister_identities_for_territory(territory_id, NPC.Role.DEALER)
	call_deferred("_refresh_population_requests", true)

func _despawn_all_dealers() -> void:
	_suspend_npc_removed_respawn = true
	for i in range(_active_dealers.size() - 1, -1, -1):
		var npc: NPC = _active_dealers[i]
		if not is_instance_valid(npc):
			_active_dealers.remove_at(i)
			continue
		_return_to_pool(npc, _dealer_pool)
		_active_dealers.remove_at(i)
	call_deferred("_resume_npc_removed_respawn")

func _resume_npc_removed_respawn() -> void:
	_suspend_npc_removed_respawn = false

func _check_and_spawn() -> void:
	_refresh_population_requests(true)

func _remove_ambient_dealers() -> void:
	for i in range(_active_dealers.size() - 1, -1, -1):
		var npc: NPC = _active_dealers[i]
		if not is_instance_valid(npc):
			_active_dealers.remove_at(i)
			continue
		if npc.get_meta(&"dealer_spawn_kind", &"") != &"ambient":
			continue
		_return_to_pool(npc, _dealer_pool)
		_active_dealers.remove_at(i)

func _remove_hired_dealers() -> void:
	for i in range(_active_dealers.size() - 1, -1, -1):
		var npc: NPC = _active_dealers[i]
		if not is_instance_valid(npc):
			_active_dealers.remove_at(i)
			continue
		if npc.get_meta(&"dealer_spawn_kind", &"") != &"hired":
			continue
		_return_to_pool(npc, _dealer_pool)
		_active_dealers.remove_at(i)

func _activate_queue_item(item: Dictionary) -> void:
	if not _territory_should_be_active and not _is_preloading:
		return

	var role: NPC.Role = item.get("role", NPC.Role.CUSTOMER)
	var pool: Array[NPC] = _get_pool_for_role(role)
	var active_list: Array[NPC] = _get_active_list_for_role(role)

	var npc: NPC = _pop_from_pool(pool)
	if not npc:
		_enqueue_spawn_item(_make_spawn_item(KIND_EXPAND_POOL, role, item.get("reason", &"expand")))
		_enqueue_spawn_item(item)
		return

	var spawn_result: Dictionary = _get_spawn_position_for_item(item)
	if not spawn_result.get("found", false):
		pool.append(npc)
		_enqueue_spawn_item(item)
		return
	var spawn_pos: Vector2 = spawn_result.get("position", parent_territory.global_position)

	_configure_npc_for_activation(npc, item)
	npc.activate_from_pool(spawn_pos, {
		"path_markers": _get_path_markers(),
		"debug_logging": debug_logging,
		"lod_tier": 2,
	})
	if not active_list.has(npc):
		active_list.append(npc)

func _configure_npc_for_activation(npc: NPC, item: Dictionary) -> void:
	if not is_instance_valid(npc):
		return
	if npc.role != NPC.Role.DEALER:
		return

	var dealer_kind: StringName = item.get("dealer_kind", &"ambient")
	if dealer_kind == &"hired":
		var slot: HiredDealerSlot = item.get("slot", null)
		npc.set_meta(&"hired_dealer", true)
		npc.set_meta(&"dealer_spawn_kind", &"hired")
		if slot:
			var tier_path: String = "res://GAME/resources/npc/dealers/dealer_lvl" + str(slot.tier_level) + ".tres"
			if FileAccess.file_exists(tier_path):
				npc.dealer_tier = load(tier_path)
	else:
		npc.set_meta(&"hired_dealer", false)
		npc.set_meta(&"dealer_spawn_kind", &"ambient")
		var tier_path := "res://GAME/resources/npc/dealers/dealer_lvl" + str(_dealer_tier_cycle) + ".tres"
		if FileAccess.file_exists(tier_path):
			npc.dealer_tier = load(tier_path)
		_dealer_tier_cycle = (_dealer_tier_cycle % 4) + 1

func _register_virtual_npc(role: NPC.Role, context: Dictionary = {}) -> void:
	var id := NPCIdentity.new()
	id.role = role
	id.gender = NPC.Gender.values().pick_random()
	id.appearance_data = appearance_data
	
	# Dealers should stay at their posts and not wander off as ghosts
	if role == NPC.Role.DEALER:
		id.path_markers = []
	else:
		id.path_markers = _get_path_markers()
		
	id.territory_id = parent_territory.get_territory_id()
	
	match role:
		NPC.Role.CUSTOMER:
			id.behavior_tree = customer_bt
			id.stats = customer_stats
		NPC.Role.POLICE:
			id.behavior_tree = police_bt
			id.stats = police_stats
		NPC.Role.DEALER:
			id.metadata["dealer_kind"] = context.get("dealer_kind", &"ambient")
			id.behavior_tree = dealer_bt
			id.stats = dealer_stats
			# Handle dealer tiering logic here for identity
			var tier_path := "res://GAME/resources/npc/dealers/dealer_lvl" + str(_dealer_tier_cycle) + ".tres"
			if FileAccess.file_exists(tier_path):
				id.dealer_tier = load(tier_path)
			_dealer_tier_cycle = (_dealer_tier_cycle % 4) + 1

	# NavMesh Distribution logic: pick a marker OR a random nav point
	var final_pos: Vector2 = parent_territory.global_position
	var found_safe := false
	var max_retries := 5
	
	for attempt in range(max_retries):
		var spawn_result: Dictionary = _get_spawn_position_for_item({"role": role})
		var candidate_pos: Vector2 = spawn_result.get("position", parent_territory.global_position)
		var original_pos: Vector2 = candidate_pos
		
		# MANDATORY: Always snap to navmesh, even if it's a marker, to prevent spawning in buildings
		candidate_pos = _snap_to_navmesh(candidate_pos)
		
		# FAIL-SAFE: If the snap moved the position significantly (>50px), it means the 
		# original candidate point was likely inside a building or off-map.
		if candidate_pos.distance_to(original_pos) > 50.0:
			if attempt == 0:
				_log("Warning: Initial spawn %s for %s was too far from navmesh (%.1fpx). Retrying with nudges..." % [original_pos, role, candidate_pos.distance_to(original_pos)])
			continue
		
		# On subsequent attempts, apply a horizontal nudge as per user request (50-60px left or right)
		if attempt > 0:
			var side = 1.0 if randf() > 0.5 else -1.0
			candidate_pos.x += side * randf_range(50.0, 60.0)
			# Re-snap after nudge to ensure we didn't push them off the walkway
			candidate_pos = _snap_to_navmesh(candidate_pos)
		
		if _is_position_safe(candidate_pos):
			if role == NPC.Role.DEALER:
				var spaced_result := _find_spaced_dealer_spawn_position(candidate_pos, id.territory_id)
				if not spaced_result.get("found", false):
					_log("Warning: Dealer spawn attempt %d at %s had no spaced fallback, retrying..." % [attempt, candidate_pos])
					continue
				candidate_pos = spaced_result.get("position", candidate_pos)
			final_pos = candidate_pos
			found_safe = true
			break
		else:
			_log("Warning: Spawn attempt %d at %s was unsafe for %s, retrying..." % [attempt, candidate_pos, role])
	
	if not found_safe:
		# SCRAPPED: Random safe point scattering is removed as it often overlaps buildings.
		# If no marker is safe, we don't spawn.
		_log("Warning: No safe spawn marker found for %s after retries. Skipping registration." % role)
		return
	
	id.global_position = final_pos
	
	# Register with global manager
	if NPCManager:
		NPCManager.register_identity(id)

func _snap_to_navmesh(pos: Vector2) -> Vector2:
	var map = get_world_2d().get_navigation_map()
	var closest_pt = NavigationServer2D.map_get_closest_point(map, pos)
	
	# If the closest point is within 400px, trust it as the intended walkway.
	# We return the closest point to ensure they are EXACTLY on the navmesh.
	if closest_pt.distance_to(pos) < 400.0:
		return closest_pt
	
	# If no navmesh point is nearby, return a very far away position or handle as fail
	return pos

func _get_random_nav_point_near(center: Vector2, radius: float) -> Vector2:
	# Try to find the master NavigationRegion2D or just use the global map
	# Correct scattering: Pick a random point in the radius and snap it to the NavMesh
	var angle := randf() * TAU
	var dist := randf() * radius
	var target_pt = center + Vector2(cos(angle), sin(angle)) * dist
	
	var map = get_world_2d().get_navigation_map()
	var closest_pt = NavigationServer2D.map_get_closest_point(map, target_pt)
	
	# If the closest point is still within a reasonable range, use it.
	if closest_pt.distance_to(target_pt) < 500.0:
		return closest_pt
		
	return target_pt

func _is_position_safe(pos: Vector2) -> bool:
	# Check if point overlaps with collision layer 1 (Environment/Buildings)
	# Use a small circle query to represent the NPC's footprint
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsShapeQueryParameters2D.new()
	
	var shape = CircleShape2D.new()
	shape.radius = 20.0 # Standard NPC footprint
	
	query.shape = shape
	query.transform = Transform2D(0, pos)
	query.collision_mask = 1 # Environment/Buildings
	query.collide_with_bodies = true
	query.collide_with_areas = false
	
	var result = space_state.intersect_shape(query, 1)
	return result.is_empty()

func _find_spaced_dealer_spawn_position(base_pos: Vector2, territory_id: StringName) -> Dictionary:
	if _is_dealer_spawn_spacing_clear(base_pos, territory_id):
		return {"found": true, "position": base_pos}

	var ring_radii := [
		dealer_spawn_spacing,
		dealer_spawn_spacing * 1.5,
		minf(dealer_spawn_spacing_search_radius, dealer_spawn_spacing * 2.0),
		dealer_spawn_spacing_search_radius,
	]
	var angle_offset := randf() * TAU

	for radius in ring_radii:
		if radius <= 0.0:
			continue
		var sample_count: int = maxi(8, int(ceili((TAU * radius) / maxf(dealer_spawn_spacing, 1.0))))
		for sample in range(sample_count):
			var angle: float = angle_offset + (TAU * float(sample) / float(sample_count))
			var probe: Vector2 = base_pos + Vector2.RIGHT.rotated(angle) * radius
			var snapped_probe: Vector2 = _snap_to_navmesh(probe)
			if snapped_probe.distance_to(probe) > 50.0:
				continue
			if not _is_position_safe(snapped_probe):
				continue
			if not _is_dealer_spawn_spacing_clear(snapped_probe, territory_id):
				continue
			return {"found": true, "position": snapped_probe}

	return {"found": false, "position": base_pos}

func _is_dealer_spawn_spacing_clear(pos: Vector2, territory_id: StringName) -> bool:
	if dealer_spawn_spacing <= 0.0 or not NPCManager:
		return true

	var min_dist_sq: float = dealer_spawn_spacing * dealer_spawn_spacing
	for identity in NPCManager.identities:
		if not identity:
			continue
		if identity.role != NPC.Role.DEALER:
			continue
		if identity.territory_id != territory_id:
			continue
		if identity.global_position.distance_squared_to(pos) < min_dist_sq:
			return false
	return true

func _spawn_and_pool_npc(role: NPC.Role) -> void:
	var scene: PackedScene
	var bt: BehaviorTree
	var stats: CharacterStatsResource

	match role:
		NPC.Role.CUSTOMER:
			scene = customer_scene
			bt = customer_bt
			stats = customer_stats
		NPC.Role.POLICE:
			scene = police_scene
			bt = police_bt
			stats = police_stats
		NPC.Role.DEALER:
			scene = dealer_scene
			bt = dealer_bt
			stats = dealer_stats

	if not scene: return
	var npc: NPC = scene.instantiate() as NPC
	if not npc: return

	npc.set_meta(&"managed_by_pool", true)
	npc.role = role
	npc.appearance_data = appearance_data
	npc.behavior_tree = bt
	npc.stats = stats.duplicate() if stats else null
	
	# Actors in pool stay hidden and idle until claimed by NPCManager
	add_sibling(npc)
	npc.prepare_for_pool()

func _get_pool_for_role(role: NPC.Role) -> Array[NPC]:
	match role:
		NPC.Role.CUSTOMER:
			return _customer_pool
		NPC.Role.POLICE:
			return _police_pool
		NPC.Role.DEALER:
			return _dealer_pool
	return _customer_pool

func _get_active_list_for_role(role: NPC.Role) -> Array[NPC]:
	match role:
		NPC.Role.CUSTOMER:
			return _active_customers
		NPC.Role.POLICE:
			return _active_police
		NPC.Role.DEALER:
			return _active_dealers
	return _active_customers

func _pop_from_pool(pool: Array[NPC]) -> NPC:
	for i in range(pool.size() - 1, -1, -1):
		var npc: NPC = pool[i]
		pool.remove_at(i)
		if is_instance_valid(npc):
			return npc
	return null

func _return_to_pool(npc: NPC, pool: Array[NPC]) -> void:
	if not is_instance_valid(npc):
		return

	if not pool.has(npc):
		pool.append(npc)

	npc.prepare_for_pool()

func _inject_path_markers_and_connect(npc: NPC) -> void:
	var markers := _get_path_markers()
	npc.ready.connect(_on_spawned_npc_ready.bind(npc, markers), CONNECT_ONE_SHOT)
	npc.tree_exited.connect(_on_npc_removed.bind(npc))

func _on_spawned_npc_ready(npc: NPC, markers: Array) -> void:
	if not is_instance_valid(npc):
		return
	npc.set_path_markers(markers)
	_return_to_pool(npc, _get_pool_for_role(npc.role))

func _cleanup_active_npcs() -> void:
	_cleanup_active_list(_active_customers)
	_cleanup_active_list(_active_police)
	_cleanup_active_list(_active_dealers)

func _cleanup_active_list(npcs: Array[NPC]) -> void:
	for i in range(npcs.size() - 1, -1, -1):
		var npc: NPC = npcs[i]
		if is_instance_valid(npc) and not npc.is_queued_for_deletion():
			continue
		npcs.remove_at(i)

func _on_npc_removed(npc: NPC) -> void:
	if not is_inside_tree() or _suspend_npc_removed_respawn:
		return
	_active_customers.erase(npc)
	_active_police.erase(npc)
	_active_dealers.erase(npc)

func _get_path_markers() -> Array:
	var markers: Array = []
	var path_container := parent_territory.get_node_or_null("PathPoints")
	if path_container:
		for c in path_container.get_children():
			if c is Marker2D:
				markers.append(c)
	return markers

func _get_spawn_position_for_item(item: Dictionary) -> Dictionary:
	var role: NPC.Role = item.get("role", NPC.Role.CUSTOMER)
	var result := {"found": false, "position": parent_territory.global_position, "marker_found": false}
	
	match role:
		NPC.Role.CUSTOMER:
			result = _pick_spawn_position("CustomerPoints")
		NPC.Role.POLICE:
			result = _pick_spawn_position("PolicePoints")
		NPC.Role.DEALER:
			result = _pick_spawn_position("DealerPoints")
	
	# If marker was found, we flag it so we don't NavMesh scatter
	if result.get("found"):
		result["marker_found"] = true
	
	return result

func _pick_spawn_position(container_name: String) -> Dictionary:
	var base_pos: Vector2 = parent_territory.global_position
	var offscreen_positions: Array[Vector2] = []
	var fallback_positions: Array[Vector2] = []

	var container := parent_territory.get_node_or_null(container_name)
	if container:
		var markers: Array[Marker2D] = []
		for child in container.get_children():
			if child is Marker2D:
				markers.append(child)
		if not markers.is_empty():
			for marker in markers:
				var marker_pos: Vector2 = marker.global_position
				fallback_positions.append(marker_pos)
				if not _is_spawn_on_screen(marker_pos):
					offscreen_positions.append(marker_pos)
			if not offscreen_positions.is_empty():
				return {"found": true, "position": offscreen_positions.pick_random()}
			if not fallback_positions.is_empty():
				return {"found": true, "position": fallback_positions.pick_random()}

	if base_pos == parent_territory.global_position:
		var general_markers: Array[Marker2D] = []
		for child in parent_territory.get_children():
			if child is Marker2D:
				general_markers.append(child)
		if not general_markers.is_empty():
			for marker in general_markers:
				var marker_pos: Vector2 = marker.global_position
				fallback_positions.append(marker_pos)
				if not _is_spawn_on_screen(marker_pos):
					offscreen_positions.append(marker_pos)
			if not offscreen_positions.is_empty():
				return {"found": true, "position": offscreen_positions.pick_random()}
			if not fallback_positions.is_empty():
				return {"found": true, "position": fallback_positions.pick_random()}

	return {"found": false, "position": base_pos, "marker_found": false}

func _is_spawn_on_screen(spawn_pos: Vector2) -> bool:
	var camera := get_viewport().get_camera_2d()
	if not camera:
		return false
	var viewport_size: Vector2 = get_viewport_rect().size
	var half_size: Vector2 = (viewport_size * camera.zoom) * 0.5
	var rect := Rect2(camera.get_screen_center_position() - half_size, half_size * 2.0)
	return rect.grow(120.0).has_point(spawn_pos)

func _should_territory_be_loaded() -> bool:
	# Territory is always active in the new world-wide population model
	return true

func _is_territory_on_screen() -> bool:
	var camera := get_viewport().get_camera_2d()
	if not camera:
		return false
	var viewport_size: Vector2 = get_viewport_rect().size
	var half_size: Vector2 = (viewport_size * camera.zoom) * 0.5
	var rect := Rect2(camera.get_screen_center_position() - half_size, half_size * 2.0)
	if rect.grow(250.0).has_point(parent_territory.global_position):
		return true
	var collision := parent_territory.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision and collision.shape is RectangleShape2D:
		var shape := collision.shape as RectangleShape2D
		var extents := shape.size * 0.5
		var top_left := parent_territory.global_position + collision.position - extents
		var territory_rect := Rect2(top_left, shape.size)
		return rect.intersects(territory_rect)
	return false

func _get_activation_budget() -> int:
	return 4

func _return_all_active_to_pool() -> void:
	for npc in _active_customers.duplicate():
		if is_instance_valid(npc):
			_return_to_pool(npc, _customer_pool)
	_active_customers.clear()

	for npc in _active_police.duplicate():
		if is_instance_valid(npc):
			_return_to_pool(npc, _police_pool)
	_active_police.clear()

	for npc in _active_dealers.duplicate():
		if is_instance_valid(npc):
			_return_to_pool(npc, _dealer_pool)
	_active_dealers.clear()

func _pop_last_dealer_of_kind(kind: StringName) -> NPC:
	for i in range(_active_dealers.size() - 1, -1, -1):
		var npc: NPC = _active_dealers[i]
		if not is_instance_valid(npc):
			_active_dealers.remove_at(i)
			continue
		if npc.get_meta(&"dealer_spawn_kind", &"") != kind:
			continue
		_active_dealers.remove_at(i)
		return npc
	return null

func _format_pool_counts() -> String:
	return "pool=(%d customers, %d police, %d dealers) active=(%d, %d, %d)" % [
		_customer_pool.size(),
		_police_pool.size(),
		_dealer_pool.size(),
		_active_customers.size(),
		_active_police.size(),
		_active_dealers.size(),
	]

func _log(message: String) -> void:
	if debug_logging:
		print("[TerritorySpawner:%s] %s" % [parent_territory.name if parent_territory else name, message])

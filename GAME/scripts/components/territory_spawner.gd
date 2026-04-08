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

var _active_customers: Array[NPC] = []
var _active_police: Array[NPC] = []
var _active_dealers: Array[NPC] = []
var _dealer_tier_cycle: int = 1 # To ensure we spawn 1, 2, 3, 4 for testing
var _suspend_npc_removed_respawn: bool = false

@onready var parent_territory: TerritoryArea = get_parent() as TerritoryArea

func _ready() -> void:
	add_to_group("territory_spawner")
	if not parent_territory:
		push_error("TerritorySpawner must be a child of a TerritoryArea")
		# Emit even on failure so MapManager doesn't hang
		initial_spawn_complete.emit()
		return

	if not NetworkManager.territory_control_changed.is_connected(_on_territory_control_changed):
		NetworkManager.territory_control_changed.connect(_on_territory_control_changed)
	if not NetworkManager.hired_dealers_changed.is_connected(_on_hired_dealers_changed):
		NetworkManager.hired_dealers_changed.connect(_on_hired_dealers_changed)

	# Delay initial spawn to allow map to initialize
	if is_inside_tree():
		get_tree().create_timer(1.0).timeout.connect(_initial_spawn)
	else:
		ready.connect(_on_ready_deferred_spawn, CONNECT_ONE_SHOT)

func _on_ready_deferred_spawn() -> void:
	get_tree().create_timer(1.0).timeout.connect(_initial_spawn)

func _initial_spawn() -> void:
	print("TerritorySpawner: Running initial spawn for ", parent_territory.name if parent_territory else "Unknown")
	_check_and_spawn()
	initial_spawn_complete.emit()

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
	_despawn_all_dealers()
	call_deferred("_check_and_spawn")

func _on_hired_dealers_changed(territory_id: StringName) -> void:
	if not _territory_id_matches(territory_id):
		return
	if not NetworkManager.is_territory_controlled(territory_id):
		return
	_despawn_all_dealers()
	call_deferred("_check_and_spawn")

func _despawn_all_dealers() -> void:
	_suspend_npc_removed_respawn = true
	var copy: Array[NPC] = _active_dealers.duplicate()
	for npc in copy:
		if not is_instance_valid(npc):
			continue
		if npc.tree_exited.is_connected(_on_npc_removed):
			npc.tree_exited.disconnect(_on_npc_removed)
		npc.queue_free()
	_active_dealers.clear()
	call_deferred("_resume_npc_removed_respawn")

func _resume_npc_removed_respawn() -> void:
	_suspend_npc_removed_respawn = false

func _check_and_spawn() -> void:
	if not parent_territory:
		print("TerritorySpawner: No parent territory found")
		return
	if not parent_territory.territory_data:
		print("TerritorySpawner: No territory data assigned to ", parent_territory.name)
		return

	var data = parent_territory.territory_data
	var territory_id: StringName = data.territory_id
	var controlled: bool = NetworkManager.is_territory_controlled(territory_id)

	# Clean up invalid references
	_cleanup_active_npcs()

	# Spawn customers
	print("TerritorySpawner: Customers: ", _active_customers.size(), "/", data.max_customers)
	while _active_customers.size() < data.max_customers:
		_spawn_npc(NPC.Role.CUSTOMER)

	# Spawn police
	print("TerritorySpawner: Police: ", _active_police.size(), "/", data.max_police)
	while _active_police.size() < data.max_police:
		_spawn_npc(NPC.Role.POLICE)

	# Spawn dealers — ambient vs hired based on territory control
	print("TerritorySpawner: Dealers: ", _active_dealers.size(), " territory=", String(territory_id), " controlled=", controlled)
	if controlled:
		_remove_ambient_dealers()
		_sync_hired_dealers(territory_id)
	else:
		_remove_hired_dealers()
		while _active_dealers.size() < data.max_dealers:
			_spawn_npc(NPC.Role.DEALER)

func _remove_ambient_dealers() -> void:
	var removed: bool = false
	for i in range(_active_dealers.size() - 1, -1, -1):
		var npc: NPC = _active_dealers[i]
		if not is_instance_valid(npc):
			_active_dealers.remove_at(i)
			continue
		if npc.get_meta(&"dealer_spawn_kind", &"") != &"ambient":
			continue
		removed = true
		if npc.tree_exited.is_connected(_on_npc_removed):
			npc.tree_exited.disconnect(_on_npc_removed)
		npc.queue_free()
		_active_dealers.remove_at(i)
	if removed:
		_suspend_npc_removed_respawn = true
		call_deferred("_resume_npc_removed_respawn")

func _remove_hired_dealers() -> void:
	var removed: bool = false
	for i in range(_active_dealers.size() - 1, -1, -1):
		var npc: NPC = _active_dealers[i]
		if not is_instance_valid(npc):
			_active_dealers.remove_at(i)
			continue
		if npc.get_meta(&"dealer_spawn_kind", &"") != &"hired":
			continue
		removed = true
		if npc.tree_exited.is_connected(_on_npc_removed):
			npc.tree_exited.disconnect(_on_npc_removed)
		npc.queue_free()
		_active_dealers.remove_at(i)
	if removed:
		_suspend_npc_removed_respawn = true
		call_deferred("_resume_npc_removed_respawn")

func _sync_hired_dealers(territory_id: StringName) -> void:
	var slots: Array[HiredDealerSlot] = NetworkManager.get_hired_dealer_slots(territory_id)
	var need: int = slots.size()
	while _active_dealers.size() < need:
		var idx: int = _active_dealers.size()
		_spawn_hired_dealer(slots[idx])
	while _active_dealers.size() > need:
		var npc: NPC = _active_dealers.pop_back()
		if is_instance_valid(npc):
			if npc.tree_exited.is_connected(_on_npc_removed):
				npc.tree_exited.disconnect(_on_npc_removed)
			npc.queue_free()

func _spawn_hired_dealer(slot: HiredDealerSlot) -> void:
	if not dealer_scene or not parent_territory:
		return
	var spawn_pos: Vector2 = _get_random_spawn_position("DealerPoints")
	var npc: NPC = dealer_scene.instantiate() as NPC
	if not npc:
		push_error("TerritorySpawner: dealer_scene did not instantiate an NPC")
		return
	npc.position = parent_territory.to_local(spawn_pos)
	npc.appearance_data = appearance_data
	npc.role = NPC.Role.DEALER
	npc.behavior_tree = dealer_bt
	npc.stats = dealer_stats
	npc.gender = NPC.Gender.values().pick_random()
	npc.set_meta(&"territory", parent_territory)
	npc.set_meta(&"hired_dealer", true)
	npc.set_meta(&"dealer_spawn_kind", &"hired")
	var tier_path: String = "res://GAME/resources/npc/dealers/dealer_lvl" + str(slot.tier_level) + ".tres"
	if FileAccess.file_exists(tier_path):
		npc.dealer_tier = load(tier_path)
	_inject_path_markers_and_connect(npc)
	add_sibling(npc)
	_active_dealers.append(npc)
	_fade_in(npc)

func _spawn_npc(role: NPC.Role) -> void:
	var scene: PackedScene
	var bt: BehaviorTree
	var stats: CharacterStatsResource
	var container_name: String

	match role:
		NPC.Role.CUSTOMER:
			scene = customer_scene
			bt = customer_bt
			stats = customer_stats
			container_name = "CustomerPoints"
		NPC.Role.POLICE:
			scene = police_scene
			bt = police_bt
			stats = police_stats
			container_name = "PolicePoints"
		NPC.Role.DEALER:
			scene = dealer_scene
			bt = dealer_bt
			stats = dealer_stats
			container_name = "DealerPoints"

	if not scene:
		print("TerritorySpawner: No scene for role ", role)
		return

	print("TerritorySpawner: Spawning ", role, " at ", container_name)

	var spawn_pos: Vector2 = _get_random_spawn_position(container_name)
	var npc: NPC = scene.instantiate() as NPC
	if not npc:
		push_error("TerritorySpawner: scene did not instantiate an NPC for role %s" % [str(role)])
		return

	npc.position = parent_territory.to_local(spawn_pos)

	npc.appearance_data = appearance_data
	npc.role = role
	npc.behavior_tree = bt
	npc.stats = stats
	npc.gender = NPC.Gender.values().pick_random()

	npc.set_meta(&"territory", parent_territory)

	if role == NPC.Role.DEALER:
		npc.set_meta(&"hired_dealer", false)
		npc.set_meta(&"dealer_spawn_kind", &"ambient")
		var tier_path = "res://GAME/resources/npc/dealers/dealer_lvl" + str(_dealer_tier_cycle) + ".tres"
		if FileAccess.file_exists(tier_path):
			npc.dealer_tier = load(tier_path)
			print("TerritorySpawner: Assigned tier ", _dealer_tier_cycle, " to ", npc.name)

		_dealer_tier_cycle += 1
		if _dealer_tier_cycle > 4:
			_dealer_tier_cycle = 1

	_inject_path_markers_and_connect(npc)

	add_sibling(npc)
	match role:
		NPC.Role.CUSTOMER:
			_active_customers.append(npc)
		NPC.Role.POLICE:
			_active_police.append(npc)
		NPC.Role.DEALER:
			_active_dealers.append(npc)
	_fade_in(npc)

	print("TerritorySpawner: Successfully spawned ", role, " at global ", spawn_pos, " (local ", npc.position, ")")

func _inject_path_markers_and_connect(npc: NPC) -> void:
	var markers = _get_path_markers()
	npc.ready.connect(_on_spawned_npc_ready.bind(npc, markers), CONNECT_ONE_SHOT)
	npc.tree_exited.connect(_on_npc_removed)

func _on_spawned_npc_ready(npc: NPC, markers: Array) -> void:
	if not is_instance_valid(npc):
		return
	if npc.blackboard:
		npc.blackboard.set_var(&"path_markers", markers)
		print("TerritorySpawner: Injected ", markers.size(), " path markers into ", npc.name)

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

func _on_npc_removed() -> void:
	if _suspend_npc_removed_respawn:
		return
	if not is_inside_tree():
		return
	get_tree().create_timer(3.0).timeout.connect(_check_and_spawn)

func _get_path_markers() -> Array:
	var markers: Array = []
	var path_container = parent_territory.get_node_or_null("PathPoints")
	if path_container:
		for c in path_container.get_children():
			if c is Marker2D:
				markers.append(c)
	return markers

func _get_random_spawn_position(container_name: String) -> Vector2:
	var container = parent_territory.get_node_or_null(container_name)
	if container:
		var markers = []
		for child in container.get_children():
			if child is Marker2D:
				markers.append(child)

		if markers.size() > 0:
			var picked = markers.pick_random()
			return picked.global_position

	var general_markers = []
	for child in parent_territory.get_children():
		if child is Marker2D:
			general_markers.append(child)

	if general_markers.size() > 0:
		return general_markers.pick_random().global_position

	return parent_territory.global_position

func _fade_in(npc: NPC) -> void:
	if not is_instance_valid(npc) or not npc.is_inside_tree():
		return
	npc.modulate.a = 0.0
	var tween: Tween = npc.create_tween()
	tween.tween_property(npc, "modulate:a", 1.0, 0.6).set_ease(Tween.EASE_OUT)

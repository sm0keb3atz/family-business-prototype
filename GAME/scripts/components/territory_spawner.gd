extends Node2D
class_name TerritorySpawner

@export_group("NPC Scenes")
@export var dealer_scene: PackedScene
@export var police_scene: PackedScene
@export var customer_scene: PackedScene

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

@onready var parent_territory: TerritoryArea = get_parent() as TerritoryArea

func _ready() -> void:
	if not parent_territory:
		push_error("TerritorySpawner must be a child of a TerritoryArea")
		return
		
	# Delay initial spawn to allow map to initialize
	if is_inside_tree():
		get_tree().create_timer(1.0).timeout.connect(_initial_spawn)
	else:
		ready.connect(func(): get_tree().create_timer(1.0).timeout.connect(_initial_spawn), CONNECT_ONE_SHOT)

func _initial_spawn() -> void:
	print("TerritorySpawner: Running initial spawn for ", parent_territory.name if parent_territory else "Unknown")
	_check_and_spawn()

func _process(_delta: float) -> void:
	# Periodically check population, though signals are preferred
	pass

func _check_and_spawn() -> void:
	if not parent_territory:
		print("TerritorySpawner: No parent territory found")
		return
	if not parent_territory.territory_data:
		print("TerritorySpawner: No territory data assigned to ", parent_territory.name)
		return
	
	var data = parent_territory.territory_data
	
	# Clean up invalid references
	_active_customers = _active_customers.filter(func(npc): return is_instance_valid(npc) and not npc.is_queued_for_deletion())
	_active_police = _active_police.filter(func(npc): return is_instance_valid(npc) and not npc.is_queued_for_deletion())
	_active_dealers = _active_dealers.filter(func(npc): return is_instance_valid(npc) and not npc.is_queued_for_deletion())
	
	# Spawn customers
	print("TerritorySpawner: Customers: ", _active_customers.size(), "/", data.max_customers)
	while _active_customers.size() < data.max_customers:
		_spawn_npc(NPC.Role.CUSTOMER)
		
	# Spawn police
	print("TerritorySpawner: Police: ", _active_police.size(), "/", data.max_police)
	while _active_police.size() < data.max_police:
		_spawn_npc(NPC.Role.POLICE)
		
	# Spawn dealers
	print("TerritorySpawner: Dealers: ", _active_dealers.size(), "/", data.max_dealers)
	while _active_dealers.size() < data.max_dealers:
		_spawn_npc(NPC.Role.DEALER)

func _spawn_npc(role: NPC.Role) -> void:
	var scene: PackedScene
	var bt: BehaviorTree
	var stats: CharacterStatsResource
	var target_list: Array
	var container_name: String
	
	match role:
		NPC.Role.CUSTOMER:
			scene = customer_scene
			bt = customer_bt
			stats = customer_stats
			target_list = _active_customers
			container_name = "CustomerPoints"
		NPC.Role.POLICE:
			scene = police_scene
			bt = police_bt
			stats = police_stats
			target_list = _active_police
			container_name = "PolicePoints"
		NPC.Role.DEALER:
			scene = dealer_scene
			bt = dealer_bt
			stats = dealer_stats
			target_list = _active_dealers
			container_name = "DealerPoints"
	
	if not scene: 
		print("TerritorySpawner: No scene for role ", role)
		return
	
	print("TerritorySpawner: Spawning ", role, " at ", container_name)
	
	var spawn_pos = _get_random_spawn_position(container_name)
	var npc: NPC = scene.instantiate()
	
	# Set position relative to parent BEFORE adding to tree
	# Since npc is a sibling of this spawner, its parent will be parent_territory
	npc.position = parent_territory.to_local(spawn_pos)
	
	# Set properties BEFORE adding to tree so _ready() has them
	npc.appearance_data = appearance_data
	npc.role = role
	npc.behavior_tree = bt
	npc.stats = stats
	npc.gender = NPC.Gender.values().pick_random()
	
	# Inject territory reference
	npc.set_meta(&"territory", parent_territory)
	
	# Inject Path Markers for Navigation
	var markers = _get_path_markers()
	npc.ready.connect(func():
		if npc.blackboard:
			npc.blackboard.set_var(&"path_markers", markers)
			print("TerritorySpawner: Injected ", markers.size(), " path markers into ", npc.name)
	, CONNECT_ONE_SHOT)
	
	# Connect to tree_exited to trigger respawn
	npc.tree_exited.connect(_on_npc_removed)
	
	add_sibling(npc)
	target_list.append(npc)
	_fade_in(npc)
	
	print("TerritorySpawner: Successfully spawned ", role, " at global ", spawn_pos, " (local ", npc.position, ")")

func _on_npc_removed() -> void:
	# Wait a short bit before respawning so it's not instant/robotic
	if not is_inside_tree(): return
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
	# Look for the specific container inside the territory
	var container = parent_territory.get_node_or_null(container_name)
	if container:
		var markers = []
		for child in container.get_children():
			if child is Marker2D:
				markers.append(child)
		
		if markers.size() > 0:
			var picked = markers.pick_random()
			return picked.global_position
	
	# Fallback: Look for any Marker2D directly in territory
	var general_markers = []
	for child in parent_territory.get_children():
		if child is Marker2D:
			general_markers.append(child)
	
	if general_markers.size() > 0:
		return general_markers.pick_random().global_position
	
	# Fallback to territory center
	return parent_territory.global_position

func _fade_in(npc: NPC) -> void:
	if not is_instance_valid(npc) or not npc.is_inside_tree(): return
	npc.modulate.a = 0.0
	var tween: Tween = npc.create_tween()
	tween.tween_property(npc, "modulate:a", 1.0, 0.6).set_ease(Tween.EASE_OUT)

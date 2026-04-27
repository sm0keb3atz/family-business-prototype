extends Node2D
class_name NPCSpawner

@export_group("NPC Scenes")
@export var dealer_scene: PackedScene
@export var police_scene: PackedScene
@export var customer_scene: PackedScene

@export_group("AI Trees")
@export var dealer_bt: BehaviorTree
@export var police_bt: BehaviorTree = preload("res://GAME/resources/npc/police_bt.tres")
@export var customer_bt: BehaviorTree

@export_group("AI Stats")
@export var dealer_stats: CharacterStatsResource = preload("res://GAME/resources/npc/dealer_stats.tres")
@export var police_stats: CharacterStatsResource = preload("res://GAME/resources/npc/police_stats.tres")
@export var customer_stats: CharacterStatsResource = preload("res://GAME/resources/npc/civilian_stats.tres")

@export_group("Spawn Points")
@export var dealer_points_container: Node2D
@export var police_points_container: Node2D
@export var customer_points_container: Node2D
@export var path_points_container: Node2D

@export_group("Settings")
@export var max_customers: int = 10
@export var appearance_data: NPCAppearanceResource
## Seconds between each NPC spawn for staggered appearance.
@export var spawn_interval: float = 0.4

var _spawn_queue: Array = []

func _ready() -> void:
	# Pre-scan directory contents into memory during the delay
	# (textures themselves are loaded on-demand so we don't crash the GPU)
	if appearance_data:
		appearance_data.prescan_all()
	get_tree().create_timer(0.5).timeout.connect(_initial_spawn)

func _initial_spawn() -> void:
	# Dealers spawn immediately (there are few)
	_spawn_dealers()
	# Queue police and customers for staggered spawning
	_queue_police()
	_queue_customers()
	_process_spawn_queue()

func _spawn_dealers() -> void:
	# Dealers are now managed globally by NPCManager. 
	# Spawner no longer needs to instantiate them manually.
	pass

func _queue_police() -> void:
	if not police_scene or not police_points_container:
		return
	
	for point in police_points_container.get_children():
		if point is Marker2D:
			_spawn_queue.append({"type": "police", "position": point.global_position})

func _queue_customers() -> void:
	if not customer_scene or not customer_points_container:
		return
	
	for i in range(max_customers):
		var point = _get_random_customer_spawn()
		if point:
			_spawn_queue.append({"type": "customer", "position": point.global_position})
	
	# Shuffle so police and customers are intermixed
	_spawn_queue.shuffle()

func _process_spawn_queue() -> void:
	if _spawn_queue.size() == 0:
		return
	
	var data: Dictionary = _spawn_queue.pop_front()
	match data["type"]:
		"police":
			_do_spawn_police(data["position"])
		"customer":
			_do_spawn_customer(data["position"])
	
	if _spawn_queue.size() > 0:
		get_tree().create_timer(spawn_interval).timeout.connect(_process_spawn_queue)

func _do_spawn_police(pos: Vector2) -> void:
	var police: NPC = police_scene.instantiate()
	police.global_position = pos
	police.appearance_data = appearance_data
	police.behavior_tree = police_bt
	police.stats = police_stats
	police.role = NPC.Role.POLICE
	police.gender = NPC.Gender.values().pick_random()
	
	var markers: Array = _get_path_markers()
	police.ready.connect(func():
		if police.blackboard:
			police.blackboard.set_var(&"path_markers", markers)
	, CONNECT_ONE_SHOT)
	
	add_sibling(police)
	_fade_in(police)

func _do_spawn_customer(pos: Vector2) -> void:
	var customer: NPC = customer_scene.instantiate()
	customer.global_position = pos
	customer.appearance_data = appearance_data
	customer.behavior_tree = customer_bt
	customer.stats = customer_stats
	customer.role = NPC.Role.CUSTOMER
	customer.gender = NPC.Gender.values().pick_random()
	
	var markers: Array = _get_path_markers()
	customer.ready.connect(func():
		if customer.blackboard:
			customer.blackboard.set_var(&"path_markers", markers)
	, CONNECT_ONE_SHOT)
	
	add_sibling(customer)
	_fade_in(customer)

func _fade_in(npc: NPC) -> void:
	npc.modulate.a = 0.0
	var tween: Tween = npc.create_tween()
	tween.tween_property(npc, "modulate:a", 1.0, 0.6).set_ease(Tween.EASE_OUT)

func _get_path_markers() -> Array:
	var markers: Array = []
	if path_points_container:
		for c in path_points_container.get_children():
			if c is Marker2D:
				markers.append(c)
	return markers

func _get_random_customer_spawn() -> Marker2D:
	if customer_points_container and customer_points_container.get_child_count() > 0:
		var points = customer_points_container.get_children().filter(func(c): return c is Marker2D)
		if points.size() > 0:
			return points.pick_random()
	return null

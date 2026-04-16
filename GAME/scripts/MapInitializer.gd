extends Node

## MapInitializer - Runtime setup for camera and transparency mask.
## This script handles the plug-and-play integration of the cutout system.
## Drop this node into any scene containing a Map and Player, or add it via script.
signal initialization_complete

@export_group("Manual Node Overrides")
## Optional: Manually assign the Player. If empty, it will auto-discover via "player" group or name.
@export var player_override: Node2D
## Optional: Manually assign the BuildingsTop layer. If empty, it will search for "BuildingsTop".
@export var buildings_top_override: CanvasItem
@export_group("Settings")
## How fast the transparency fades in/out
@export var fade_speed: float = 8.0

const GAME_CAMERA_SCENE = preload("res://GAME/scenes/GameCamera.tscn")
const ROOF_SHADER = preload("res://GAME/assets/shaders/roof_cutout.gdshader")

var player: Node2D
var game_camera: Node2D
var target_layers: Array[CanvasItem] = []
var cutout_material: ShaderMaterial
var current_occlusion: float = 0.0

func _ready() -> void:
	add_to_group("map_initializer")
	_initialize_system.call_deferred()

func _initialize_system() -> void:
	# 1. Find Player
	player = player_override
	if !is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
	if !is_instance_valid(player):
		player = get_tree().get_root().find_child("Player", true, false)
	
	if !is_instance_valid(player):
		push_warning("MapInitializer: Player not found!")
		return

	# Enable Y-sorting on player just in case
	player.y_sort_enabled = true

	# 2. Find BuildingsTop Node
	var buildings_top = buildings_top_override
	if !is_instance_valid(buildings_top):
		buildings_top = get_tree().get_root().find_child("BuildingsTop", true, false)
	
	if is_instance_valid(buildings_top) and buildings_top is CanvasItem:
		target_layers.append(buildings_top)
		
		# Runtime Y-Sorting setup
		_setup_y_sorting(buildings_top)
		
		for child in buildings_top.get_children():
			if child is CanvasItem:
				target_layers.append(child)
	
	# Also find Buildings parent for Y-sorting
	var buildings_parent = get_tree().get_root().find_child("Buildings", true, false)
	if is_instance_valid(buildings_parent):
		_setup_y_sorting(buildings_parent)

	# 3. Setup Shader Material
	if !target_layers.is_empty():
		cutout_material = ShaderMaterial.new()
		cutout_material.shader = ROOF_SHADER
		for layer in target_layers:
			layer.material = cutout_material
			layer.z_index = 10 # Ensure roofs are above player by default
	else:
		print("MapInitializer: No layers found to apply shader to.")

	# 4. Instance Camera
	game_camera = GAME_CAMERA_SCENE.instantiate()
	game_camera.target = player
	
	# Add to same level as MapInitializer
	var parent = get_parent()
	if is_instance_valid(parent):
		parent.add_child(game_camera)
	else:
		# Fallback to root if for some reason we are orphan
		get_tree().root.add_child(game_camera)
	
	# 5. Generate Footprints from collision
	_generate_footprints()
	
	# 6. Wire up doors
	_initialize_doors()
	
	# 7. Disable existing cameras to prevent conflict
	_disable_other_cameras()
	
	# Ensure our new camera is current
	if game_camera.has_node("Camera2D"):
		var cam_node = game_camera.get_node("Camera2D")
		cam_node.make_current()
		print("MapInitializer: Set GameCamera as current. Position: ", game_camera.global_position, " Zoom: ", cam_node.zoom)

	print("MapInitializer: System fully initialized. Waiting for NPC pre-spawn...")
	_wait_for_spawners()

func _wait_for_spawners() -> void:
	# Collect all territory spawners in the scene
	var spawners: Array[Node] = get_tree().get_nodes_in_group("territory_spawner")
	if spawners.is_empty():
		# No spawners — emit immediately
		print("MapInitializer: No spawners found, initializing immediately.")
		initialization_complete.emit()
		return

	# Track how many spawners still need to complete
	var pending: Array[int] = [spawners.size()]  # Wrapped in array so closure can mutate it

	var _on_spawner_done := func() -> void:
		pending[0] -= 1
		if pending[0] <= 0:
			print("MapInitializer: All ", spawners.size(), " spawners complete. Starting game.")
			initialization_complete.emit()

	for spawner in spawners:
		if spawner.has_signal("initial_spawn_complete"):
			spawner.initial_spawn_complete.connect(_on_spawner_done, CONNECT_ONE_SHOT)
		else:
			# Spawner doesn't have the signal — don't block on it
			pending[0] -= 1

	# Edge case: all spawners had no signal, emit immediately
	if pending[0] <= 0:
		initialization_complete.emit()

func _generate_footprints() -> void:
	# Look for BuildingColision (user spelled with one L)
	var collision_root = get_tree().get_root().find_child("BuildingColision", true, false)
	if !collision_root:
		return
		
	var footprint_parent = Node2D.new()
	footprint_parent.name = "GeneratedFootprints"
	# Place it in the tree
	var map_node = collision_root.get_parent()
	map_node.add_child(footprint_parent)
	
	# Move it to be BEFORE the Buildings node so it renders underneath them
	var buildings_node = map_node.find_child("Buildings", false, false)
	if buildings_node:
		map_node.move_child(footprint_parent, buildings_node.get_index())
	
	footprint_parent.z_index = 0 # Ground level
	footprint_parent.modulate = Color(1, 1, 1, 0.7)
	
	for child in collision_root.get_children():
		if child is CollisionPolygon2D:
			var poly = Polygon2D.new()
			poly.polygon = child.polygon
			poly.global_position = child.global_position
			poly.color = Color.BLACK
			footprint_parent.add_child(poly)
			
	print("MapInitializer: Generated ", footprint_parent.get_child_count(), " footprint polygons.")

func _setup_y_sorting(node: Node) -> void:
	if node is Node2D:
		node.y_sort_enabled = true
	# Also check parent to ensure sorting context
	var parent = node.get_parent()
	if parent is Node2D:
		parent.y_sort_enabled = true

func _disable_other_cameras() -> void:
	# Find all cameras in the scene
	var cameras = get_tree().get_nodes_in_group("camera")
	
	# Also find player's camera explicitly
	var player_cam = player.find_child("Camera2D", true, false)
	if player_cam and !cameras.has(player_cam):
		cameras.append(player_cam)
		
	for cam in cameras:
		if cam is Camera2D and cam.get_parent() != game_camera:
			cam.enabled = false
			# We don't hide it because it might be the only thing showing the player if our camera fails
			# but we definitely disable it.

func _process(delta: float) -> void:
	if !is_instance_valid(player) or !cutout_material:
		return

	# 1. Tile-based occlusion check
	var is_occluded = false
	for layer in target_layers:
		if layer.has_method("local_to_map"): # Works for TileMap and TileMapLayer
			var local_pos = layer.to_local(player.global_position)
			var map_pos = layer.local_to_map(local_pos)
			if layer.get_cell_source_id(map_pos) != -1:
				is_occluded = true
				break
	
	# 2. Smoothly lerp strength
	var target_occ = 1.0 if is_occluded else 0.0
	current_occlusion = lerp(current_occlusion, target_occ, fade_speed * delta)

	# 3. Update uniforms
	if is_instance_valid(game_camera):
		var player_screen_pos = game_camera.get_target_screen_pos()
		var cursor_screen_pos = player_screen_pos # Default to overlap
		
		if Input.is_action_pressed("aim"):
			cursor_screen_pos = get_viewport().get_mouse_position()
			
		cutout_material.set_shader_parameter("player_pos", player_screen_pos)
		cutout_material.set_shader_parameter("cursor_pos", cursor_screen_pos)
		cutout_material.set_shader_parameter("radius", game_camera.cutout_radius)
		cutout_material.set_shader_parameter("softness", game_camera.edge_softness)
		
		# Drive strengths independently
		var aim_blocked = false
		var weapon_holder = player.get_node_or_null("%WeaponHolderComponent")
		if weapon_holder and weapon_holder.current_weapon and weapon_holder.current_weapon.has_method("is_aiming_blocked"):
			aim_blocked = weapon_holder.current_weapon.is_aiming_blocked()
		
		cutout_material.set_shader_parameter("player_occlusion", current_occlusion)
		cutout_material.set_shader_parameter("cursor_occlusion", 1.0 if (Input.is_action_pressed("aim") and not aim_blocked) else 0.0)

func _initialize_doors() -> void:
	var triggers = get_tree().get_nodes_in_group("door_trigger")
	if triggers.size() == 0:
		return

	var map = get_tree().get_root().find_child("Map", true, false)
	if !map:
		map = get_tree().get_root()
		
	var doors = map.find_children("BuildingDoor*", "AnimatedSprite2D", true)
	if doors.size() == 0:
		print("MapInitializer: No BuildingDoor nodes found.")
		return
	
	# 1. Wire Triggers - Match logic only now that doors are already in world
	for trigger in triggers:
		if trigger is DoorTrigger and trigger.door_node == null:
			var closest_door = null
			var min_dist = 500.0 # Search radius
			var t_pos = trigger.global_position
			
			for door in doors:
				var d_pos = door.global_position
				var dist = t_pos.distance_to(d_pos)
				if dist < min_dist:
					min_dist = dist
					closest_door = door
			
			if closest_door:
				trigger.door_node = closest_door
				print("MapInitializer: Wired Trigger '", trigger.name, "' to Door '", closest_door.name, "' (Dist: ", min_dist, ")")
			else:
				print("MapInitializer FAIL: No door near trigger '", trigger.name, "' (Dist > 500px)")

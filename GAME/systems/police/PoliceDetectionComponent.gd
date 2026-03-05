class_name PoliceDetectionComponent
extends Area2D

var is_player_inside: bool = false
var player_ref: Player = null

@export var detection_radius: float = 350.0
@export var wanted_radius_multiplier: float = 1.6 # ~560 radius when wanted

var _base_radius: float = 350.0
var _visual: Node2D = null
var _collision_shape: CollisionShape2D = null

func _ready() -> void:
	_base_radius = detection_radius
	
	# Add visual
	_visual = preload("res://GAME/scripts/ui/circle_visual.gd").new()
	_visual.radius = detection_radius
	_visual.fill_color = Color(1, 0, 0, 0.15)
	add_child(_visual)
	
	# Setup Area2D
	_collision_shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = detection_radius
	_collision_shape.shape = circle
	add_child(_collision_shape)
	
	collision_layer = 0 # Don't be hit by bullets
	collision_mask = 2 # Detect Player
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	if has_node("/root/HeatManager"):
		get_node("/root/HeatManager").stars_changed.connect(_on_stars_changed)
		_update_radius_for_stars(get_node("/root/HeatManager").wanted_stars)

func _on_stars_changed(stars: int) -> void:
	_update_radius_for_stars(stars)

func _update_radius_for_stars(stars: int) -> void:
	var target_radius = _base_radius
	if stars > 0:
		target_radius = _base_radius * wanted_radius_multiplier
	
	detection_radius = target_radius
	
	if _visual:
		_visual.radius = detection_radius
		if _visual.has_method("queue_redraw"):
			_visual.queue_redraw()
			
	if _collision_shape and _collision_shape.shape is CircleShape2D:
		_collision_shape.shape.radius = detection_radius

func _physics_process(delta: float) -> void:
	if is_player_inside and is_instance_valid(player_ref):
		# Check if player is armed
		var is_armed: bool = false
		if player_ref.weapon_holder_component and player_ref.weapon_holder_component.current_weapon:
			is_armed = true
			
		if is_armed:
			if has_node("/root/HeatManager"):
				get_node("/root/HeatManager").add_heat(HeatConfig.ARMED_HEAT_RATE * delta)
		
		# When wanted, directly update THIS officer's blackboard so the BT reacts
		# to the player being right here inside the detection area
		var npc: NPC = get_parent() as NPC
		if npc and npc.blackboard:
			var hm: Node = get_node_or_null("/root/HeatManager")
			if hm and hm.wanted_stars >= 1:
				var vel: Vector2 = player_ref.velocity if player_ref is CharacterBody2D else Vector2.ZERO
				npc.blackboard.set_var(&"last_known_position", player_ref.global_position)
				npc.blackboard.set_var(&"last_known_velocity", vel)
				npc.blackboard.set_var(&"last_seen_time", Time.get_ticks_msec() / 1000.0)
				npc.blackboard.set_var(&"has_line_of_sight", true)
				npc.blackboard.set_var(&"is_searching", false)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		is_player_inside = true
		player_ref = body
		if has_node("/root/DetectionManager"):
			get_node("/root/DetectionManager").register_detection()

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		is_player_inside = false
		player_ref = null
		if has_node("/root/DetectionManager"):
			get_node("/root/DetectionManager").unregister_detection()

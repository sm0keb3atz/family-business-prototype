class_name PoliceDetectionComponent
extends Area2D

var is_player_inside: bool = false
var player_ref: Player = null

@export_category("Colors")
@export var patrol_color: Color = Color(0.0, 1.0, 0.0)    # Green
@export var warning_color_1: Color = Color(1.0, 1.0, 0.0) # Yellow
@export var warning_color_2: Color = Color(1.0, 0.5, 0.0) # Orange
@export var danger_color: Color = Color(1.0, 0.0, 0.0)    # Red
@export var police_blue: Color = Color(0.0, 0.2, 1.0)     # Blue for flashing

@export_category("Radius")
@export var detection_radius: float = 350.0
@export var patrol_radius_multiplier: float = 0.5  # ~175 radius when patrolling (0 stars)
@export var wanted_radius_multiplier: float = 1.6  # ~560 radius at 2+ stars

var _base_radius: float = 350.0
var _visual: Node2D = null
var _collision_shape: CollisionShape2D = null
## Lightweight timer to throttle position refresh when player is inside.
var _update_timer: float = 0.0
const UPDATE_INTERVAL: float = 0.25

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
		var hm = get_node("/root/HeatManager")
		hm.stars_changed.connect(_on_stars_changed)
		hm.heat_changed.connect(_on_heat_changed)
		_update_radius_for_stars(hm.wanted_stars)
		_update_color()

func _on_stars_changed(stars: int) -> void:
	_update_radius_for_stars(stars)
	_update_color()

func _on_heat_changed(_heat: float) -> void:
	_update_color()

func _update_color() -> void:
	if not _visual or not has_node("/root/HeatManager"):
		return
	
	var hm = get_node("/root/HeatManager")
	var heat = hm.heat_value
	var stars = hm.wanted_stars
	
	var target_color: Color
	
	if stars >= 1:
		# Flash red and blue based on system time when wanted
		# 5.0 speed means roughly 2.5 cycles per second
		var t = sin(Time.get_ticks_msec() / 1000.0 * 5.0)
		if t > 0.0:
			target_color = danger_color
		else:
			target_color = police_blue
	else:
		# Gradient based on heat (0.0 to 100.0 expected from HeatConfig.MAX_HEAT)
		# 0 = Green, 33 = Yellow, 66 = Orange, 100 = Red
		var t_heat = clamp(heat / 100.0, 0.0, 1.0)
		
		if t_heat < 0.33:
			# Green to Yellow
			target_color = patrol_color.lerp(warning_color_1, t_heat / 0.33)
		elif t_heat < 0.66:
			# Yellow to Orange
			target_color = warning_color_1.lerp(warning_color_2, (t_heat - 0.33) / 0.33)
		else:
			# Orange to Red
			target_color = warning_color_2.lerp(danger_color, (t_heat - 0.66) / 0.34)
	
	_visual.fill_color = target_color

func _update_radius_for_stars(stars: int) -> void:
	var target_radius: float = _base_radius * patrol_radius_multiplier
	if stars == 1:
		target_radius = _base_radius
	elif stars >= 2:
		target_radius = _base_radius * wanted_radius_multiplier

	detection_radius = target_radius

	if _visual:
		_visual.radius = detection_radius
		if _visual.has_method("queue_redraw"):
			_visual.queue_redraw()

	if _collision_shape and _collision_shape.shape is CircleShape2D:
		_collision_shape.shape.radius = detection_radius

func _physics_process(delta: float) -> void:
	if _visual and has_node("/root/HeatManager"):
		var hm = get_node("/root/HeatManager")
		if hm.wanted_stars >= 1:
			# We need to _process the color every frame to get the flashing effect
			_update_color()

	if not is_player_inside or not is_instance_valid(player_ref):
		return

	# Check if player is armed
	var is_armed: bool = false
	if player_ref.weapon_holder_component and player_ref.weapon_holder_component.current_weapon:
		is_armed = true

	if is_armed:
		if has_node("/root/HeatManager"):
			get_node("/root/HeatManager").add_heat(HeatConfig.ARMED_HEAT_RATE * delta)

	# ── Throttled position updates (event-driven, not every frame) ────
	_update_timer += delta
	if _update_timer < UPDATE_INTERVAL:
		return
	_update_timer = 0.0

	var npc: NPC = get_parent() as NPC
	if npc and npc.blackboard:
		var hm: Node = get_node_or_null("/root/HeatManager")
		if hm and hm.wanted_stars >= 1:
			var vel: Vector2 = player_ref.velocity if player_ref is CharacterBody2D else Vector2.ZERO
			var dist: float = npc.global_position.distance_to(player_ref.global_position)
			npc.blackboard.set_var(&"last_known_position", player_ref.global_position)
			npc.blackboard.set_var(&"last_known_velocity", vel)
			npc.blackboard.set_var(&"last_seen_time", Time.get_ticks_msec() / 1000.0)
			npc.blackboard.set_var(&"has_line_of_sight", true)
			npc.blackboard.set_var(&"is_searching", false)
			# Update confidence based on distance
			npc.blackboard.set_var(&"confidence", IntelConfidence.calculate_confidence(dist, true))

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		is_player_inside = true
		player_ref = body
		_update_timer = UPDATE_INTERVAL # Force immediate first update
		if has_node("/root/DetectionManager"):
			get_node("/root/DetectionManager").register_detection()

		# ── Event-driven: immediate blackboard update on sighting ─────
		var npc: NPC = get_parent() as NPC
		if npc and npc.blackboard:
			var hm: Node = get_node_or_null("/root/HeatManager")
			if hm and hm.wanted_stars >= 1:
				var vel: Vector2 = body.velocity if body is CharacterBody2D else Vector2.ZERO
				var dist: float = npc.global_position.distance_to(body.global_position)
				npc.blackboard.set_var(&"last_known_position", body.global_position)
				npc.blackboard.set_var(&"last_known_velocity", vel)
				npc.blackboard.set_var(&"last_seen_time", Time.get_ticks_msec() / 1000.0)
				npc.blackboard.set_var(&"has_line_of_sight", true)
				npc.blackboard.set_var(&"is_searching", false)
				npc.blackboard.set_var(&"confidence", IntelConfidence.calculate_confidence(dist, true))

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		is_player_inside = false
		player_ref = null
		if has_node("/root/DetectionManager"):
			get_node("/root/DetectionManager").unregister_detection()

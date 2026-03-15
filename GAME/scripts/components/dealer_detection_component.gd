class_name DealerDetectionComponent
extends Area2D

var is_player_inside: bool = false
var player_ref: Player = null

@export_category("Colors")
@export var detection_color: Color = Color(1.0, 0.5, 0.0) # Orange for dealers

@export_category("Radius")
@export var detection_radius: float = 400.0

var _visual: Node2D = null
var _collision_shape: CollisionShape2D = null
var _update_timer: float = 0.0
const UPDATE_INTERVAL: float = 0.25

func _ready() -> void:
	# Add visual
	_visual = preload("res://GAME/scripts/ui/circle_visual.gd").new()
	_visual.radius = detection_radius
	_visual.fill_color = detection_color
	_visual.visible = false # Hidden until aggro
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

func _physics_process(delta: float) -> void:
	var npc: NPC = get_parent() as NPC
	if not npc or not npc.blackboard:
		return

	var has_aggro: bool = npc.blackboard.get_var(&"was_shot", false)
	if _visual:
		_visual.visible = has_aggro

	if not has_aggro:
		return

	# ── Throttled position updates ────────────────────────────────────
	_update_timer += delta
	if _update_timer < UPDATE_INTERVAL:
		return
	_update_timer = 0.0

	# ── Priority 1: Track the active attacker (player OR police NPC) ──
	# This is the key fix: we don't require the attacker to be inside the
	# detection ring. We read the attacker node directly from the blackboard
	# and track their real-time position so the dealer can chase and fight
	# back against anyone who shot them — including police outside the ring.
	var raw_attacker = npc.blackboard.get_var(&"attacker", null)
	if raw_attacker and is_instance_valid(raw_attacker):
		var attacker := raw_attacker as Node2D
		if attacker and is_instance_valid(attacker):
			var vel: Vector2 = attacker.velocity if attacker is CharacterBody2D else Vector2.ZERO
			var dist: float = npc.global_position.distance_to(attacker.global_position)
			npc.blackboard.set_var(&"last_known_position", attacker.global_position)
			npc.blackboard.set_var(&"last_known_velocity", vel)
			npc.blackboard.set_var(&"last_seen_time", Time.get_ticks_msec() / 1000.0)
			npc.blackboard.set_var(&"has_line_of_sight", true)
			npc.blackboard.set_var(&"is_searching", false)
			npc.blackboard.set_var(&"confidence", IntelConfidence.calculate_confidence(dist, true))
			return

	# ── Priority 2: Fall back to player if inside ring ────────────────
	if is_player_inside and is_instance_valid(player_ref):
		var vel: Vector2 = player_ref.velocity if player_ref is CharacterBody2D else Vector2.ZERO
		var dist: float = npc.global_position.distance_to(player_ref.global_position)
		npc.blackboard.set_var(&"last_known_position", player_ref.global_position)
		npc.blackboard.set_var(&"last_known_velocity", vel)
		npc.blackboard.set_var(&"last_seen_time", Time.get_ticks_msec() / 1000.0)
		npc.blackboard.set_var(&"has_line_of_sight", true)
		npc.blackboard.set_var(&"is_searching", false)
		npc.blackboard.set_var(&"confidence", IntelConfidence.calculate_confidence(dist, true))

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		is_player_inside = true
		player_ref = body
		_update_timer = UPDATE_INTERVAL # Force immediate first update

		# ── Event-driven: immediate blackboard update on sighting ─────
		var npc: NPC = get_parent() as NPC
		if npc and npc.blackboard:
			if npc.blackboard.get_var(&"was_shot", false):
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

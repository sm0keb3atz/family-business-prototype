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

# Audio / Dialogue
var radio_player: AudioStreamPlayer2D
var bark_player: AudioStreamPlayer2D

var _radio_timer: float = 0.0
var _next_radio_time: float = 15.0

var _bark_timer: float = 0.0
var _next_bark_time: float = 8.0

const RADIO_CHIPS = [
	preload("res://GAME/assets/audio/dialog/police/radiochatter/618971__mrrap4food__radio-police-inside-car.mp3"),
	preload("res://GAME/assets/audio/dialog/police/radiochatter/732209__soundbitersfx__walkie-talkie-beep.wav")
]

const CHASE_BARKS = [
	preload("res://GAME/assets/audio/dialog/police/police_freeze.ogg"),
	preload("res://GAME/assets/audio/dialog/police/police_stoporillshoot.ogg"),
	preload("res://GAME/assets/audio/dialog/police/police_getontheground.ogg"),
	preload("res://GAME/assets/audio/dialog/police/police_stopresisting.ogg"),
	preload("res://GAME/assets/audio/dialog/police/police_wehaveyousurrounded.ogg")
]

const CHASE_TEXTS = [
	"FREEZE!",
	"Stop or I'll shoot!",
	"Get on the ground!",
	"Stop resisting!",
	"We have you surrounded!"
]

const WARNING_TEXTS = [
	"Move along.",
	"I've got my eye on you.",
	"Keep walking."
]

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
	
	_setup_audio_players()

	if has_node("/root/HeatManager"):
		var hm = get_node("/root/HeatManager")
		hm.stars_changed.connect(_on_stars_changed)
		hm.heat_changed.connect(_on_heat_changed)
		_update_radius_for_stars(hm.wanted_stars)
		_update_color()

func _setup_audio_players() -> void:
	# Add AudioStreamPlayer2D for realistic positional audio
	radio_player = AudioStreamPlayer2D.new()
	radio_player.volume_db = -20.0 # Lowered volume
	radio_player.max_distance = 600.0
	radio_player.bus = "SFX" # Using default structure, adjust to SFX bus if exists
	add_child(radio_player)

	bark_player = AudioStreamPlayer2D.new()
	bark_player.volume_db = -10.0 # Lowered volume
	bark_player.max_distance = 1000.0
	bark_player.bus = "SFX"
	add_child(bark_player)

	_next_radio_time = randf_range(2.0, 6.0)   # First radio plays soon after entering radius
	_next_bark_time = randf_range(1.0, 3.0)   # First bark plays soon when wanted

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
			_update_color()

	# Throttled timer for detection and heat logic
	_update_timer += delta
	if _update_timer < UPDATE_INTERVAL:
		return
	_update_timer = 0.0

	var heat_manager = get_node_or_null("/root/HeatManager")
	if heat_manager:
		# Optimization: Only scan for nearby crimes/suspicious NPCs every 0.25s
		# and only if this cop is actually near enough to the player to matter.
		var player = get_tree().get_first_node_in_group("player")
		if player and global_position.distance_to(player.global_position) < detection_radius * 2.0:
			var npcs = get_tree().get_nodes_in_group("npc")
			for npc in npcs:
				if not is_instance_valid(npc): continue
				if npc.role == npc.Role.CUSTOMER and npc.blackboard:
					if npc.blackboard.get_var(&"is_solicited", false):
						var dist = global_position.distance_to(npc.global_position)
						if dist <= detection_radius:
							if npc.blackboard.get_var(&"is_interacting", false):
								heat_manager.add_heat(HeatConfig.CUSTOMER_TALKING_HEAT_RATE * UPDATE_INTERVAL)
							elif not (is_instance_valid(player_ref) and player_ref.has_method("ignores_customer_follow_heat") and player_ref.ignores_customer_follow_heat()):
								heat_manager.add_heat(HeatConfig.CUSTOMER_FOLLOWING_HEAT_RATE * UPDATE_INTERVAL)

	if not is_player_inside or not is_instance_valid(player_ref):
		return

	# Check if player is armed
	var is_armed: bool = false
	if player_ref.weapon_holder_component and player_ref.weapon_holder_component.current_weapon:
		is_armed = true

	if is_armed:
		if heat_manager:
			heat_manager.add_heat(HeatConfig.ARMED_HEAT_RATE * UPDATE_INTERVAL)

	_handle_audio_timers(UPDATE_INTERVAL)

	var npc: NPC = get_parent() as NPC
	if npc and npc.blackboard:
		var hm: Node = get_node_or_null("/root/HeatManager")
		var heat_manager_stars = hm.wanted_stars if hm else 0
		
		# Determine highest priority target (Hostile Player > Hostile Dealer)
		var best_target: Node2D = null
		var min_dist: float = INF
		var investigating_gunshot: bool = npc.blackboard.get_var(&"responding_to_gunshot", false)
		var is_in_pursuit: bool = npc.blackboard.get_var(&"is_in_combat", false)
		
		# Chase player if wanted, OR if this cop is investigating a gunshot and sees the player
		if is_player_inside and is_instance_valid(player_ref) and (heat_manager_stars >= 1 or (heat_manager_stars == 0 and investigating_gunshot)):
			best_target = player_ref
			min_dist = npc.global_position.distance_to(player_ref.global_position)
			if heat_manager_stars == 0 and investigating_gunshot and hm:
				hm.set_stars(1)
			
		# Also check for hostile dealers in radius
		# Optimization: Only engage dealers if we are already "awake" for a pursuit 
		# or if the player is involved, to prevent global police-on-dealer dogpiling.
		if is_in_pursuit or investigating_gunshot or heat_manager_stars > 0:
			var npcs = get_tree().get_nodes_in_group("npc")
			for other in npcs:
				if not is_instance_valid(other) or other == npc: continue
				if other.role == npc.Role.DEALER and other.blackboard and other.blackboard.get_var(&"was_shot", false):
					var dist = npc.global_position.distance_to(other.global_position)
					if dist <= detection_radius and dist < min_dist:
						min_dist = dist
						best_target = other

		if best_target:
			var dist: float = npc.global_position.distance_to(best_target.global_position)
			
			# Enforcement: Only track if within detection radius
			if dist > detection_radius:
				npc.blackboard.set_var(&"has_line_of_sight", false)
				return

			# Raycast Check
			var space_state = npc.get_world_2d().direct_space_state
			var query = PhysicsRayQueryParameters2D.create(npc.global_position, best_target.global_position, 1) # Layer 1 is environment
			query.exclude = [npc.get_rid()]
			var result = space_state.intersect_ray(query)
			
			if result:
				# Hit environment/wall
				npc.blackboard.set_var(&"has_line_of_sight", false)
				return

			var vel: Vector2 = best_target.velocity if best_target is CharacterBody2D else Vector2.ZERO
			npc.blackboard.set_var(&"is_in_combat", true)
			npc.blackboard.set_var(&"target", best_target)
			npc.blackboard.set_var(&"last_known_position", best_target.global_position)
			npc.blackboard.set_var(&"last_known_velocity", vel)
			npc.blackboard.set_var(&"last_seen_time", Time.get_ticks_msec() / 1000.0)
			npc.blackboard.set_var(&"has_line_of_sight", true)
			npc.blackboard.set_var(&"is_searching", false)
			# Update confidence based on distance
			npc.blackboard.set_var(&"confidence", IntelConfidence.calculate_confidence(dist, true))


func _handle_audio_timers(delta: float) -> void:
	var hm = get_node_or_null("/root/HeatManager")
	var stars = hm.wanted_stars if hm else 0
	var heat = hm.heat_value if hm else 0.0
	var npc: NPC = get_parent() as NPC

	# Determine if player is actually close enough for this cop's radio
	var player: Player = null
	if is_instance_valid(player_ref):
		player = player_ref
	else:
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			player = players[0]

	var is_player_nearby := false
	if player:
		var dist_to_player = global_position.distance_to(player.global_position)
		# Use a slight buffer over detection_radius so you hear them just before detection
		is_player_nearby = dist_to_player <= detection_radius * 1.2

	# Radio chatter: used as a proximity warning
	if is_player_nearby:
		_radio_timer += delta
		if _radio_timer >= _next_radio_time:
			_radio_timer = 0.0
			if stars == 0:
				_next_radio_time = randf_range(5.0, 12.0)   # Patrol: every 5–12 sec when close
			else:
				_next_radio_time = randf_range(8.0, 16.0)  # Chase: less often but still audible
			if RADIO_CHIPS.size() > 0 and not radio_player.playing:
				var stream = RADIO_CHIPS[randi() % RADIO_CHIPS.size()]
				radio_player.stream = stream
				radio_player.play()

	# Barks and UI dialogue when player is inside radius
	if is_player_inside:
		_bark_timer += delta
		if _bark_timer >= _next_bark_time:
			_bark_timer = 0.0

			if stars >= 1:
				# Only bark if they can see the player
				if npc and npc.blackboard and npc.blackboard.get_var(&"has_line_of_sight", false):
					var idx = randi() % CHASE_BARKS.size()
					var stream = CHASE_BARKS[idx]
					var text = CHASE_TEXTS[idx]

					if not bark_player.playing:
						bark_player.stream = stream
						bark_player.play()

					if npc.npc_ui:
						npc.npc_ui.show_dialog_bubble(text)
						get_tree().create_timer(2.0).timeout.connect(npc.npc_ui.hide_dialog_bubble)
					_next_bark_time = randf_range(1.5, 3.5)  # Next bark after a successful one
				else:
					_next_bark_time = randf_range(0.5, 1.2)  # Retry soon when no line of sight yet

			elif stars == 0 and heat > 30.0:
				# Suspicion warning barks (no audio standardized for this yet, so just text)
				_next_bark_time = randf_range(6.0, 12.0)
				if npc and npc.npc_ui:
					var text = WARNING_TEXTS[randi() % WARNING_TEXTS.size()]
					npc.npc_ui.show_dialog_bubble(text)
					# Optionally clear it early
					get_tree().create_timer(4.0).timeout.connect(npc.npc_ui.hide_dialog_bubble)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		is_player_inside = true
		player_ref = body
		_update_timer = UPDATE_INTERVAL # Force immediate first update
		if has_node("/root/DetectionManager"):
			get_node("/root/DetectionManager").register_detection()

		# Play patrol radio immediately as a warning that police are close
		var hm = get_node_or_null("/root/HeatManager")
		var stars: int = hm.wanted_stars if hm else 0
		if stars == 0 and RADIO_CHIPS.size() > 0 and not radio_player.playing:
			radio_player.stream = RADIO_CHIPS[randi() % RADIO_CHIPS.size()]
			radio_player.play()
			_radio_timer = 0.0
			_next_radio_time = randf_range(5.0, 12.0)

		# ── Event-driven: immediate blackboard update on sighting ─────
		var npc: NPC = get_parent() as NPC
		if npc and npc.blackboard:
			hm = get_node_or_null("/root/HeatManager")
			stars = hm.wanted_stars if hm else 0
			var investigating: bool = npc.blackboard.get_var(&"responding_to_gunshot", false)
			if hm and (stars >= 1 or (stars == 0 and investigating)):
				if stars == 0 and investigating:
					hm.set_stars(1)
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

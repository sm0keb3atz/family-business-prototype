extends Node

signal heat_changed(value: float)
signal stars_changed(value: int)
signal star_lock_changed(state: bool)
signal player_sighted(pos: Vector2, vel: Vector2)
signal player_lost()

var heat_value: float = 0.0
var wanted_stars: int = 0
var star_lock: bool = false
var unseen_timer: float = 0.0
var _broadcast_timer: float = 0.0

var siren_intro_player: AudioStreamPlayer
var siren_loop_player: AudioStreamPlayer

const SIREN_INTRO_SOUND = preload("res://GAME/assets/audio/dialog/police/sirens/police-intro-sfx-323774.mp3")
const SIREN_LOOP_SOUND = preload("res://GAME/assets/audio/dialog/police/sirens/police-siren-one-loop-loop-able-104019.mp3")

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		if event.keycode == KEY_1:
			set_stars(wanted_stars + 1)
			print("Debug: Added Wanted Star. Current: ", wanted_stars)

func _ready() -> void:
	_setup_siren_players()
	# DetectionManager might not be ready in the exact same frame depending on autoload order,
	# but we can connect safely or wait for it.
	# We will connect in a deferred way or assume DetectionManager is an autoload before this.
	call_deferred("_connect_to_detection_manager")

func _setup_siren_players() -> void:
	siren_intro_player = AudioStreamPlayer.new()
	siren_intro_player.stream = SIREN_INTRO_SOUND
	siren_intro_player.volume_db = -20.0 # Adjust volume as needed
	add_child(siren_intro_player)
	
	siren_loop_player = AudioStreamPlayer.new()
	siren_loop_player.stream = SIREN_LOOP_SOUND
	siren_loop_player.volume_db = -20.0
	add_child(siren_loop_player)
	
	siren_intro_player.finished.connect(_on_siren_intro_finished)

func _on_siren_intro_finished() -> void:
	if wanted_stars >= 1:
		siren_loop_player.play()

func _connect_to_detection_manager() -> void:
	if has_node("/root/DetectionManager"):
		var dm = get_node("/root/DetectionManager")
		if not dm.player_detection_changed.is_connected(_on_player_detection_changed):
			dm.player_detection_changed.connect(_on_player_detection_changed)

func _process(delta: float) -> void:
	update_heat(delta)

func _on_player_detection_changed(state: bool) -> void:
	if state == true:
		unseen_timer = 0.0

func add_heat(amount: float) -> void:
	if is_heat_locked():
		return
	set_heat(heat_value + amount)

func set_heat(value: float) -> void:
	if is_heat_locked():
		heat_value = HeatConfig.MAX_HEAT
		return
		
	var new_heat = clampf(value, 0.0, HeatConfig.MAX_HEAT)
	if heat_value != new_heat:
		heat_value = new_heat
		heat_changed.emit(heat_value)
		
	_evaluate_star_escalation()

func set_stars(value: int) -> void:
	var new_stars = clampi(value, 0, 6) # Changed max to 6 per user request
	if wanted_stars != new_stars:
		var previous_stars = wanted_stars
		wanted_stars = new_stars
		stars_changed.emit(wanted_stars)
		
		# Siren Logic
		if previous_stars == 0 and wanted_stars >= 1:
			siren_intro_player.play()
		elif wanted_stars == 0:
			siren_intro_player.stop()
			siren_loop_player.stop()
		
		# Star lock rules
		if wanted_stars >= 2:
			if not star_lock:
				star_lock = true
				star_lock_changed.emit(star_lock)
			set_heat(HeatConfig.MAX_HEAT)
		elif wanted_stars == 1:
			if star_lock:
				star_lock = false
				star_lock_changed.emit(star_lock)
				
				# RE-DISPATCH: Immediately broadcast position when dropping back to 1 star
				var player = get_tree().get_first_node_in_group("player")
				if player:
					broadcast_player_position(player.global_position)
				
			# INITIAL DISPATCH: Immediately broadcast position to all police (first time 1-star)
			var player = get_tree().get_first_node_in_group("player")
			if player:
				broadcast_player_position(player.global_position)
		elif wanted_stars == 0:
			if star_lock:
				star_lock = false
				star_lock_changed.emit(star_lock)
				
			# Clear searching and tracking state for all police
			var npcs = get_tree().get_nodes_in_group("npc")
			for npc in npcs:
				if npc is NPC and npc.role == NPC.Role.POLICE and npc.blackboard:
					npc.blackboard.set_var(&"is_searching", false)
					npc.blackboard.set_var(&"search_anchor", Vector2.ZERO)
					npc.blackboard.set_var(&"last_known_position", Vector2.ZERO)
					npc.blackboard.set_var(&"last_known_velocity", Vector2.ZERO)
					npc.blackboard.set_var(&"target", null)
					if npc.blackboard.has_var(&"approach_offset"):
						npc.blackboard.erase_var(&"approach_offset")
					
					# Force immediate navigation halt
					if npc.nav_agent:
						npc.nav_agent.set_velocity(Vector2.ZERO)
						npc.nav_agent.target_position = npc.global_position

func update_heat(delta: float) -> void:
	if star_lock and wanted_stars >= 2:
		# When locked at 2+ stars, we check detection to drop stars
		var is_player_detected = false
		if has_node("/root/DetectionManager"):
			is_player_detected = get_node("/root/DetectionManager").is_player_detected
			
		if is_player_detected:
			unseen_timer = 0.0
		else:
			unseen_timer += delta
			if unseen_timer >= HeatConfig.STAR_DROP_TIME:
				unseen_timer = 0.0
				set_stars(wanted_stars - 1)
		return

	# Handle 1-star decay and 0-star heat decay
	var is_player_detected = false
	if has_node("/root/DetectionManager"):
		is_player_detected = get_node("/root/DetectionManager").is_player_detected
		
	if is_player_detected:
		unseen_timer = 0.0
	else:
		unseen_timer += delta
		if unseen_timer >= HeatConfig.STAR_DROP_TIME:
			unseen_timer = 0.0
			if wanted_stars > 0:
				set_stars(wanted_stars - 1)
				
	if can_decay() and not is_player_detected:
		var target_heat = 0.0
		if wanted_stars == 1:
			target_heat = HeatConfig.ONE_STAR_DECAY_TARGET
		
		if heat_value > target_heat:
			var new_heat = move_toward(heat_value, target_heat, HeatConfig.BASE_DECAY_RATE * delta)
			set_heat(new_heat)
			
			if wanted_stars == 1 and heat_value <= HeatConfig.ONE_STAR_DECAY_TARGET:
				set_stars(0)

func is_heat_locked() -> bool:
	return star_lock

func can_decay() -> bool:
	return wanted_stars < 2

func _evaluate_star_escalation() -> void:
	if heat_value >= HeatConfig.MAX_HEAT and wanted_stars == 0:
		set_stars(1)

func on_gunshot(source_pos: Vector2 = Vector2.ZERO) -> void:
	add_heat(HeatConfig.GUNSHOT_HEAT)
	if wanted_stars < 1:
		set_stars(1)
	elif wanted_stars == 1:
		set_stars(2)
	print("HeatManager: Gunshot detected. Heat: ", heat_value, " Stars: ", wanted_stars)
	
	if source_pos != Vector2.ZERO:
		var npcs = get_tree().get_nodes_in_group("npc")
		for npc in npcs:
			if not npc is NPC or not npc.blackboard:
				continue
				
			var dist = npc.global_position.distance_to(source_pos)
			
			if npc.role == NPC.Role.POLICE:
				if dist < 1200.0:
					npc.blackboard.set_var(&"last_known_position", source_pos)
					npc.blackboard.set_var(&"has_line_of_sight", false)
					npc.blackboard.set_var(&"is_searching", true)
					npc.blackboard.set_var(&"search_anchor", source_pos)
					npc.blackboard.set_var(&"last_seen_time", Time.get_ticks_msec() / 1000.0)
			elif npc.role == NPC.Role.DEALER:
				# Dealers already in combat update their target's known position
				# (so they can chase even when player is outside detection ring)
				# But they only become agro from being directly hit, not just from hearing shots
				if dist < 1000.0 and npc.blackboard.get_var(&"was_shot", false):
					var player = get_tree().get_first_node_in_group("player")
					npc.blackboard.set_var(&"damage_source_position", source_pos)
					npc.blackboard.set_var(&"last_known_position", source_pos)
					if player:
						npc.blackboard.set_var(&"attacker", player)
			else:
				# Non-police, non-dealer (Customers) panic if they hear gunfire nearby
				if dist < 1000.0:
					npc.blackboard.set_var(&"heard_gunfire", true)
					npc.blackboard.set_var(&"damage_source_position", source_pos)

func on_kill(role: int) -> void:
	# role matches NPC.Role enum
	add_heat(HeatConfig.KILL_HEAT)
	set_stars(wanted_stars + 1)
	print("HeatManager: Kill detected (Role: ", role, "). Heat: ", heat_value, " Stars: ", wanted_stars)

func reset() -> void:
	set_stars(0)
	set_heat(0.0)
	unseen_timer = 0.0
	
	# Clear tracking/aggro for ALL NPCs (Police and Dealers)
	var npcs = get_tree().get_nodes_in_group("npc")
	for npc in npcs:
		if not is_instance_valid(npc) or not npc.get("blackboard"): 
			continue
			
		var bb = npc.blackboard
		bb.set_var(&"was_shot", false)
		bb.set_var(&"attacker", null)
		bb.set_var(&"target", null)
		bb.set_var(&"has_line_of_sight", false)
		bb.set_var(&"last_known_position", Vector2.ZERO)
		bb.set_var(&"is_searching", false)
		bb.set_var(&"search_anchor", Vector2.ZERO)
		bb.set_var(&"last_known_velocity", Vector2.ZERO)
		bb.set_var(&"heard_gunfire", false)
		if bb.has_var(&"approach_offset"):
			bb.erase_var(&"approach_offset")
		
		# Force stop pathing
		if npc.nav_agent:
			npc.nav_agent.set_velocity(Vector2.ZERO)
			npc.nav_agent.target_position = npc.global_position
			
	print("HeatManager: System reset. All heat and NPC aggression cleared.")
func broadcast_player_position(pos: Vector2, vel: Vector2 = Vector2.ZERO) -> void:
	if pos == Vector2.ZERO:
		return

	# Emit event-driven signal for any listeners
	player_sighted.emit(pos, vel)

	var npcs: Array[Node] = get_tree().get_nodes_in_group("npc")
	var role_index: int = 0
	var roles: Array[String] = ["tracker", "cutoff", "sweeper"]
	for npc in npcs:
		if npc is NPC and npc.role == NPC.Role.POLICE and npc.blackboard:
			# Update last known position for all police
			npc.blackboard.set_var(&"last_known_position", pos)
			npc.blackboard.set_var(&"last_known_velocity", vel)
			npc.blackboard.set_var(&"last_seen_time", Time.get_ticks_msec() / 1000.0)
			# Set confidence to broadcast level (not as strong as direct LOS)
			var dist: float = npc.global_position.distance_to(pos)
			var conf: float = IntelConfidence.calculate_confidence(dist, false)
			# Broadcast intel is weaker than direct LOS — cap at 0.6
			npc.blackboard.set_var(&"confidence", minf(conf + 0.4, 0.6))
			# Assign squad search roles so officers fan out
			npc.blackboard.set_var(&"search_role", roles[role_index % roles.size()])
			role_index += 1
			# Found him! Stop searching and move to him
			npc.blackboard.set_var(&"is_searching", false)

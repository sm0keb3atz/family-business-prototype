extends CharacterBody2D
class_name NPC

# --- Resources ---
@export_group("Data")
@export var stats: CharacterStatsResource
@export var appearance_data: NPCAppearanceResource
@export var behavior_tree: BehaviorTree

enum Gender { MALE, FEMALE }
@export var gender: Gender = Gender.MALE

enum Role { CUSTOMER, DEALER, POLICE }
@export var role: Role = Role.CUSTOMER
@export var dealer_tier: DealerTierResource

# --- Components ---
@onready var movement_component: MovementComponent = %MovementComponent
@onready var health_component: HealthComponent = %HealthComponent
@onready var faction_component: FactionComponent = %FactionComponent
@onready var weapon_holder_component: WeaponHolderComponent = %WeaponHolderComponent
@onready var animation_component: AnimationComponent = %AnimationComponent
@onready var blood_effect_component: BloodEffectComponent = %BloodEffectComponent
@onready var nav_agent: NavigationAgent2D = %NavigationAgent2D
@onready var npc_ui: NpcUI = %NpcUI
@onready var interact_area: Area2D = %InteractArea
@onready var hit_flash_component: HitFlashComponent = %HitFlashComponent
@onready var footstep_component: FootstepComponent = %FootstepComponent



# --- State ---
var spawn_position: Vector2 = Vector2.ZERO
var blackboard: Blackboard
var _hitstun_duration: float = 0.0
var _is_interacting: bool = false
var _panic_audio_player: AudioStreamPlayer2D
var _dialog_hide_timer: SceneTreeTimer
var _dealer_bark_cooldowns := {
	"approach": 0,
	"solicitation": 0
}

const DEALER_APPROACH_BARKS: Array[String] = [
	"Yo, you need to re-up.",
	"Come see what I got.",
	"You lookin' low, pull up.",
	"I got what you need."
]

const DEALER_SOLICITATION_BARKS: Array[String] = [
	"Get off my corner.",
	"You solicitin' on my block?",
	"Take that hustle somewhere else.",
	"Not in front of my spot."
]

const DEALER_COMBAT_BARKS: Array[String] = [
	"You picked the wrong corner!",
	"Get him!",
	"He's hit, push up!",
	"Don't let him get away!"
]

const DEALER_POLICE_COMBAT_BARKS: Array[String] = [
	"Five-O! Light 'em up!",
	"Cops on the block!",
	"Get back to the precinct!",
	"They ain't takin' me today!"
]


# --- BT ---
@onready var bt_player: BTPlayer = %BTPlayer

func _ready() -> void:
	randomize() 
	add_to_group("npc")
	spawn_position = global_position
	z_index = 1
	# NPCs on layer 2, only collide with layer 1 (walls/environment)
	# Avoidance still steers them around each other, but no physics collision = never stuck
	collision_layer = 2
	collision_mask = 1
	
	_randomize_gender_and_appearance()
	_inject_dependencies()
	_setup_connections()
	_setup_bt()
	if role == Role.DEALER:
		var tier = dealer_tier
		if not tier:
			tier = DealerTierResource.new()
			var drug = preload("res://GAME/scripts/resources/drug_definition_resource.gd").new()
			drug.id = "weed"
			drug.display_name = "Weed"
			drug.base_price = 10
			tier.allowed_drugs.append(drug)
			
		var shop_comp = DealerShopComponent.new()
		shop_comp.name = "DealerShopComponent"
		shop_comp.tier_config = tier
		add_child(shop_comp)
		
		# Add Detection Component for combat
		var detect_comp = DealerDetectionComponent.new()
		detect_comp.name = "DealerDetectionComponent"
		detect_comp.detection_radius = 450.0  # Slightly larger than Police patrol to let them spot the player from further away once combat starts
		add_child(detect_comp)
	elif role == Role.POLICE:
		var detect_comp: PoliceDetectionComponent = PoliceDetectionComponent.new()
		detect_comp.name = "PoliceDetectionComponent"
		detect_comp.detection_radius = 350.0 # Standard base radius
		add_child(detect_comp)
		# Debug overlay for visual telemetry (toggle via PoliceDebugOverlay.DEBUG_POLICE)
		var debug_overlay: PoliceDebugOverlay = PoliceDebugOverlay.new()
		debug_overlay.name = "PoliceDebugOverlay"
		add_child(debug_overlay)
	
	_update_ui_icon()

func _update_ui_icon() -> void:
	if not npc_ui: return
	
	if role == Role.DEALER:
		npc_ui.show_type_icon(preload("res://GAME/assets/icons/Dealer_Icon.png"))
	elif role == Role.CUSTOMER and blackboard and blackboard.get_var(&"is_solicited", false):
		npc_ui.show_type_icon(preload("res://GAME/assets/icons/Customer_Icon.png"))
	else:
		npc_ui.hide_type_icon()
	
	# Proactive check: if we just became interactable and player is already here, register!
	var can_interact = (role == Role.DEALER) or (blackboard and blackboard.get_var(&"is_solicited", false))
	if can_interact and interact_area:
		for body in interact_area.get_overlapping_bodies():
			if body.is_in_group("player"):
				_on_interact_area_body_entered(body)

func _randomize_gender_and_appearance() -> void:
	if not appearance_data:
		return

	var body: Sprite2D = %Appearance/Body
	var hair: Sprite2D = %Appearance/Hair
	var outfit: Sprite2D = %Appearance/Outfit

	# Set Body (shared between genders for now)
	var body_tex: Texture2D = appearance_data.get_random_body()
	if body_tex:
		body.texture = body_tex

	# Set Hair based on Gender
	if gender == Gender.MALE:
		var hair_tex: Texture2D = appearance_data.get_random_hairstyle_male()
		if hair_tex:
			hair.texture = hair_tex
	else:
		var hair_tex: Texture2D = appearance_data.get_random_hairstyle_female()
		if hair_tex:
			hair.texture = hair_tex

	# Set Outfit based on Role
	var outfit_tex: Texture2D = null
	match role:
		Role.DEALER:
			outfit_tex = appearance_data.get_random_outfit_dealer()
		Role.POLICE:
			outfit_tex = appearance_data.get_random_outfit_police()
		Role.CUSTOMER:
			if gender == Gender.MALE:
				outfit_tex = appearance_data.get_random_outfit_male()
			else:
				outfit_tex = appearance_data.get_random_outfit_female()
	
	if outfit_tex:
		outfit.texture = outfit_tex

	# Hide accessories based on role (only dealers keep backpack visible)
	if role != Role.DEALER:
		var backpack = %Appearance.get_node_or_null("Backpack")
		if backpack:
			backpack.visible = false

func _inject_dependencies() -> void:
	if movement_component:
		movement_component.parent_body = self
		movement_component.setup(stats)

	if health_component:
		health_component.setup(stats)

	if faction_component:
		faction_component.setup(stats)

	if blood_effect_component:
		blood_effect_component.hurt_box = %HurtBox

	if nav_agent and stats:
		# Randomize walk speed ±30% so each NPC feels unique
		# Remove variance to ensure tuned speeds are perfectly consistent
		var speed_variation: float = 1.0
		var personal_speed: float = stats.move_speed * speed_variation
		nav_agent.max_speed = personal_speed
		# Store the personal speed so BT actions use it
		stats = stats.duplicate()
		stats.move_speed = personal_speed
		# Light avoidance — small radius so NPCs nudge past each other
		nav_agent.avoidance_enabled = true
		nav_agent.radius = 10.0
		nav_agent.neighbor_distance = 50.0
		nav_agent.max_neighbors = 3
		nav_agent.time_horizon_agents = 0.5
		# Police get wider avoidance to prevent bunching during pursuits
		if role == Role.POLICE:
			nav_agent.neighbor_distance = 80.0
			nav_agent.max_neighbors = 5
			nav_agent.time_horizon_agents = 0.8

	if footstep_component:
		footstep_component.animation_player = %AnimationPlayer
		footstep_component.body_sprite = %Appearance/Body
		footstep_component.dust_sprite = get_node_or_null("Footsteps")
		var fs_audio = get_node_or_null("%FootstepAudio") # Try to find unique or relative
		if not fs_audio:
			fs_audio = get_node_or_null("FootstepAudio")
		footstep_component.footstep_audio = fs_audio
		footstep_component.on_screen_notifier = get_node_or_null("VisibleOnScreenNotifier2D")

func _setup_connections() -> void:
	if health_component:
		health_component.health_changed.connect(_on_health_changed)
		health_component.damage_taken.connect(_on_damage_taken)
		health_component.died.connect(_on_died)
	if nav_agent:
		nav_agent.velocity_computed.connect(_on_velocity_computed)
	if interact_area:
		interact_area.body_entered.connect(_on_interact_area_body_entered)
		interact_area.body_exited.connect(_on_interact_area_body_exited)


func _physics_process(delta: float) -> void:
	if _hitstun_duration > 0:
		_hitstun_duration -= delta
	
	# If solicited but player is too far, give up
	if blackboard and blackboard.get_var(&"is_solicited", false):
		var player = get_tree().get_first_node_in_group("player")
		if player and global_position.distance_to(player.global_position) > 800.0:
			blackboard.set_var(&"is_solicited", false)
			_update_ui_icon()

func _on_velocity_computed(safe_velocity: Vector2) -> void:
	if movement_component:
		if _hitstun_duration > 0 or _is_interacting:
			movement_component.move_velocity(Vector2.ZERO)
			return
		# Smooth velocity for less robotic movement
		var smoothed: Vector2 = velocity.lerp(safe_velocity, 0.15)
		# Snap to zero when nearly stopped to prevent animation flicker
		if smoothed.length_squared() < 25.0: # < 5 px/s
			smoothed = Vector2.ZERO
		movement_component.move_velocity(smoothed)
		if animation_component:
			animation_component.update_animation(smoothed)


func _setup_bt() -> void:
	if bt_player:
		if behavior_tree:
			print("NPC: Setting BehaviorTree for ", name, " (Role: ", role, ") to ", behavior_tree.resource_path)
			bt_player.behavior_tree = behavior_tree
			bt_player.restart()
		else:
			print("NPC: No BehaviorTree assigned for ", name, ", using default.")
		
		blackboard = bt_player.get_blackboard()
		if blackboard:
			blackboard.set_var(&"was_shot", false)
			blackboard.set_var(&"damage_source_position", Vector2.ZERO)
			blackboard.set_var(&"attacker", null)
			blackboard.set_var(&"is_interacting", false)
			blackboard.set_var(&"is_solicited", false)
			blackboard.set_var(&"target", null)
			blackboard.set_var(&"requested_grams", 0)
			blackboard.set_var(&"offered_payout", 0)
			blackboard.set_var(&"last_known_position", Vector2.ZERO)
			blackboard.set_var(&"has_line_of_sight", false)
			blackboard.set_var(&"is_searching", false)
			blackboard.set_var(&"search_anchor", Vector2.ZERO)
			blackboard.set_var(&"last_seen_time", 0.0)
			blackboard.set_var(&"search_cooldown_until", 0.0)
			blackboard.set_var(&"search_role", "")
			blackboard.set_var(&"confidence", 0.0)
			blackboard.set_var(&"last_known_velocity", Vector2.ZERO)
			blackboard.set_var(&"heard_gunfire", false) # Track if gunshot was heard
			blackboard.set_var(&"path_markers", []) # Ensure path_markers exists even for non-path characters

	_setup_panic_audio()

func _setup_panic_audio() -> void:
	if not _panic_audio_player:
		_panic_audio_player = AudioStreamPlayer2D.new()
		_panic_audio_player.name = "PanicAudio"
		_panic_audio_player.max_distance = 600.0
		_panic_audio_player.attenuation = 2.0
		_panic_audio_player.bus = &"SFX"
		add_child(_panic_audio_player)

func play_panic_scream() -> void:
	if not _panic_audio_player or _panic_audio_player.playing:
		return
	
	# Only non-police scream in panic for now
	if role == Role.POLICE:
		return

	var screams: Array[String] = []
	if gender == Gender.MALE:
		screams = [
			"res://GAME/assets/audio/dialog/customer/male/panic/male-scream1.ogg",
			"res://GAME/assets/audio/dialog/customer/male/panic/male-screams3.ogg",
			"res://GAME/assets/audio/dialog/customer/male/panic/male-scream5.ogg"
		]
	else:
		screams = [
			"res://GAME/assets/audio/dialog/customer/female/panic/female-scream1.ogg",
			"res://GAME/assets/audio/dialog/customer/female/panic/female-scream2.ogg",
			"res://GAME/assets/audio/dialog/customer/female/panic/female-scream3.ogg",
			"res://GAME/assets/audio/dialog/customer/female/panic/female-scream4.ogg"
		]
	
	if screams.is_empty(): return
	
	var chosen = screams.pick_random()
	var stream = load(chosen)
	if stream:
		_panic_audio_player.stream = stream
		_panic_audio_player.play()

func bark(text: String, duration: float = 2.5) -> void:
	if not npc_ui:
		return

	npc_ui.show_dialog_bubble(text)
	if _dialog_hide_timer and _dialog_hide_timer.timeout.is_connected(npc_ui.hide_dialog_bubble):
		_dialog_hide_timer.timeout.disconnect(npc_ui.hide_dialog_bubble)
	_dialog_hide_timer = get_tree().create_timer(duration)
	_dialog_hide_timer.timeout.connect(npc_ui.hide_dialog_bubble)

func bark_dealer_feedback(kind: String) -> void:
	if role != Role.DEALER:
		return

	var now := Time.get_ticks_msec()
	var ready_at: int = _dealer_bark_cooldowns.get(kind, 0)
	if now < ready_at:
		return

	var lines: Array[String] = []
	match kind:
		"approach":
			lines = DEALER_APPROACH_BARKS
		"solicitation":
			lines = DEALER_SOLICITATION_BARKS
		_:
			return

	if lines.is_empty():
		return

	_dealer_bark_cooldowns[kind] = now + 4000
	bark(lines.pick_random())

func bark_dealer_combat(target: Node2D) -> void:
	if role != Role.DEALER:
		return

	var now := Time.get_ticks_msec()
	var ready_at: int = _dealer_bark_cooldowns.get("combat", 0)
	if now < ready_at:
		return

	var lines := DEALER_COMBAT_BARKS
	if target and target.is_in_group("npc") and target.get("role") == Role.POLICE:
		lines = DEALER_POLICE_COMBAT_BARKS
	
	_dealer_bark_cooldowns["combat"] = now + 6000 # Longer cooldown for combat barks
	bark(lines.pick_random(), 3.0)

# --- Damage Interface ---
# Called by BulletBase when a projectile hits this body.
func take_damage(amount: int, source_position: Vector2 = Vector2.ZERO, hit_direction: Vector2 = Vector2.ZERO, shooter: Node2D = null) -> void:
	# Friendly Fire Prevention: Ignore damage if both the victim and shooter share the same NPC role.
	# We check 'role' and 'is_in_group("npc")' to ensure we only block ally-on-ally hits.
	if shooter and shooter.is_in_group("npc") and shooter.get("role") == role:
		return

	if health_component:
		health_component.take_damage(amount)

	if hit_flash_component:
		hit_flash_component.flash()

	# Blood FX logic
	if source_position != Vector2.ZERO:
		_hitstun_duration = 0.1 # Very brief pause
		if blood_effect_component:
			blood_effect_component.spawn_blood(source_position, hit_direction)

	# Write to blackboard so BT can react
	if blackboard:
		blackboard.set_var(&"was_shot", true)
		if shooter and is_instance_valid(shooter):
			blackboard.set_var(&"attacker", shooter)
			# Immediately seed target so check_line_of_sight / shoot_target
			# don't fail on the very first BT tick (before set_aggro_target runs).
			blackboard.set_var(&"target", shooter)
			# Use the shooter's real position, not just the bullet origin.
			blackboard.set_var(&"last_known_position", shooter.global_position)
			blackboard.set_var(&"last_seen_time", Time.get_ticks_msec() / 1000.0)
		elif source_position != Vector2.ZERO:
			blackboard.set_var(&"damage_source_position", source_position)
			# No shooter ref — fall back to bullet origin as best guess.
			blackboard.set_var(&"last_known_position", source_position)
			blackboard.set_var(&"last_seen_time", Time.get_ticks_msec() / 1000.0)


# --- Interaction ---
func interact() -> void:
	_is_interacting = true
	if blackboard:
		blackboard.set_var(&"is_interacting", true)
	var player = get_tree().get_first_node_in_group("player")
	if player and animation_component:
		var dir = global_position.direction_to(player.global_position)
		animation_component.last_direction = dir
		animation_component.update_animation(Vector2.ZERO) # Force idle facing player

	if role == Role.DEALER and has_node("DealerShopComponent"):
		if player and player.shop_ui:
			var shop_comp = get_node("DealerShopComponent")
			player.shop_ui.open_shop(shop_comp, player)
		return

	if blackboard and blackboard.get_var(&"is_solicited", false):
		AudioManager.play_ui_menu()
		_handle_solicited_interaction(player)
		return

	if npc_ui:
		bark("Hey there! Can't talk right now.")

func _handle_solicited_interaction(player: Player) -> void:
	var grams = blackboard.get_var(&"requested_grams", 0)
	var payout = blackboard.get_var(&"offered_payout", 0)
	
	if Input.is_action_just_pressed("ui_accept"): # Dealing with Space/Enter
		var inv = player.inventory_component
		var found_drug_id = ""
		for k in inv.drugs.keys():
			if str(k).to_lower() == "weed":
				found_drug_id = k
				break
				
		if found_drug_id != "" and inv.has_drug(found_drug_id, grams):
			inv.remove_drug(found_drug_id, grams)
			player.progression.money += payout
			
			# Apply Heat
			# In a larger system, we'd lookup the actual resource. Using def values here.
			var base_heat = 1.0
			var risk_mult = 1.0
			var sale_heat = base_heat * grams * risk_mult
			if has_node("/root/HeatManager"):
				get_node("/root/HeatManager").add_heat(sale_heat)
			
			# XP and Indicators
			var sale_xp = int(grams * 5) # Example: 5 XP per gram
			player.progression.xp += sale_xp
			
			var pui = player.get("player_ui")
			if pui:
				pui.spawn_indicator("money_up", "+$" + str(payout))
				pui.spawn_indicator("product", "-" + str(grams) + "g")
				pui.spawn_indicator("xp", "+" + str(sale_xp) + " XP")
			
			AudioManager.play_transaction()
			
			if npc_ui:
				npc_ui.show_dialog_bubble("Thanks man.")
			
			# Reset state so client returns to path
			blackboard.set_var(&"is_solicited", false)
			_is_interacting = false
			blackboard.set_var(&"is_interacting", false)
			
			# CRITICAL: Force unregister from player to prevent re-interaction prompt
			if player:
				player.unregister_interactable(self)
				if player.get("current_interactable") == self:
					player._is_interacting = false
					player.current_interactable = null
			
			_update_ui_icon()
		else:
			if npc_ui:
				npc_ui.show_dialog_bubble("You don't have enough!")
			
			# Exit solicitation if player can't fulfill
			await get_tree().create_timer(1.5).timeout
			if is_instance_valid(self):
				blackboard.set_var(&"is_solicited", false)
				_is_interacting = false
				blackboard.set_var(&"is_interacting", false)
				
				# CRITICAL: Force unregister from player to prevent re-interaction prompt
				if player:
					player.unregister_interactable(self)
					if player.get("current_interactable") == self:
						player._is_interacting = false
						player.current_interactable = null
				
				_update_ui_icon()
				if npc_ui:
					npc_ui.hide_dialog_bubble()
	else:
		if npc_ui:
			npc_ui.show_dialog_bubble("I need " + str(grams) + "g. Give you $" + str(payout) + ".\n(Press Space)")


func _on_interact_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("register_interactable"):
		# Only allow interaction if we are a dealer OR a solicited customer
		var can_interact = (role == Role.DEALER) or (blackboard and blackboard.get_var(&"is_solicited", false))
		if can_interact:
			body.register_interactable(self)
			if role == Role.DEALER:
				bark_dealer_feedback("approach")
			elif npc_ui:
				npc_ui.hide_dialog_bubble()
			if body.get("player_ui"):
				body.player_ui.hide_dialog_bubble()

func _on_interact_area_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		# Always clear interaction state when player walks away
		if body.has_method("unregister_interactable"):
			body.unregister_interactable(self)
		_is_interacting = false
		if blackboard:
			blackboard.set_var(&"is_interacting", false)
		if npc_ui and role != Role.DEALER:
			npc_ui.hide_dialog_bubble()

# --- Callbacks ---
func _on_health_changed(current: int, maximum: int) -> void:
	if npc_ui:
		npc_ui.update_health(float(current), float(maximum))

func _on_damage_taken(amount: int) -> void:
	if npc_ui:
		npc_ui.spawn_indicator("damage", str(amount))

func _on_died() -> void:
	if has_node("/root/HeatManager"):
		get_node("/root/HeatManager").on_kill(role)
	
	if role == Role.DEALER:
		var territory = get_meta(&"territory") if has_meta(&"territory") else null
		if territory and territory.reputation_component:
			territory.reputation_component.add_reputation(-25.0)
			var p = get_tree().get_first_node_in_group("player")
			if p and p.get("player_ui"):
				p.player_ui.spawn_indicator("money_up", "-25 REP (Dealer Killed)")
	
	# Disable processing and AI
	set_physics_process(false)
	set_process(false)
	if bt_player:
		bt_player.active = false
	
	if animation_component:
		animation_component.update_animation(Vector2.ZERO) # Force idle
		if animation_component.animation_player:
			animation_component.animation_player.stop()
	
	# Hide Detection Rings
	if role == Role.POLICE:
		var detect_comp = get_node_or_null("PoliceDetectionComponent")
		if detect_comp:
			detect_comp.visible = false
			detect_comp.set_physics_process(false)
			detect_comp.set_deferred("monitoring", false)
			detect_comp.set_deferred("monitorable", false)
	elif role == Role.DEALER:
		var detect_comp = get_node_or_null("DealerDetectionComponent")
		if detect_comp:
			detect_comp.visible = false
			detect_comp.set_physics_process(false)
			detect_comp.set_deferred("monitoring", false)
			detect_comp.set_deferred("monitorable", false)
	
	# Disable collisions
	collision_layer = 0
	collision_mask = 0
	if find_child("HurtBox"):
		var hb = find_child("HurtBox")
		hb.collision_layer = 0
		hb.collision_mask = 0
	
	# Hide UI
	if npc_ui:
		npc_ui.hide()
	
	# Blood Pool
	if blood_effect_component:
		blood_effect_component.spawn_blood_pool()
	
	# Death Animation (Rotate and Fade)
	var death_tween = create_tween()
	
	# 1. Rotate immediately
	var target_rotation = deg_to_rad(randf_range(75.0, 85.0))
	if animation_component and animation_component.last_direction.x < 0:
		target_rotation = -target_rotation
	
	death_tween.tween_property(self, "rotation", target_rotation, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	# 2. Stay on ground for a moment, then fade
	death_tween.tween_interval(1.5)
	death_tween.tween_property(self, "modulate:a", 0.0, 1.0).set_trans(Tween.TRANS_SINE)
	
	# 3. Cleanup
	death_tween.tween_callback(queue_free)

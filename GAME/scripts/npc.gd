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
@export var is_potential_girlfriend: bool = false
@export var gf_resource: GirlfriendResource

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
var _lod_tier: int = 0          # 0=Full, 1=Reduced, 2=Dormant
var _is_dead: bool = false
var _panic_audio_player: AudioStreamPlayer2D
var _dialog_hide_timer: SceneTreeTimer
var _dealer_bark_cooldowns := {
	"approach": 0,
	"solicitation": 0
}
var potential_gf_level: int = 1
var _gf_reset_timer: SceneTreeTimer
var gf_is_requesting: bool = false
var gf_request_amount: int = 0
var gf_request_timer: float = 0.0
var gf_request_grace_timer: float = 0.0
var _managed_by_pool: bool = false
var _is_pooled: bool = false
var _core_runtime_initialized: bool = false
var _role_runtime_initialized: bool = false
var _visual_state_initialized: bool = false
var _path_markers: Array = []
var territory_id: StringName = &""

# --- Stuck Detection Fail-Safes ---
var _stuck_accumulator: float = 0.0
var _last_stuck_pos: Vector2 = Vector2.ZERO
var _stuck_check_timer: float = 0.0

const NPC_COLLISION_LAYER: int = 2
const NPC_COLLISION_MASK: int = 1
const HURTBOX_COLLISION_LAYER: int = 4
const HURTBOX_COLLISION_MASK: int = 0
const INTERACT_COLLISION_LAYER: int = 0
const INTERACT_COLLISION_MASK: int = 2

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
	# NPCs on layer 2, only collide with layer 1 (walls/environment)
	# Avoidance still steers them around each other, but no physics collision = never stuck
	collision_layer = NPC_COLLISION_LAYER
	collision_mask = NPC_COLLISION_MASK
	y_sort_enabled = true
	_managed_by_pool = bool(get_meta(&"managed_by_pool", false))
	_ensure_core_runtime_initialized()
	if _managed_by_pool:
		prepare_for_pool()
	else:
		activate_from_pool(global_position, {"lod_tier": 0})

func _update_ui_icon() -> void:
	if not npc_ui: return
	if _is_pooled:
		npc_ui.hide_type_icon()
		npc_ui.hide_request_badge()
		return
	
	if role == Role.DEALER:
		npc_ui.show_type_icon(preload("res://GAME/assets/icons/Dealer_Icon.png"))
		npc_ui.hide_request_badge()
	elif role == Role.CUSTOMER and blackboard and blackboard.get_var(&"is_solicited", false):
		npc_ui.show_type_icon(preload("res://GAME/assets/icons/Customer_Icon.png"))
		var requested_drug_id: StringName = blackboard.get_var(&"requested_drug_id", &"")
		var requested_grams: int = blackboard.get_var(&"requested_grams", 0)
		if not String(requested_drug_id).is_empty() and requested_grams > 0:
			npc_ui.show_request_badge(DrugCatalog.get_product_icon(requested_drug_id, false), requested_grams)
		else:
			npc_ui.hide_request_badge()
	elif is_potential_girlfriend:
		npc_ui.show_type_icon(preload("res://GAME/assets/icons/Girlfriend_Icon.png"))
		npc_ui.update_level(potential_gf_level, -1)
		npc_ui.hide_request_badge()
	elif gf_resource != null:
		npc_ui.show_type_icon(preload("res://GAME/assets/icons/Girlfriend_Icon.png"))
		npc_ui.update_level(gf_resource.level, -1)
		npc_ui.hide_request_badge()
	else:
		npc_ui.hide_type_icon()
		npc_ui.hide_request_badge()
	
	# Proactive check: if we just became interactable and player is already here, register!
	var is_dealer_customer: bool = blackboard and blackboard.has_var(&"is_dealer_customer") and blackboard.get_var(&"is_dealer_customer", false)
	var solicited_ok: bool = blackboard and blackboard.get_var(&"is_solicited", false) and not is_dealer_customer
	var can_interact = (role == Role.DEALER) or solicited_ok or is_potential_girlfriend
	if can_interact and interact_area and interact_area.monitoring:
		for body in interact_area.get_overlapping_bodies():
			if body.is_in_group("player"):
				_on_interact_area_body_entered(body)


func _apply_gf_appearance() -> void:
	if not gf_resource or not gf_resource.appearance: return
	
	var app = gf_resource.appearance
	%Appearance/Body.texture = app.body_texture
	%Appearance/Hair.texture = app.hair_texture
	%Appearance/Outfit.texture = app.outfit_texture
	
	for node_name in ["Backpack", "Beard", "Mustache", "Glasses", "Hat"]:
		var sprite = %Appearance.get_node_or_null(node_name)
		if sprite:
			var tex = app.get(node_name.to_lower() + "_texture")
			if tex:
				sprite.texture = tex
				sprite.visible = true
			else:
				sprite.visible = false

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

	_hide_nondealer_backpack()


func _hide_nondealer_backpack() -> void:
	# Hide accessories based on role (only dealers keep backpack visible)
	if role != Role.DEALER:
		var backpack = %Appearance.get_node_or_null("Backpack")
		if backpack:
			backpack.visible = false


## Fast path: textures chosen at ghost registration; get_texture_cached avoids load() spikes when realizing.
func _try_apply_baked_visual_from_identity(identity: NPCIdentity) -> bool:
	if not identity.metadata.get(&"app_baked", false):
		return false
	var ad: NPCAppearanceResource = identity.appearance_data as NPCAppearanceResource
	if not ad:
		return false

	var body: Sprite2D = %Appearance/Body
	var hair: Sprite2D = %Appearance/Hair
	var outfit: Sprite2D = %Appearance/Outfit
	var bp: String = String(identity.metadata.get(&"app_body_path", ""))
	var hp: String = String(identity.metadata.get(&"app_hair_path", ""))
	var op: String = String(identity.metadata.get(&"app_outfit_path", ""))
	var body_tex: Texture2D = ad.get_texture_cached(bp) if not bp.is_empty() else null
	var hair_tex: Texture2D = ad.get_texture_cached(hp) if not hp.is_empty() else null
	var outfit_tex: Texture2D = ad.get_texture_cached(op) if not op.is_empty() else null
	if body_tex:
		body.texture = body_tex
	if hair_tex:
		hair.texture = hair_tex
	if outfit_tex:
		outfit.texture = outfit_tex

	var backpack = %Appearance.get_node_or_null("Backpack")
	if backpack:
		backpack.visible = bool(identity.metadata.get(&"app_backpack_visible", false))

	_visual_state_initialized = true
	return body_tex != null or hair_tex != null or outfit_tex != null


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
		nav_agent.radius = 20.0 # Slightly reduced to allow being closer
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

	if blackboard and blackboard.has_var(&"is_dealer_customer") and blackboard.get_var(&"is_dealer_customer", false):
		var dealer_node: Node2D = null
		if blackboard.has_var(&"dealer_purchase_target"):
			var raw_dealer: Variant = blackboard.get_var(&"dealer_purchase_target", null)
			if is_instance_valid(raw_dealer) and raw_dealer is Node2D:
				dealer_node = raw_dealer
		if not is_instance_valid(dealer_node):
			_reset_dealer_customer_state()
		elif global_position.distance_to(dealer_node.global_position) > 1400.0:
			_reset_dealer_customer_state()

	if blackboard and blackboard.has_var(&"is_front_business_customer") and blackboard.get_var(&"is_front_business_customer", false):
		var business_target: Node2D = null
		if blackboard.has_var(&"front_business_purchase_target"):
			var raw_business: Variant = blackboard.get_var(&"front_business_purchase_target", null)
			if is_instance_valid(raw_business) and raw_business is Node2D:
				business_target = raw_business
		if not is_instance_valid(business_target):
			_reset_front_business_customer_state()
		elif global_position.distance_to(business_target.global_position) > 1400.0:
			_reset_front_business_customer_state()

	# Girlfriend Request Logic
	if gf_resource and gf_resource.is_following and not gf_is_requesting:
		if gf_request_timer > 0.0:
			gf_request_timer -= delta
			if gf_request_timer <= 0.0:
				_trigger_girlfriend_request()
				
	if gf_is_requesting:
		if gf_request_grace_timer > 0.0:
			gf_request_grace_timer -= delta
		else:
			var player = get_tree().get_first_node_in_group("player")
			# Increased decline distance slightly and it only applies after grace period ends
			if player and global_position.distance_to(player.global_position) > 400.0:
				_decline_girlfriend_request()

	_run_stuck_detection_fail_safe(delta)

	# If avoidance is disabled (e.g. LOD tier 1), the NavigationServer will NOT emit velocity_computed.
	# We must manually process the requested velocity so the NPC still moves and animates.
	if nav_agent and not nav_agent.avoidance_enabled:
		_on_velocity_computed(nav_agent.velocity)
		nav_agent.velocity = Vector2.ZERO

func _run_stuck_detection_fail_safe(delta: float) -> void:
	if _is_pooled or _is_dead:
		return
	
	# Fail-Safe 1: NavMesh check (only for moving roles, dealers are static)
	if role != Role.DEALER:
		_stuck_check_timer += delta
		if _stuck_check_timer >= 1.0:
			_stuck_check_timer = 0.0
			
			# Check NavMesh proximity
			var map = get_world_2d().get_navigation_map()
			var closest = NavigationServer2D.map_get_closest_point(map, global_position)
			if closest.distance_to(global_position) > 60.0:
				# We are too far from any valid navigation poly (likely inside a building)
				if _managed_by_pool:
					etherealize_to_pool()
				else:
					queue_free()
				return

			# Fail-Safe 2: Active Stuck Detection (moved < 5px while trying to move)
			var dist_moved = global_position.distance_to(_last_stuck_pos)
			if velocity.length() > 60.0 and dist_moved < 5.0:
				_stuck_accumulator += 1.0
				if _stuck_accumulator >= 5.0:
					# Stuck for 5 seconds
					if _managed_by_pool:
						etherealize_to_pool()
					else:
						queue_free()
					return
			else:
				_stuck_accumulator = 0.0
			
			_last_stuck_pos = global_position

func _trigger_girlfriend_request() -> void:
	gf_is_requesting = true
	gf_request_amount = gf_resource.level * randi_range(20, 50)
	var request_barks = [
		"Can I get $" + str(gf_request_amount) + "?",
		"I saw something nice, only $" + str(gf_request_amount) + "...",
		"You got $" + str(gf_request_amount) + "?",
		"Baby, I need $" + str(gf_request_amount) + " for my hair."
	]
	bark(request_barks.pick_random() + "\n(Press Space)", 999.0, true, "gf_request") 
	gf_request_grace_timer = 5.0
	
	# Force register interactable if player is already in range
	var player = get_tree().get_first_node_in_group("player")
	if player and interact_area.overlaps_body(player):
		if player.has_method("register_interactable"):
			player.register_interactable(self)

func _decline_girlfriend_request() -> void:
	gf_is_requesting = false
	gf_resource.set_relationship(gf_resource.relationship - 10.0)
	if gf_resource and gf_resource.relationship <= 0.0:
		break_up_due_to_relationship()
		return
	bark("Fine, ignore me then!", 3.0, true)
	gf_request_timer = randf_range(45.0, 90.0)
	_clear_interaction_with_player()

func _clear_interaction_with_player(player: Node2D = null) -> void:
	if player == null:
		player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	if player.has_method("unregister_interactable"):
		player.unregister_interactable(self)
	if player.get("current_interactable") == self:
		player._is_interacting = false
		player.current_interactable = null

func _reset_girlfriend_request_state() -> void:
	gf_is_requesting = false
	gf_request_amount = 0
	gf_request_grace_timer = 0.0
	if npc_ui:
		npc_ui.hide_dialog_bubble()

func break_up_due_to_relationship() -> void:
	if not gf_resource:
		return
	dismiss(true)

func _on_velocity_computed(safe_velocity: Vector2) -> void:
	if movement_component:
		if _hitstun_duration > 0 or _is_interacting:
			movement_component.move_velocity(Vector2.ZERO)
			return
		# Tighten smoothing (0.3 instead of 0.15) for faster stops
		var smoothed: Vector2 = velocity.lerp(safe_velocity, 0.3)
		# Snap to zero when nearly stopped to prevent animation flicker
		if smoothed.length_squared() < 25.0: # < 5 px/s
			smoothed = Vector2.ZERO
		movement_component.move_velocity(smoothed)
		if animation_component:
			animation_component.update_animation(smoothed)

# Removed hardcoded follow logic in favor of Behavior Tree


func _setup_bt() -> void:
	if bt_player:
		if behavior_tree:
			bt_player.behavior_tree = behavior_tree
			bt_player.restart()
		
		blackboard = bt_player.get_blackboard()
		if blackboard:
			blackboard.set_var(&"was_shot", false)
			blackboard.set_var(&"damage_source_position", Vector2.ZERO)
			blackboard.set_var(&"attacker", null)
			blackboard.set_var(&"is_interacting", false)
			blackboard.set_var(&"is_solicited", false)
			blackboard.set_var(&"target", null)
			blackboard.set_var(&"requested_drug_id", &"")
			blackboard.set_var(&"requested_grams", 0)
			blackboard.set_var(&"offered_payout", 0)
			blackboard.set_var(&"customer_tier", 1)
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
			blackboard.set_var(&"is_dealer_customer", false)
			blackboard.set_var(&"approach_target", null)
			blackboard.set_var(&"dealer_purchase_target", null)
			blackboard.set_var(&"dealer_purchase_drug_id", &"")
			blackboard.set_var(&"dealer_purchase_grams", 0)
			blackboard.set_var(&"is_front_business_customer", false)
			blackboard.set_var(&"front_business_purchase_target", null)
			blackboard.set_var(&"front_business_level", 0)
			blackboard.set_var(&"path_markers", _path_markers.duplicate())

	_setup_panic_audio()

func set_path_markers(markers: Array) -> void:
	_path_markers = markers.duplicate()
	if blackboard:
		blackboard.set_var(&"path_markers", _path_markers.duplicate())

func prepare_for_pool() -> void:
	if _is_dead:
		return
	_ensure_core_runtime_initialized()
	_is_pooled = true
	_is_interacting = false
	_reset_runtime_state_for_pool()
	_set_detection_component_active(false)
	_set_interact_area_active(false)
	_set_collisions_active(false)
	velocity = Vector2.ZERO
	visible = false
	modulate.a = 1.0
	set_process(false)
	set_physics_process(false)
	
	# Keep role runtime prewarmed; only visuals need to be rebuilt per identity.
	_visual_state_initialized = false
	
	# Clean up role-specific components to ensure a fresh slate
	_cleanup_role_components()
	
	if bt_player:
		bt_player.active = false
		bt_player.set_process_mode(PROCESS_MODE_DISABLED)
	if nav_agent:
		nav_agent.avoidance_enabled = false
	if animation_component and animation_component.animation_player:
		animation_component.animation_player.stop()
	if npc_ui:
		npc_ui.hide()
	_lod_tier = 2

func activate_from_pool(spawn_pos: Vector2, role_context: Dictionary = {}) -> void:
	_ensure_core_runtime_initialized()
	global_position = spawn_pos
	spawn_position = spawn_pos
	_is_pooled = false
	_apply_activation_context(role_context)
	_ensure_visual_state()
	_ensure_role_runtime_initialized()
	_apply_role_runtime_state()
	_setup_bt()
	_set_detection_component_active(true)
	_set_interact_area_active(true)
	_set_collisions_active(true)
	visible = true
	modulate.a = 1.0
	set_process(true)
	if npc_ui:
		npc_ui.show()
	_update_ui_icon()
	set_physics_process(true)
	set_lod_tier(role_context.get("lod_tier", 0))

## ─── Identity Realization ──────────────────────────────────────────────────
## Used by NPCManager to turn a "Ghost" (data) into a "Real Actor" (this node).
## Split into two phases to prevent frame spikes when many NPCs realize at once:
##   Phase 1 (immediate): position, visuals, collisions — NPC appears this frame.
##   Phase 2 (manager-budgeted): BT restart, detection, interaction — AI starts later.
func realize_from_identity(identity: NPCIdentity) -> void:
	_ensure_core_runtime_initialized()
	
	# Mapping state from identity
	self.role = identity.role
	self.gender = identity.gender
	self.global_position = identity.global_position
	self.spawn_position = identity.global_position
	self.appearance_data = identity.appearance_data
	self.behavior_tree = identity.behavior_tree
	self.stats = identity.stats.duplicate() if identity.stats else null
	self.dealer_tier = identity.dealer_tier
	self.territory_id = identity.territory_id
	set_path_markers(identity.path_markers)
	
	_is_pooled = false
	_is_interacting = false
	velocity = Vector2.ZERO
	blackboard = null
	# Ghosts bake outfit paths at registration so we do not load() textures during territory crossings.
	if gf_resource and gf_resource.appearance:
		_visual_state_initialized = false
		_ensure_visual_state()
	else:
		_visual_state_initialized = false
		if not _try_apply_baked_visual_from_identity(identity):
			_ensure_visual_state()
	_ensure_role_runtime_initialized()
	
	# --- Phase 1: appear visually this frame (cheap) ---
	if bt_player:
		bt_player.active = false
		bt_player.set_process_mode(PROCESS_MODE_DISABLED)
	_set_detection_component_active(false)
	_set_interact_area_active(false)
	_set_collisions_active(true)
	visible = true
	modulate.a = 1.0
	set_process(true)
	set_physics_process(true)
	_lod_tier = 2


## Finishes realization when NPCManager spends the stage-2 activation budget.
func finish_realization() -> void:
	# Guard: if we got pooled again before this fires, bail out
	if _is_pooled or _is_dead:
		return

	_apply_role_runtime_state()
	_setup_bt()

	if npc_ui:
		npc_ui.show()
	_update_ui_icon()
	if nav_agent:
		nav_agent.avoidance_enabled = false

	if bt_player:
		bt_player.active = true
		bt_player.set_process_mode(PROCESS_MODE_INHERIT)


func complete_realization() -> void:
	if _is_pooled or _is_dead:
		return

	_set_interact_area_active(true)

	# Dealers stay in reduced-cost tier by default to avoid nav-avoidance spikes
	# when the player approaches dealer spawn points. Police/customers still use full tier.
	var activation_tier: int = 1 if role == Role.DEALER else 0
	set_lod_tier(activation_tier)

## Returns this actor to the pool and saves any necessary state back to the identity.
func etherealize_to_pool() -> void:
	prepare_for_pool()

func prewarm_runtime() -> void:
	_ensure_core_runtime_initialized()
	_ensure_role_runtime_initialized()

func _ensure_core_runtime_initialized() -> void:
	if _core_runtime_initialized:
		return
	_inject_dependencies()
	_setup_connections()
	_core_runtime_initialized = true

func _ensure_visual_state() -> void:
	if _visual_state_initialized:
		return
	if gf_resource and gf_resource.appearance:
		_apply_gf_appearance()
	else:
		_randomize_gender_and_appearance()
	_visual_state_initialized = true

func _ensure_role_runtime_initialized() -> void:
	if _role_runtime_initialized: return
	if not has_node("DealerShopComponent"):
		var shop_comp := DealerShopComponent.new()
		shop_comp.name = "DealerShopComponent"
		add_child(shop_comp)
		shop_comp.set_process(false)
	if not has_node("DealerDetectionComponent"):
		var detect_comp := DealerDetectionComponent.new()
		detect_comp.name = "DealerDetectionComponent"
		add_child(detect_comp)
		detect_comp.set_physics_process(false)
		detect_comp.visible = false
	if not has_node("PoliceDetectionComponent"):
		var police_detect := PoliceDetectionComponent.new()
		police_detect.name = "PoliceDetectionComponent"
		add_child(police_detect)
		police_detect.set_physics_process(false)
		police_detect.visible = false
	if not has_node("PoliceDebugOverlay"):
		var debug_overlay := PoliceDebugOverlay.new()
		debug_overlay.name = "PoliceDebugOverlay"
		add_child(debug_overlay)
		debug_overlay.visible = false
	if not has_node("GirlfriendComponent"):
		var gf_comp := GirlfriendComponent.new()
		gf_comp.name = "GirlfriendComponent"
		add_child(gf_comp)
		gf_comp.set_process(false)
	_role_runtime_initialized = true

func _apply_role_runtime_state() -> void:
	_disable_all_role_components()
	if gf_resource and gf_resource.appearance:
		behavior_tree = load("res://GAME/resources/ai/girlfriend_bt.tres")
		var gf_comp = get_node_or_null("GirlfriendComponent")
		if gf_comp:
			gf_comp.setup(gf_resource)
			gf_comp.set_process(true)
		_boost_girlfriend_speed()
		if npc_ui:
			npc_ui.update_level(gf_resource.level, -1)
		if gf_request_timer <= 0.0:
			gf_request_timer = randf_range(45.0, 90.0)

	if role == Role.DEALER:
		var tier := _get_effective_dealer_tier()
		dealer_tier = tier
		var shop_comp := get_node_or_null("DealerShopComponent") as DealerShopComponent
		if shop_comp:
			shop_comp.tier_config = tier
			shop_comp.set_process(true)
		if stats:
			stats.max_health = tier.max_health
			if health_component:
				health_component.setup(stats)
		if npc_ui:
			npc_ui.update_level(tier.tier_level, 1)

func _apply_activation_context(role_context: Dictionary) -> void:
		set_path_markers(role_context["path_markers"])

func _disable_all_role_components() -> void:
	var names = ["DealerShopComponent", "DealerDetectionComponent", "PoliceDetectionComponent", "PoliceDebugOverlay", "GirlfriendComponent"]
	for n_name in names:
		var n = get_node_or_null(n_name)
		if n:
			if "visible" in n: n.visible = false
			if n.has_method("set_process"): n.set_process(false)
			if n is Area2D:
				n.set_deferred("monitoring", false)
				n.set_deferred("monitorable", false)

func _cleanup_role_components() -> void:
	# Legacy function, now just hides everything
	_disable_all_role_components()

func _reset_runtime_state_for_pool() -> void:
	_clear_interaction_with_player()
	_reset_girlfriend_request_state()
	if weapon_holder_component:
		weapon_holder_component.equip_weapon(null)
	if blackboard:
		blackboard.set_var(&"was_shot", false)
		blackboard.set_var(&"damage_source_position", Vector2.ZERO)
		blackboard.set_var(&"attacker", null)
		blackboard.set_var(&"is_interacting", false)
		blackboard.set_var(&"is_solicited", false)
		blackboard.set_var(&"target", null)
		blackboard.set_var(&"requested_drug_id", &"")
		blackboard.set_var(&"requested_grams", 0)
		blackboard.set_var(&"offered_payout", 0)
		blackboard.set_var(&"has_line_of_sight", false)
		blackboard.set_var(&"is_searching", false)
		blackboard.set_var(&"last_known_position", Vector2.ZERO)
		blackboard.set_var(&"last_known_velocity", Vector2.ZERO)
		blackboard.set_var(&"heard_gunfire", false)
		blackboard.set_var(&"is_dealer_customer", false)
		blackboard.set_var(&"approach_target", null)
		blackboard.set_var(&"dealer_purchase_target", null)
		blackboard.set_var(&"dealer_purchase_drug_id", &"")
		blackboard.set_var(&"dealer_purchase_grams", 0)
		blackboard.set_var(&"is_front_business_customer", false)
		blackboard.set_var(&"front_business_purchase_target", null)
		blackboard.set_var(&"front_business_level", 0)
		blackboard.set_var(&"path_markers", _path_markers.duplicate())

func _set_detection_component_active(active: bool) -> void:
	var detect_comp: Node = null
	if role == Role.POLICE:
		detect_comp = get_node_or_null("PoliceDetectionComponent")
	elif role == Role.DEALER:
		detect_comp = get_node_or_null("DealerDetectionComponent")
	if detect_comp:
		detect_comp.visible = active
		detect_comp.set_physics_process(active)
		detect_comp.set_deferred("monitoring", active)
		detect_comp.set_deferred("monitorable", active)

	var debug_overlay := get_node_or_null("PoliceDebugOverlay")
	if debug_overlay:
		debug_overlay.visible = active and role == Role.POLICE

func _set_interact_area_active(active: bool) -> void:
	if not interact_area:
		return
	interact_area.visible = false
	interact_area.set_deferred("monitoring", active)
	interact_area.set_deferred("monitorable", active)
	interact_area.collision_layer = INTERACT_COLLISION_LAYER if active else 0
	interact_area.collision_mask = INTERACT_COLLISION_MASK if active else 0

func _set_collisions_active(active: bool) -> void:
	collision_layer = NPC_COLLISION_LAYER if active else 0
	collision_mask = NPC_COLLISION_MASK if active else 0
	var hb := find_child("HurtBox")
	if hb:
		hb.collision_layer = HURTBOX_COLLISION_LAYER if active else 0
		hb.collision_mask = HURTBOX_COLLISION_MASK if active else 0

func _get_effective_dealer_tier() -> DealerTierResource:
	if dealer_tier:
		return dealer_tier
	var tier := DealerTierResource.new()
	var drug = preload("res://GAME/scripts/resources/drug_definition_resource.gd").new()
	drug.id = "weed"
	drug.display_name = "Weed"
	drug.base_price = 10
	tier.allowed_drugs.append(drug)
	return tier

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

func bark(text: String, duration: float = 2.5, force: bool = false, type: String = "generic") -> void:
	if not npc_ui:
		return
		
	if gf_is_requesting and not force:
		return

	var priority = BarkManager.Priority.LOW
	var color = Color.YELLOW # Default NPC dialogue color
	
	match type:
		"gf_request":
			priority = BarkManager.Priority.HIGH
			color = Color(1.0, 0.4, 0.7) # Pink
		"recruitment":
			priority = BarkManager.Priority.HIGH
			color = Color.YELLOW
		"solicitation":
			priority = BarkManager.Priority.URGENT
			color = Color.YELLOW
		"combat":
			priority = BarkManager.Priority.MEDIUM
			color = Color.DARK_RED
		"generic":
			priority = BarkManager.Priority.LOW
			color = Color.YELLOW

	if BarkManager.request_bark(self, priority, force):
		npc_ui.show_dialog_bubble(text, color)
		if _dialog_hide_timer and _dialog_hide_timer.timeout.is_connected(npc_ui.hide_dialog_bubble):
			_dialog_hide_timer.timeout.disconnect(npc_ui.hide_dialog_bubble)
		_dialog_hide_timer = get_tree().create_timer(duration)
		_dialog_hide_timer.timeout.connect(npc_ui.hide_dialog_bubble)

func interrupt_bark():
	if npc_ui:
		npc_ui.hide_dialog_bubble()
		if _dialog_hide_timer:
			_dialog_hide_timer.timeout.disconnect(npc_ui.hide_dialog_bubble)
			_dialog_hide_timer = null

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
	bark(lines.pick_random(), 3.0, false, "combat")

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
	var player = get_tree().get_first_node_in_group("player") as Node2D
	if player and animation_component:
		var dir = global_position.direction_to(player.global_position)
		animation_component.last_direction = dir
		animation_component.update_animation(Vector2.ZERO) # Force idle facing player

	if role == Role.DEALER and has_node("DealerShopComponent"):
		var shop_comp = get_node("DealerShopComponent")
		var tier_num = 1
		if shop_comp.get("tier_config"):
			tier_num = shop_comp.get("tier_config").get("tier_level")
			
		var req_player_level = _get_required_level_for_tier(tier_num)
			
		if player and player.get("progression") and player.get("progression").get("level") < req_player_level:
			bark("you neeed to be (lvl %d)" % req_player_level, 3.0, true)
			_is_interacting = false
			if blackboard: blackboard.set_var(&"is_interacting", false)
			return
			
		if player and player.get("shop_ui"):
			player.get("shop_ui").open_shop(shop_comp, player)
		return

	if gf_is_requesting:
		_handle_girlfriend_money_request(player)
		return

	if is_potential_girlfriend:
		_handle_girlfriend_recruitment(player)
		return

	if blackboard and blackboard.get_var(&"is_solicited", false):
		AudioManager.play_ui_menu()
		_handle_solicited_interaction(player)
		return

	if npc_ui:
		bark("Hey there! Can't talk right now.")

func _handle_solicited_interaction(player: Node2D) -> void:
	if not player:
		return
	var grams = blackboard.get_var(&"requested_grams", 0)
	var payout = blackboard.get_var(&"offered_payout", 0)
	var drug_id: StringName = blackboard.get_var(&"requested_drug_id", &"weed")
	var drug_name := DrugCatalog.get_display_name(drug_id)

	var inv: InventoryComponent = player.get("inventory_component")
	if inv and inv.has_drug(drug_id, grams):
		inv.remove_drug(drug_id, grams)
		var sale_payout: int = int(payout)
		if player.has_method("get_sale_payout_multiplier"):
			sale_payout = roundi(float(payout) * player.get_sale_payout_multiplier())
		NetworkManager.economy.add_dirty(sale_payout)

		# Apply Heat
		var definition := DrugCatalog.get_definition(drug_id)
		var base_heat := definition.base_heat_per_gram if definition else HeatConfig.BASE_HEAT_PER_GRAM
		var risk_multiplier := definition.risk_multiplier if definition else 1.0
		var sale_heat = base_heat * grams * risk_multiplier * HeatConfig.SALE_RISK_MULTIPLIER
		if player.has_method("get_sale_heat_multiplier"):
			sale_heat *= player.get_sale_heat_multiplier()
		if has_node("/root/HeatManager"):
			get_node("/root/HeatManager").add_heat(sale_heat)

		# XP and Indicators
		var sale_xp = int(grams * 25) # Balanced: 25 XP per gram
		if player.has_method("get_sale_xp_multiplier"):
			sale_xp = roundi(float(sale_xp) * player.get_sale_xp_multiplier())
		player.get("progression").add_xp(sale_xp)

		var pui = player.get("player_ui")
		if pui:
			pui.spawn_indicator("money_up", "+$" + str(sale_payout))
			pui.spawn_indicator("product", "-%dg %s" % [grams, drug_name], DrugCatalog.get_product_icon(drug_id, false))
			pui.spawn_indicator("xp", "+" + str(sale_xp) + " XP")

		AudioManager.play_transaction()

		# Gain Reputation in Territory
		var deal_territory: TerritoryArea = get_meta(&"territory") if has_meta(&"territory") else null
		if not deal_territory:
			for node in get_tree().get_nodes_in_group("territories"):
				if node is TerritoryArea and node.get_overlapping_bodies().has(player):
					deal_territory = node
					break
					
		if deal_territory and deal_territory.reputation_component:
			deal_territory.reputation_component.add_reputation(1.0 + (grams * 0.1))
			pui = player.get("player_ui")
			if pui:
				pui.spawn_indicator("money_up", "+REP")

		if npc_ui:
			bark("Thanks man.", 2.5, false, "solicitation")

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
			bark("You don't have enough!", 2.5, false, "solicitation")

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

func _handle_girlfriend_money_request(player: Node2D) -> void:
	if not player: return
	
	if NetworkManager.economy.dirty_money >= gf_request_amount:
		NetworkManager.economy.spend_dirty(gf_request_amount)
		gf_resource.set_relationship(gf_resource.relationship + 10.0)
		gf_is_requesting = false
		gf_request_timer = randf_range(45.0, 90.0)
		
		if player.get("player_ui"):
			var pui = player.player_ui
			pui.spawn_indicator("money_down", "-$" + str(gf_request_amount))
			pui.spawn_indicator("relationship_up", "+10 Relationship")
			
		AudioManager.play_transaction()
		
		var thanks_barks = ["Thanks baby!", "You're the best!", "I love a man with cash.", "You're so sweet!"]
		bark(thanks_barks.pick_random(), 3.0, true, "gf_request")
		
		_clear_interaction_with_player(player)
	else:
		var broke_barks = ["You're broke?!", "Don't play with me.", "I need a real provider.", "Maybe next time then."]
		bark(broke_barks.pick_random(), 3.0, true, "gf_request")
		# She keeps requesting? Or decline? Let's decline it automatically if you can't pay and talk to her.
		_decline_girlfriend_request()

func _handle_girlfriend_recruitment(player: Node2D) -> void:
	if not player: return
	
	var req_player_level = _get_required_level_for_tier(potential_gf_level)
	if player and player.get("progression") and player.get("progression").get("level") < req_player_level:
		var reject_barks = [
			"You're not experienced enough for me.",
			"Come back when you're a bigger deal.",
			"I only roll with top-tier players.",
			"You need to step your game up."
		]
		bark(reject_barks.pick_random() + "\n(Need Lvl %d)" % req_player_level, 3.0, true)
		_is_interacting = false
		if blackboard: blackboard.set_var(&"is_interacting", false)
		return

	var player_barks = [
		"damn you fine lemme get your number",
		"hey beautiful, what's your name?",
		"you're the prettiest girl on this block",
		"wanna come with me?"
	]
	player.show_bark(player_barks.pick_random())

	var gf_barks = [
		"ok cutie",
		"sure, call me later",
		"i like your style",
		"let's go!"
	]
	bark(gf_barks.pick_random(), 2.5, false, "recruitment")
	
	is_potential_girlfriend = false
	_is_interacting = false
	if blackboard:
		blackboard.set_var(&"is_interacting", false)
	
	# Create Resource
	gf_resource = GirlfriendResource.new()
	var names_res: NPCNamesResource = load("res://GAME/scripts/resources/npc_names_resource.gd").new()
	gf_resource.npc_name = names_res.get_random_name()
	
	# Capture appearance
	var app = AppearanceResource.new()
	app.body_texture = %Appearance/Body.texture
	app.hair_texture = %Appearance/Hair.texture
	app.outfit_texture = %Appearance/Outfit.texture
	
	var backpack = %Appearance.get_node_or_null("Backpack")
	if backpack and backpack.visible: app.backpack_texture = backpack.texture
	var beard = %Appearance.get_node_or_null("Beard")
	if beard and beard.visible: app.beard_texture = beard.texture
	var mustache = %Appearance.get_node_or_null("Mustache")
	if mustache and mustache.visible: app.mustache_texture = mustache.texture
	var glasses = %Appearance.get_node_or_null("Glasses")
	if glasses and glasses.visible: app.glasses_texture = glasses.texture
	var hat = %Appearance.get_node_or_null("Hat")
	if hat and hat.visible: app.hat_texture = hat.texture
	
	gf_resource.appearance = app
	gf_resource.stats = stats.duplicate()
	gf_resource.is_following = true
	
	gf_resource.level = potential_gf_level
	
	# Setup Girlfriend Component (now pre-allocated)
	var gf_comp = get_node_or_null("GirlfriendComponent")
	if gf_comp:
		gf_comp.setup(gf_resource)
		gf_comp.set_process(true)
		if "visible" in gf_comp: gf_comp.visible = true
	
	# Switch to Girlfriend BT
	behavior_tree = load("res://GAME/resources/ai/girlfriend_bt.tres")
	_setup_bt()
	
	if player and player.get("inventory_component"):
		player.get("inventory_component").add_girlfriend(gf_resource)
	add_to_group("girlfriend")
	_boost_girlfriend_speed()
	
	if npc_ui:
		npc_ui.update_level(gf_resource.level, -1)
	
	_update_ui_icon()
	
	# Start the request timer
	gf_request_timer = randf_range(45.0, 90.0)

func _on_gf_reset_timeout() -> void:
	# Check if player is NOT in range anymore
	var player_in_range = false
	if interact_area:
		for body in interact_area.get_overlapping_bodies():
			if body.is_in_group("player"):
				player_in_range = true
				break
	
	if not player_in_range and is_potential_girlfriend:
		is_potential_girlfriend = false
		_update_ui_icon()

func _boost_girlfriend_speed() -> void:
	if not stats: return
	var player = get_tree().get_first_node_in_group("player")
	if player and player.stats:
		# Tiny bit slower: 95% of player's base move speed 
		# (Player is 350, GF will be ~332. Civilians are 200)
		var target_speed = player.stats.move_speed * 0.95
		stats.move_speed = target_speed
		if nav_agent:
			nav_agent.max_speed = target_speed
	
func dismiss(is_breakup: bool = false) -> void:
	is_potential_girlfriend = false
	_reset_girlfriend_request_state()
	_clear_interaction_with_player()
	_is_interacting = false
	if blackboard:
		blackboard.set_var(&"is_interacting", false)
	if gf_resource:
		gf_resource.is_following = false
	
	if is_breakup:
		var player = get_tree().get_first_node_in_group("player")
		if player and player.inventory_component:
			player.inventory_component.remove_girlfriend(gf_resource)
	
	# Walk away and fade
	var walk_dir = Vector2.RIGHT.rotated(randf() * TAU)
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 0.0, 2.0)
	# Simple walk logic
	tween.tween_method(func(v): velocity = v; move_and_slide(), walk_dir * stats.move_speed, Vector2.ZERO, 2.0)
	tween.set_parallel(false)
	tween.tween_callback(queue_free)

func call_back(target_pos: Vector2) -> void:
	if gf_resource:
		gf_resource.is_following = true
	_reset_girlfriend_request_state()
	gf_request_timer = randf_range(45.0, 90.0)
	
	modulate.a = 0.0
	# Spawn just outside current stop range
	global_position = target_pos + Vector2.RIGHT.rotated(randf() * TAU) * 400.0
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 1.0)
	_boost_girlfriend_speed()


func _reset_dealer_customer_state() -> void:
	if not blackboard:
		return
	blackboard.set_var(&"is_dealer_customer", false)
	blackboard.set_var(&"approach_target", null)
	blackboard.set_var(&"dealer_purchase_target", null)
	blackboard.set_var(&"dealer_purchase_drug_id", &"")
	blackboard.set_var(&"dealer_purchase_grams", 0)
	_update_ui_icon()

func _reset_front_business_customer_state() -> void:
	if not blackboard:
		return
	blackboard.set_var(&"is_front_business_customer", false)
	blackboard.set_var(&"approach_target", null)
	blackboard.set_var(&"front_business_purchase_target", null)
	blackboard.set_var(&"front_business_level", 0)
	_update_ui_icon()


func _evaluate_girlfriend_status() -> void:
	if role != Role.CUSTOMER or gender != Gender.FEMALE or gf_resource != null or is_potential_girlfriend:
		return
		
	# Don't solicit customers who are already in a transaction
	if blackboard and blackboard.get_var(&"is_solicited", false):
		return
	if blackboard and blackboard.has_var(&"is_dealer_customer") and blackboard.get_var(&"is_dealer_customer", false):
		return
	
	if randf() < 0.2: # 20% chance
		is_potential_girlfriend = true
		potential_gf_level = randi_range(1, 4)
		_update_ui_icon()
		bark("Hey cutie! (Press E)", 3.0, false, "recruitment")

func _on_interact_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("register_interactable"):
		_evaluate_girlfriend_status()
		# Only allow interaction if we are a dealer OR a solicited customer OR a potential GF OR requesting money
		var is_dealer_customer: bool = blackboard and blackboard.has_var(&"is_dealer_customer") and blackboard.get_var(&"is_dealer_customer", false)
		var solicited_enter: bool = blackboard and blackboard.get_var(&"is_solicited", false) and not is_dealer_customer
		var can_interact = (role == Role.DEALER) or solicited_enter or is_potential_girlfriend or gf_is_requesting
		if can_interact:
			body.register_interactable(self)
			if role == Role.DEALER:
				bark_dealer_feedback("approach")
			elif npc_ui and not is_potential_girlfriend and not gf_is_requesting:
				npc_ui.hide_dialog_bubble()
			if body.get("player_ui"):
				body.player_ui.hide_dialog_bubble()

func _on_interact_area_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		# Always clear interaction state when player walks away
		if is_potential_girlfriend:
			_gf_reset_timer = get_tree().create_timer(5.0)
			_gf_reset_timer.timeout.connect(_on_gf_reset_timeout)
			
		if body.has_method("unregister_interactable"):
			body.unregister_interactable(self)
			
		if not gf_is_requesting:
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
	_is_dead = true
	if has_node("/root/HeatManager"):
		get_node("/root/HeatManager").on_kill(role)
	
	if gf_resource:
		_reset_girlfriend_request_state()
		_clear_interaction_with_player()
		var player = get_tree().get_first_node_in_group("player")
		if player and player.get("inventory_component"):
			player.inventory_component.remove_girlfriend(gf_resource)
	
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
	_is_pooled = false
	if bt_player:
		bt_player.active = false
	
	if animation_component:
		animation_component.update_animation(Vector2.ZERO) # Force idle
		if animation_component.animation_player:
			animation_component.animation_player.stop()
	
	# Hide Detection Rings
	_set_detection_component_active(false)
	
	# Disable collisions
	_set_interact_area_active(false)
	_set_collisions_active(false)
	
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

func _get_required_level_for_tier(tier: int) -> int:
	match tier:
		1: return 1
		2: return 20
		3: return 40
		4: return 100
		_: return 1


## ─── NPC LOD Tier System ────────────────────────────────────────────────────
## Called every frame by NpcLodManager based on distance from the player.
## Tier 0 = full fidelity  (within ~700 px)
## Tier 1 = reduced cost   (700–1500 px) — avoidance disabled, AI still ticks
## Tier 2 = dormant        (>1500 px)    — physics + AI fully suspended
func set_lod_tier(tier: int) -> void:
	# Never LOD dead NPCs (death tween handles their lifecycle).
	if _is_dead:
		return
	# Never freeze girlfriends — they must always follow the player.
	if gf_resource and gf_resource.is_following:
		if _lod_tier != 0:
			_apply_lod_tier(0)
		return
	if _lod_tier == tier:
		return
	_apply_lod_tier(tier)


func _apply_lod_tier(tier: int) -> void:
	if _is_pooled:
		return
	_lod_tier = tier
	match tier:
		0: # FULL
			set_physics_process(true)
			visible = true
			if bt_player:
				bt_player.set_process_mode(PROCESS_MODE_INHERIT)
			if nav_agent:
				nav_agent.avoidance_enabled = true
			if npc_ui:
				npc_ui.show()
			_set_detection_component_active(true)
		1: # REDUCED (AI runs, but no avoidance physics)
			set_physics_process(true)
			visible = true
			if bt_player:
				bt_player.set_process_mode(PROCESS_MODE_INHERIT)
			if nav_agent:
				nav_agent.avoidance_enabled = false
			if npc_ui:
				npc_ui.show()
			_set_detection_component_active(true)
		2: # DORMANT
			set_physics_process(false)
			visible = false
			if nav_agent:
				nav_agent.avoidance_enabled = false
			if bt_player:
				bt_player.set_process_mode(PROCESS_MODE_DISABLED)
			if npc_ui:
				npc_ui.hide()
			_set_detection_component_active(false)

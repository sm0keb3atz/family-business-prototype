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



# --- State ---
var spawn_position: Vector2 = Vector2.ZERO
var blackboard: Blackboard
var _hitstun_duration: float = 0.0
var _is_interacting: bool = false


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
		var speed_variation: float = randf_range(0.7, 1.3)
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

func _setup_connections() -> void:
	if health_component:
		health_component.health_changed.connect(_on_health_changed)
		health_component.died.connect(_on_died)
	if nav_agent:
		nav_agent.velocity_computed.connect(_on_velocity_computed)
	if interact_area:
		interact_area.body_entered.connect(_on_interact_area_body_entered)
		interact_area.body_exited.connect(_on_interact_area_body_exited)


func _physics_process(delta: float) -> void:
	if _hitstun_duration > 0:
		_hitstun_duration -= delta

func _on_velocity_computed(safe_velocity: Vector2) -> void:
	if movement_component:
		if _hitstun_duration > 0 or _is_interacting:
			movement_component.move_velocity(Vector2.ZERO)
			return
		movement_component.move_velocity(safe_velocity)
		if animation_component:
			animation_component.update_animation(safe_velocity)


func _setup_bt() -> void:
	if bt_player:
		if behavior_tree:
			bt_player.behavior_tree = behavior_tree
		
		blackboard = bt_player.get_blackboard()
		if blackboard:
			blackboard.set_var(&"was_shot", false)
			blackboard.set_var(&"damage_source_position", Vector2.ZERO)
			blackboard.set_var(&"is_interacting", false)

# --- Damage Interface ---
# Called by BulletBase when a projectile hits this body.
func take_damage(amount: int, source_position: Vector2 = Vector2.ZERO, hit_direction: Vector2 = Vector2.ZERO) -> void:
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
		if source_position != Vector2.ZERO:
			blackboard.set_var(&"damage_source_position", source_position)


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

	if npc_ui:
		npc_ui.show_dialog_bubble("Hey there! Can't talk right now.")

func _on_interact_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("interact"):
		body.current_interactable = self

func _on_interact_area_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		# Always clear interaction state when player walks away
		if body.get("current_interactable") == self:
			body.current_interactable = null
		_is_interacting = false
		if blackboard:
			blackboard.set_var(&"is_interacting", false)
		if npc_ui:
			npc_ui.hide_dialog_bubble()

# --- Callbacks ---
func _on_health_changed(current: int, maximum: int) -> void:
	if npc_ui:
		npc_ui.update_health(float(current), float(maximum))

func _on_died() -> void:
	queue_free()

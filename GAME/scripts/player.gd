extends CharacterBody2D
class_name Player

# Resources
@export_group("Data")
@export var stats: CharacterStatsResource
@export var progression: PlayerProgressionResource
@export var appearance: AppearanceResource

# Components
@onready var movement_component: MovementComponent = %MovementComponent
@onready var health_component: HealthComponent = %HealthComponent
@onready var input_component: InputComponent = %InputComponent
@onready var faction_component: FactionComponent = %FactionComponent
@onready var weapon_holder_component: WeaponHolderComponent = %WeaponHolderComponent
@onready var animation_component: AnimationComponent = %AnimationComponent
@onready var blood_effect_component: BloodEffectComponent = %BloodEffectComponent
@onready var footstep_component: FootstepComponent = %FootstepComponent
@onready var state_machine: StateMachine = %StateMachine

# Visuals
@onready var appearance_nodes: Node2D = %Appearance

var current_interactable: Node2D = null

var available_weapons: Array = [
	null, # Unarmed
	preload("res://GAME/scenes/Weapons/glock.tscn")
]
var current_weapon_index: int = 1
func _ready() -> void:
	add_to_group("player")
	z_index = 1
	_inject_dependencies()
	_setup_connections()
	_apply_appearance()
	_apply_appearance()
	
	_update_weapon()

func _inject_dependencies() -> void:
	if movement_component:
		movement_component.parent_body = self
		movement_component.setup(stats)
	
	if health_component:
		health_component.setup(stats)
	
	if animation_component:
		animation_component.animation_player = %AnimationPlayer
		animation_component.flip_root = %Appearance
	
	if faction_component:
		faction_component.setup(stats)

	if blood_effect_component:
		blood_effect_component.hurt_box = %HurtBox

	if footstep_component:
		footstep_component.animation_player = %AnimationPlayer
		footstep_component.body_sprite = appearance_nodes.get_node("Body")
		footstep_component.dust_sprite = $Footsteps
		footstep_component.footstep_audio = %FootstepAudio

func _setup_connections() -> void:
	if input_component:
		# InputComponent now primarily emits for combat/utility
		if weapon_holder_component:
			input_component.fire_requested.connect(weapon_holder_component.fire)
		
		input_component.interact_requested.connect(interact)
		input_component.weapon_next_requested.connect(_on_weapon_next)
		input_component.weapon_prev_requested.connect(_on_weapon_prev)
		
		# Movement/Animation is handled by the StateMachine which reads Input.get_vector directly
		# or could listen to signals if we wanted more decoupling. 
		# For this foundation, States read global input for simplicity/responsiveness.

func _apply_appearance() -> void:
	if not appearance or not appearance_nodes:
		return
	
	var nodes_map = {
		"Body": appearance.body_texture,
		"Outfit": appearance.outfit_texture,
		"Hair": appearance.hair_texture,
		"Backpack": appearance.backpack_texture,
		"Beard": appearance.beard_texture,
		"Mustache": appearance.mustache_texture,
		"Glasses": appearance.glasses_texture,
		"Hat": appearance.hat_texture
	}
	
	for node_name in nodes_map:
		var node = appearance_nodes.get_node_or_null(node_name)
		if node is Sprite2D and nodes_map[node_name]:
			node.texture = nodes_map[node_name]
			node.visible = true

func interact() -> void:
	print("Player: interact() called. current_interactable: ", current_interactable.name if current_interactable else "NONE")
	if current_interactable and current_interactable.has_method("interact"):
		current_interactable.interact()

# --- Damage Interface ---
func take_damage(amount: int, source_position: Vector2 = Vector2.ZERO, hit_direction: Vector2 = Vector2.ZERO) -> void:
	if health_component:
		health_component.take_damage(amount)
	
	if source_position != Vector2.ZERO and blood_effect_component:
		blood_effect_component.spawn_blood(source_position, hit_direction)

# --- Weapon Selection ---
func _on_weapon_next() -> void:
	current_weapon_index = (current_weapon_index + 1) % available_weapons.size()
	_update_weapon()

func _on_weapon_prev() -> void:
	current_weapon_index = (current_weapon_index - 1 + available_weapons.size()) % available_weapons.size()
	_update_weapon()

func _update_weapon() -> void:
	if weapon_holder_component:
		var weapon_scene = available_weapons[current_weapon_index]
		weapon_holder_component.equip_weapon(weapon_scene)

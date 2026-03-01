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
@onready var arrest_component: ArrestComponent = %ArrestComponent

# Visuals
@onready var appearance_nodes: Node2D = %Appearance
@onready var player_ui: NpcUI = %PlayerUI

var current_interactable: Node2D = null
var _available_interactables: Array[Node2D] = []
var _is_interacting: bool = false

var inventory_component: InventoryComponent
var inventory_ui: InventoryUI
var shop_ui: ShopUI
var solicitation_component: SolicitationComponent

@export var solicitation_config: SolicitationConfigResource

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
	_setup_inventory()
	
	_update_weapon()
	
	if arrest_component:
		arrest_component.progress_changed.connect(_on_arrest_progress_changed)

func _setup_inventory() -> void:
	inventory_component = InventoryComponent.new()
	inventory_component.name = "InventoryComponent"
	add_child(inventory_component)
	
	var ui_scene = preload("res://GAME/scenes/ui/inventory_ui.tscn")
	inventory_ui = ui_scene.instantiate()
	get_tree().root.call_deferred("add_child", inventory_ui)
	inventory_ui.setup(inventory_component)
	
	var shop_ui_scene = preload("res://GAME/scenes/ui/shop_ui.tscn")
	shop_ui = shop_ui_scene.instantiate()
	get_tree().root.call_deferred("add_child", shop_ui)
	
	var hud_scene = preload("res://GAME/scenes/ui/hud.tscn")
	var hud = hud_scene.instantiate()
	get_tree().root.call_deferred("add_child", hud)
	
	solicitation_component = SolicitationComponent.new()

	solicitation_component.name = "SolicitationComponent"
	if not solicitation_config:
		solicitation_config = SolicitationConfigResource.new()
	solicitation_component.config = solicitation_config
	add_child(solicitation_component)

func _inject_dependencies() -> void:
	if movement_component:
		movement_component.parent_body = self
		movement_component.setup(stats)
	
	if health_component:
		health_component.setup(stats)
		health_component.damage_taken.connect(_on_damage_taken)
	
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

func show_bark(text: String) -> void:
	if player_ui:
		player_ui.show_dialog_bubble(text)
		# Hide bark after 2.5 seconds
		get_tree().create_timer(2.5).timeout.connect(player_ui.hide_dialog_bubble)

func register_interactable(node: Node2D) -> void:
	if not _available_interactables.has(node):
		_available_interactables.append(node)

func unregister_interactable(node: Node2D) -> void:
	_available_interactables.erase(node)
	if current_interactable == node:
		current_interactable = null
		_is_interacting = false

func interact() -> void:
	if _is_interacting:
		print("Player: Already interacting, ignoring request.")
		return

	# Always pick the closest one when several are in range
	if not _available_interactables.is_empty():
		var closest_node = null
		var min_dist = 1e10
		for node in _available_interactables:
			if not is_instance_valid(node): continue
			var d = global_position.distance_to(node.global_position)
			if d < min_dist:
				min_dist = d
				closest_node = node
		current_interactable = closest_node

	print("Player: interact() called. current_interactable: ", current_interactable.name if current_interactable else "NONE")
	if current_interactable and current_interactable.has_method("interact"):
		_is_interacting = true
		current_interactable.interact()

# --- Damage Interface ---
func take_damage(amount: int, source_position: Vector2 = Vector2.ZERO, hit_direction: Vector2 = Vector2.ZERO) -> void:
	if health_component:
		health_component.take_damage(amount)
	
	if source_position != Vector2.ZERO and blood_effect_component:
		blood_effect_component.spawn_blood(source_position, hit_direction)

# --- Weapon Selection ---
func _on_damage_taken(amount: int) -> void:
	if player_ui:
		player_ui.spawn_indicator("damage", str(amount))

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

func _on_arrest_progress_changed(value: float) -> void:
	if player_ui:
		player_ui.update_arrest_progress(value)

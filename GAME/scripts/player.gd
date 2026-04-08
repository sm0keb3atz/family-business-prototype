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

signal weapon_changed(weapon: WeaponBase)

# Visuals
@onready var appearance_nodes: Node2D = %Appearance
@onready var player_ui: NpcUI = %PlayerUI

var current_interactable: Node2D = null
var _available_interactables: Array[Node2D] = []
var _is_interacting: bool = false

var inventory_component: InventoryComponent
var inventory_ui: InventoryUI
var shop_ui: ShopUI
var property_ui: PropertyUI
var atm_ui: ATMUI
var gun_shop_ui: GunShopUI
var solicitation_component: SolicitationComponent
var _base_stats: CharacterStatsResource
var weapon_state: PlayerWeaponState

@export var solicitation_config: SolicitationConfigResource

var glock_weapon_scene: PackedScene = preload("res://GAME/scenes/Weapons/glock.tscn")
var glock_weapon_data_by_level := {
	1: preload("res://GAME/resources/weapons/glock_lv1.tres"),
	2: preload("res://GAME/resources/weapons/glock_lv2.tres"),
	3: preload("res://GAME/resources/weapons/glock_lv3.tres"),
	4: preload("res://GAME/resources/weapons/glock_lv4.tres")
}

func _ready() -> void:
	add_to_group("player")
	z_index = 1
	if stats:
		stats = stats.duplicate(true)
		_base_stats = stats.duplicate(true)
	_inject_dependencies()
	_setup_connections()
	_apply_appearance()
	_setup_inventory()
	_apply_skill_bonuses()
	
	_update_weapon()
	
	if arrest_component:
		arrest_component.progress_changed.connect(_on_arrest_progress_changed)
	if progression and not progression.skills_changed.is_connected(_on_skill_changed):
		progression.skills_changed.connect(_on_skill_changed)

func _setup_inventory() -> void:
	inventory_component = InventoryComponent.new()
	inventory_component.name = "InventoryComponent"
	add_child(inventory_component)

	weapon_state = PlayerWeaponState.new()
	weapon_state.owned_glock_level = 0
	if not weapon_state.owned_glock_level_changed.is_connected(_on_owned_glock_level_changed):
		weapon_state.owned_glock_level_changed.connect(_on_owned_glock_level_changed)
	if not weapon_state.equipped_state_changed.is_connected(_on_equipped_state_changed):
		weapon_state.equipped_state_changed.connect(_on_equipped_state_changed)
	
	var ui_scene = preload("res://GAME/scenes/ui/inventory_ui.tscn")
	inventory_ui = ui_scene.instantiate()
	get_tree().root.call_deferred("add_child", inventory_ui)
	inventory_ui.setup(inventory_component, self)
	
	var shop_ui_scene = preload("res://GAME/scenes/ui/shop_ui.tscn")
	shop_ui = shop_ui_scene.instantiate()
	get_tree().root.call_deferred("add_child", shop_ui)
	
	var property_ui_scene = preload("res://GAME/scenes/ui/property_ui.tscn")
	property_ui = property_ui_scene.instantiate()
	get_tree().root.call_deferred("add_child", property_ui)

	var atm_ui_scene = preload("res://GAME/scenes/ui/atm_ui.tscn")
	atm_ui = atm_ui_scene.instantiate()
	get_tree().root.call_deferred("add_child", atm_ui)

	var gun_shop_ui_scene = preload("res://GAME/scenes/ui/gun_shop_ui.tscn")
	gun_shop_ui = gun_shop_ui_scene.instantiate()
	get_tree().root.call_deferred("add_child", gun_shop_ui)

	var hud_scene = preload("res://GAME/scenes/ui/hud.tscn")
	var hud = hud_scene.instantiate()
	get_tree().root.call_deferred("add_child", hud)

	var debug_console_scene = preload("res://GAME/scenes/ui/debug_console.tscn")
	var debug_console = debug_console_scene.instantiate()
	get_tree().root.call_deferred("add_child", debug_console)
	
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
		health_component.died.connect(_on_died)
	
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
		footstep_component.footstep_audio = %FootstepAudio
		footstep_component.dust_sprite = $Footsteps
	
	# Safety clear for interaction state on scene jumps
	_is_interacting = false
	current_interactable = null
	call_deferred("refresh_interactables")

func _setup_connections() -> void:
	if input_component:
		# InputComponent now primarily emits for combat/utility
		if weapon_holder_component:
			input_component.fire_requested.connect(weapon_holder_component.fire)
		
		input_component.interact_requested.connect(interact)
		input_component.weapon_next_requested.connect(_on_weapon_next)
		input_component.weapon_prev_requested.connect(_on_weapon_prev)
		input_component.reload_requested.connect(weapon_holder_component.reload)
		
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

func show_bark(text: String, type: String = "generic") -> void:
	if player_ui:
		var color = Color.YELLOW
		var priority = BarkManager.Priority.LOW
		
		match type:
			"recruitment":
				color = Color.YELLOW
				priority = BarkManager.Priority.HIGH
			"solicitation":
				color = Color.YELLOW
				priority = BarkManager.Priority.URGENT
			"generic":
				color = Color.YELLOW
				priority = BarkManager.Priority.LOW
				
		if BarkManager.request_bark(self, priority, false):
			player_ui.show_dialog_bubble(text, color)
			# Hide bark after 2.5 seconds
			get_tree().create_timer(2.5).timeout.connect(player_ui.hide_dialog_bubble)

func interrupt_bark():
	if player_ui:
		player_ui.hide_dialog_bubble()

func register_interactable(node: Node2D) -> void:
	if not _available_interactables.has(node):
		_available_interactables.append(node)

func unregister_interactable(node: Node2D) -> void:
	_available_interactables.erase(node)
	if current_interactable == node:
		current_interactable = null
		_is_interacting = false

func refresh_interactables() -> void:
	_available_interactables.clear()
	# Search for any areas the player is currently overlapping that are in the interact group
	# This handles the case where the player spawns inside a trigger
	for area in get_tree().get_nodes_in_group("door_trigger"):
		if area is Area2D and area.overlaps_body(self):
			register_interactable(area)
	# Also check generic interactables
	for area in get_tree().get_nodes_in_group("interact_area"):
		if area is Area2D and area.overlaps_body(self):
			register_interactable(area)

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

	var interactable_name: String = "NONE"
	if current_interactable:
		interactable_name = current_interactable.name
	print("Player: interact() called. current_interactable: ", interactable_name)
	if current_interactable and current_interactable.has_method("interact"):
		_is_interacting = true
		current_interactable.interact()

# --- Damage Interface ---
func take_damage(amount: int, source_position: Vector2 = Vector2.ZERO, hit_direction: Vector2 = Vector2.ZERO, shooter: Node2D = null) -> void:
	var final_amount := amount
	if shooter and shooter.is_in_group("npc"):
		final_amount = max(1, roundi(float(amount) * get_incoming_damage_multiplier()))
	if health_component:
		health_component.take_damage(final_amount)
	
	if source_position != Vector2.ZERO and blood_effect_component:
		blood_effect_component.spawn_blood(source_position, hit_direction)

# --- Weapon Selection ---
func _on_damage_taken(amount: int) -> void:
	if player_ui:
		player_ui.spawn_indicator("damage", str(amount))

func _on_weapon_next() -> void:
	if not weapon_state or weapon_state.owned_glock_level <= 0:
		return
	weapon_state.is_equipped = !weapon_state.is_equipped
	_update_weapon()

func _on_weapon_prev() -> void:
	if not weapon_state or weapon_state.owned_glock_level <= 0:
		return
	weapon_state.is_equipped = !weapon_state.is_equipped
	_update_weapon()

func _update_weapon() -> void:
	if weapon_holder_component:
		var owned_level: int = get_owned_glock_level()
		if owned_level <= 0 or not weapon_state.is_equipped:
			weapon_holder_component.equip_weapon(null, null)
		else:
			var weapon_data: WeaponDataResource = glock_weapon_data_by_level.get(owned_level, null)
			weapon_holder_component.equip_weapon(glock_weapon_scene, weapon_data)
		weapon_changed.emit(weapon_holder_component.current_weapon)

func _on_equipped_state_changed(_is_equipped: bool) -> void:
	_update_weapon()

func get_owned_glock_level() -> int:
	if not weapon_state:
		return 0
	return weapon_state.owned_glock_level

func has_owned_glock() -> bool:
	return get_owned_glock_level() > 0

func get_glock_purchase_cost(level: int) -> int:
	match clampi(level, 1, 4):
		1:
			return 2500
		2:
			return 4500
		3:
			return 7000
		4:
			return 9500
		_:
			return 0

func can_purchase_or_upgrade_glock(level: int) -> bool:
	level = clampi(level, 1, 4)
	var owned_level: int = get_owned_glock_level()
	if owned_level <= 0:
		return level == 1
	return level == owned_level + 1

func purchase_or_upgrade_glock(level: int) -> bool:
	level = clampi(level, 1, 4)
	if not can_purchase_or_upgrade_glock(level):
		return false
	var cost: int = get_glock_purchase_cost(level)
	if cost <= 0 or not NetworkManager.economy.spend_clean(cost):
		return false
	weapon_state.owned_glock_level = level
	return true

func _on_owned_glock_level_changed(_new_level: int) -> void:
	_update_weapon()

func _on_arrest_progress_changed(value: float) -> void:
	if player_ui:
		player_ui.update_arrest_progress(value)

func _on_died() -> void:
	# Disable processing and input
	set_physics_process(false)
	set_process(false)
	velocity = Vector2.ZERO
	if state_machine:
		state_machine.set_process(false)
		state_machine.set_physics_process(false)
	
	if input_component:
		input_component.set_process(false)
		input_component.set_process_unhandled_input(false)
		# Reset aiming state
		input_component._is_aiming_last_state = false
	
	if weapon_holder_component:
		weapon_holder_component.set_process(false)
		# Force stop aiming
		weapon_holder_component._on_aim_state_changed(false)
	
	if animation_component:
		animation_component.update_animation(Vector2.ZERO)
		if animation_component.animation_player:
			animation_component.animation_player.stop()
	
	# Disable collisions safely
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	var hb = find_child("HurtBox")
	if hb:
		hb.set_deferred("collision_layer", 0)
		hb.set_deferred("collision_mask", 0)
	
	# Blood Pool
	if blood_effect_component:
		blood_effect_component.spawn_blood_pool()
	
	# Death Animation (Rotate)
	var death_tween = create_tween()
	var target_rotation = deg_to_rad(randf_range(75.0, 85.0))
	if animation_component and animation_component.last_direction.x < 0:
		target_rotation = -target_rotation
	
	death_tween.tween_property(self, "rotation", target_rotation, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	# Call MapManager for cutscene
	var mm = get_tree().get_first_node_in_group("map_manager")
	if mm:
		mm.trigger_death_cutscene(self)

func respawn(spawn_pos: Vector2) -> void:
	global_position = spawn_pos
	rotation = 0
	modulate.a = 1.0
	
	# Re-enable processing
	set_physics_process(true)
	set_process(true)
	
	if health_component:
		health_component.is_dead = false
		health_component.current_health = stats.max_health
		health_component.health_changed.emit(health_component.current_health, stats.max_health)
		
	if input_component:
		input_component.set_process(true)
		input_component.set_process_unhandled_input(true)
		
	if weapon_holder_component:
		weapon_holder_component.set_process(true)
		
	if state_machine:
		state_machine.set_process(true)
		state_machine.set_physics_process(true)
		state_machine.transition_to("Idle")
	
	if arrest_component:
		arrest_component.reset_for_respawn()
	
	# Re-sync aiming state if they were holding it through death (or just to be safe)
	if weapon_holder_component:
		weapon_holder_component._on_aim_state_changed(Input.is_action_pressed("aim"))
	
	# Restore collisions (Assuming Layer 2 for Player per standard NPC pattern)
	set_deferred("collision_layer", 2)
	set_deferred("collision_mask", 1)
	var hb = find_child("HurtBox")
	if hb:
		hb.set_deferred("collision_layer", 4) # Standard HurtBox layer
		hb.set_deferred("collision_mask", 0)
	
	print("Player: Respawned at ", spawn_pos)

func _on_skill_changed(_skill_id: StringName, _new_level: int) -> void:
	_apply_skill_bonuses()

func _apply_skill_bonuses() -> void:
	if not stats or not _base_stats:
		return
	var previous_max_health := stats.max_health
	stats.max_health = _base_stats.max_health
	stats.health_regen = _base_stats.health_regen
	stats.move_speed = _base_stats.move_speed
	stats.sprint_speed = _base_stats.sprint_speed
	stats.defense = _base_stats.defense

	var strength_level := progression.get_skill_level(PlayerSkills.STRENGTH) if progression else 0
	var strength_multiplier := PlayerSkills.get_strength_multiplier(strength_level)
	stats.max_health = roundi(float(_base_stats.max_health) * strength_multiplier)
	stats.health_regen = _base_stats.health_regen * strength_multiplier

	var combat_level := progression.get_skill_level(PlayerSkills.COMBAT) if progression else 0
	stats.sprint_speed = _base_stats.sprint_speed * PlayerSkills.get_sprint_multiplier(combat_level)

	if health_component:
		if previous_max_health <= 0:
			health_component.setup(stats)
		else:
			var health_ratio := float(health_component.current_health) / float(previous_max_health)
			health_component.stats = stats
			var minimum_health := 0 if health_component.current_health <= 0 else 1
			health_component.current_health = clampi(roundi(stats.max_health * health_ratio), minimum_health, stats.max_health)
			health_component.health_changed.emit(health_component.current_health, stats.max_health)

func get_outgoing_damage_multiplier() -> float:
	if not progression:
		return 1.0
	return PlayerSkills.get_damage_multiplier(progression.get_skill_level(PlayerSkills.COMBAT))

func get_reload_time_multiplier() -> float:
	if not progression:
		return 1.0
	return PlayerSkills.get_reload_time_multiplier(progression.get_skill_level(PlayerSkills.COMBAT))

func get_sale_payout_multiplier() -> float:
	if not progression:
		return 1.0
	return PlayerSkills.get_sales_multiplier(progression.get_skill_level(PlayerSkills.SALES))

func get_sale_xp_multiplier() -> float:
	if not progression:
		return 1.0
	return PlayerSkills.get_sales_multiplier(progression.get_skill_level(PlayerSkills.SALES))

func get_sale_heat_multiplier() -> float:
	if not progression:
		return 1.0
	return PlayerSkills.get_sale_heat_multiplier(progression.get_skill_level(PlayerSkills.SALES))

func ignores_customer_follow_heat() -> bool:
	if not progression:
		return false
	return PlayerSkills.ignores_customer_follow_heat(progression.get_skill_level(PlayerSkills.SALES))

func get_dealer_price_multiplier() -> float:
	if not progression:
		return 1.0
	return PlayerSkills.get_social_price_multiplier(progression.get_skill_level(PlayerSkills.SOCIAL))

func get_solicitation_chance_multiplier() -> float:
	if not progression:
		return 1.0
	return PlayerSkills.get_solicitation_multiplier(progression.get_skill_level(PlayerSkills.SOCIAL))

func get_incoming_damage_multiplier() -> float:
	if not progression:
		return 1.0
	return PlayerSkills.get_incoming_damage_multiplier(progression.get_skill_level(PlayerSkills.STRENGTH))

extends CharacterBody2D
class_name NPC

# --- Resources ---
@export_group("Data")
@export var stats: CharacterStatsResource
@export var debug_path: bool = true

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
	add_to_group("npc")
	spawn_position = global_position
	z_index = 1
	_inject_dependencies()
	_setup_connections()
	_setup_bt()

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
		nav_agent.max_speed = stats.move_speed

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

	if debug_path:
		queue_redraw()

func _on_velocity_computed(safe_velocity: Vector2) -> void:
	if movement_component:
		# If in hitstun or interacting, don't move
		if _hitstun_duration > 0 or _is_interacting:
			movement_component.move_velocity(Vector2.ZERO)
			return

		# Move with the safe velocity calculated by avoidance
		movement_component.move_velocity(safe_velocity)

		
		# Update animation based on actual movement
		if animation_component:
			animation_component.update_animation(safe_velocity)

func _draw() -> void:
	if debug_path and nav_agent:
		var path = nav_agent.get_current_navigation_path()
		if path.size() > 1:
			var local_path = []
			for point in path:
				local_path.append(to_local(point))
			draw_polyline(local_path, Color.RED, 2.0)

func _setup_bt() -> void:
	if bt_player:
		blackboard = bt_player.get_blackboard()
		if blackboard:
			blackboard.set_var(&"was_shot", false)
			blackboard.set_var(&"damage_source_position", Vector2.ZERO)

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
		if body.get("current_interactable") == self:
			body.current_interactable = null
			_is_interacting = false
			if npc_ui:
				npc_ui.hide_dialog_bubble()

# --- Callbacks ---
func _on_health_changed(current: int, maximum: int) -> void:
	if npc_ui:
		npc_ui.update_health(float(current), float(maximum))

func _on_died() -> void:
	queue_free()

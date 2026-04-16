extends Node
class_name WeaponHolderComponent

@export var weapon_parent: Node2D
var current_weapon: Node2D

func _ready() -> void:
	if not weapon_parent and owner.has_node("%WeaponPivot"):
		weapon_parent = owner.get_node("%WeaponPivot")

func _process(_delta: float) -> void:
	_handle_rotation()

func _handle_rotation() -> void:
	if not weapon_parent:
		return
		
	var target_pos: Vector2
	if owner.is_in_group("player"):
		target_pos = weapon_parent.get_global_mouse_position()
	elif owner.has_method("get_aggro_target") and owner.get_aggro_target():
		target_pos = owner.get_aggro_target().global_position
	else:
		# Default to looking forward/current rotation if no clear target
		return
	
	weapon_parent.look_at(target_pos)
	
	# Handle flipping
	var rot_degrees = weapon_parent.rotation_degrees
	# Normalize to -180 to 180
	while rot_degrees > 180: rot_degrees -= 360
	while rot_degrees < -180: rot_degrees += 360
	
	if abs(rot_degrees) > 90:
		weapon_parent.scale.y = -1
	else:
		weapon_parent.scale.y = 1

func equip_weapon(weapon_scene: PackedScene, data: WeaponDataResource = null) -> void:
	# 1. Save ammo if it's the player
	if current_weapon and owner.is_in_group("player") and owner.get("weapon_state"):
		var ws = owner.weapon_state
		if current_weapon.has_node("Components/AmmoComponent"):
			var ac = current_weapon.get_node("Components/AmmoComponent")
			var state = ac.get_state()
			ws.current_ammo = state.current
			ws.reserve_ammo = state.reserve
			print("WeaponHolder: Saved ammo to state: ", state)

	if current_weapon:
		current_weapon.queue_free()
		current_weapon = null
	
	if not weapon_scene:
		return

	current_weapon = weapon_scene.instantiate()
	if data and "weapon_data" in current_weapon:
		current_weapon.weapon_data = data
		
	if "shooter" in current_weapon:
		current_weapon.shooter = owner
	
	if weapon_parent:
		weapon_parent.add_child(current_weapon)
	else:
		add_child(current_weapon) # Fallback

	# 2. Load ammo if it's the player
	if owner.is_in_group("player") and owner.get("weapon_state"):
		var ws = owner.weapon_state
		if ws.current_ammo != -1 and current_weapon.has_node("Components/AmmoComponent"):
			var ac = current_weapon.get_node("Components/AmmoComponent")
			ac.apply_state(ws.current_ammo, ws.reserve_ammo)
			print("WeaponHolder: Loaded ammo from state: ", ws.current_ammo, "/", ws.reserve_ammo)

	# Connect aiming signal if player
	if owner.is_in_group("player") and owner.input_component:
		if not owner.input_component.aim_state_changed.is_connected(_on_aim_state_changed):
			owner.input_component.aim_state_changed.connect(_on_aim_state_changed)
		# Initialize state
		_on_aim_state_changed(Input.is_action_pressed("aim"))

func _on_aim_state_changed(is_aiming: bool) -> void:
	if current_weapon and "is_aiming" in current_weapon:
		current_weapon.is_aiming = is_aiming

func fire() -> void:
	if current_weapon and current_weapon.has_method("fire"):
		current_weapon.fire()

func reload() -> void:
	if current_weapon and current_weapon.has_method("reload"):
		current_weapon.reload()

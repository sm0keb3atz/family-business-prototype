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

func equip_weapon(weapon_scene: PackedScene) -> void:
    if current_weapon:
        current_weapon.queue_free()
        current_weapon = null
    
    if not weapon_scene:
        return

    current_weapon = weapon_scene.instantiate()
    if "shooter" in current_weapon:
        current_weapon.shooter = owner
    
    if weapon_parent:
        weapon_parent.add_child(current_weapon)
    else:
        add_child(current_weapon) # Fallback

func fire() -> void:
    if current_weapon and current_weapon.has_method("fire"):
        current_weapon.fire()

func reload() -> void:
    if current_weapon and current_weapon.has_method("reload"):
        current_weapon.reload()


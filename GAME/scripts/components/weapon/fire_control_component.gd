extends Node
class_name FireControlComponent

@export var cooldown_timer: Timer

var is_automatic: bool = false
var can_fire_flag: bool = true

func initialize(data: WeaponDataResource) -> void:
    is_automatic = data.automatic
    if cooldown_timer:
        cooldown_timer.wait_time = data.fire_rate
        cooldown_timer.one_shot = true
        if not cooldown_timer.timeout.is_connected(_on_cooldown_timeout):
            cooldown_timer.timeout.connect(_on_cooldown_timeout)

func can_fire() -> bool:
    return can_fire_flag and (cooldown_timer == null or cooldown_timer.is_stopped())

func start_cooldown() -> void:
    can_fire_flag = false
    if cooldown_timer:
        cooldown_timer.start()

func _on_cooldown_timeout() -> void:
    can_fire_flag = true

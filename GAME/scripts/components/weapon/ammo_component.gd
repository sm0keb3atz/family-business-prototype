extends Node
class_name AmmoComponent

signal ammo_changed(current: int, reserve: int)
signal reload_started
signal reload_finished

var current_ammo: int = 0
var reserve_ammo: int = 0
var magazine_size: int = 0
var is_reloading: bool = false

func initialize(data: WeaponDataResource) -> void:
	magazine_size = data.magazine_size
	current_ammo = data.magazine_size
	reserve_ammo = data.reserve_ammo
	is_reloading = false
	emit_signal("ammo_changed", current_ammo, reserve_ammo)

func can_fire() -> bool:
	return current_ammo > 0 and not is_reloading

func consume_ammo(amount: int = 1) -> void:
	if current_ammo >= amount:
		current_ammo -= amount
		emit_signal("ammo_changed", current_ammo, reserve_ammo)

func can_reload() -> bool:
	return not is_reloading and current_ammo < magazine_size and reserve_ammo > 0

func start_reload() -> void:
	if can_reload():
		is_reloading = true
		emit_signal("reload_started")

func finish_reload() -> void:
	if not is_reloading:
		return
		
	var needed = magazine_size - current_ammo
	var available = min(needed, reserve_ammo)
	
	current_ammo += available
	reserve_ammo -= available
	is_reloading = false
	
	emit_signal("reload_finished")
	emit_signal("ammo_changed", current_ammo, reserve_ammo)

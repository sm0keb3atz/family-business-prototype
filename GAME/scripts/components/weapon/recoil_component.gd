extends Node
class_name RecoilComponent

signal recoil_applied(amount: float)

var recoil_strength: float = 0.0

func initialize(data: WeaponDataResource) -> void:
    recoil_strength = data.recoil_strength

func apply_recoil() -> void:
    emit_signal("recoil_applied", recoil_strength)

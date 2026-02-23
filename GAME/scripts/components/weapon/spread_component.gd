extends Node
class_name SpreadComponent

var spread_degrees: float = 0.0

func initialize(data: WeaponDataResource) -> void:
    spread_degrees = data.spread_degrees

func get_spread_direction(base_direction: Vector2) -> Vector2:
    if spread_degrees <= 0:
        return base_direction
        
    var spread_rad = deg_to_rad(spread_degrees)
    var random_angle = randf_range(-spread_rad / 2.0, spread_rad / 2.0)
    return base_direction.rotated(random_angle)

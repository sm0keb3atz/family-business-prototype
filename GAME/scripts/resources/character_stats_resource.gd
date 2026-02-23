extends Resource
class_name CharacterStatsResource

@export var max_health: int = 100
@export var health_regen: float = 0.0 # Only used by player usually
@export var move_speed: float = 300.0
@export var sprint_speed: float = 450.0
@export var defense: float = 0.0
@export var faction: StringName = &"neutral"

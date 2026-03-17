extends Resource
class_name DealerTierResource

@export var tier_level: int = 1
@export var min_stock: int = 10
@export var max_stock: int = 50
@export var max_health: int = 100
@export var weapon_data: WeaponDataResource
@export var weapon_scene: PackedScene
@export var restock_time_seconds: float = 60.0
@export var allowed_drugs: Array[DrugDefinitionResource] = []

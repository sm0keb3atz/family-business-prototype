extends Resource
class_name DealerTierResource

@export var tier_level: int = 1
@export var max_stock: int = 50
@export var restock_time_seconds: float = 60.0
@export var allowed_drugs: Array[DrugDefinitionResource] = []

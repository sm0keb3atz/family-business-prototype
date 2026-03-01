extends Resource
class_name DrugDefinitionResource

@export var id: StringName
@export var display_name: String
@export var base_price: int = 10
@export var icon: Texture2D
@export_multiline var description: String = ""

@export_group("Heat System")
@export var base_heat_per_gram: float = 1.0
@export var risk_multiplier: float = 1.0

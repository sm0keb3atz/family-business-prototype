extends Resource
class_name DealerStockOptionResource

@export var drug: DrugDefinitionResource
@export var min_amount: int = 1
@export var max_amount: int = 50
@export var use_bricks: bool = false

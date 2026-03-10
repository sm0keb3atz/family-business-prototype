extends Resource
class_name TerritoryResource

@export var territory_id: StringName = &"new_territory"
@export var display_name: String = "New Territory"
@export var territory_color: Color = Color.WHITE

@export_group("Pricing")
## Multiplier for player sales in this territory (e.g. 1.2 = 20% higher prices)
@export var price_multiplier: float = 1.0
## Base prices for drugs in this territory (Drug ID -> Price)
@export var drug_prices: Dictionary = {
	&"weed": 10
}

@export_group("Spawning Limits")
@export var max_customers: int = 10
@export var max_police: int = 2
@export var max_dealers: int = 1

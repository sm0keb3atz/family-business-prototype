class_name PropertyResource extends Resource

enum PropertyType {
	STASH_TRAP,
	FRONT_BUSINESS
}

@export var property_id: StringName = &""
@export var display_name: String = "Unknown Property"
@export var property_type: PropertyType = PropertyType.STASH_TRAP
@export var stash_capacity: int = 500
@export var purchase_price: int = 5000
@export var security_level: int = 1
@export var laundering_rate: float = 0.0

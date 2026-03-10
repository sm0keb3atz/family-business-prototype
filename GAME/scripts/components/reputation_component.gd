extends Node
class_name TerritoryReputationComponent

## Emitted when reputation value changes
signal reputation_changed(new_value: float)

@export var territory_id: StringName

var current_reputation: float = 0.0

## Adds (or subtracts) reputation, clamped between -100 and 100
func add_reputation(amount: float) -> void:
	var old_val = current_reputation
	current_reputation = clamp(current_reputation + amount, -100.0, 100.0)
	
	if not is_equal_approx(old_val, current_reputation):
		reputation_changed.emit(current_reputation)

func get_reputation() -> float:
	return current_reputation

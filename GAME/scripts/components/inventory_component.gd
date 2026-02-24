extends Node
class_name InventoryComponent

signal inventory_changed

# Keys are StringName (drug id), values are integers (quantity in grams)
var drugs: Dictionary = {}

func add_drug(id: StringName, amount: int) -> void:
	if amount <= 0: return
	if drugs.has(id):
		drugs[id] += amount
	else:
		drugs[id] = amount
	inventory_changed.emit()

func remove_drug(id: StringName, amount: int) -> bool:
	if amount <= 0: return false
	if drugs.has(id) and drugs[id] >= amount:
		drugs[id] -= amount
		if drugs[id] == 0:
			drugs.erase(id)
		inventory_changed.emit()
		return true
	return false

func get_drug_quantity(id: StringName) -> int:
	if drugs.has(id):
		return drugs[id]
	return 0

func has_drug(id: StringName, amount: int = 1) -> bool:
	return get_drug_quantity(id) >= amount

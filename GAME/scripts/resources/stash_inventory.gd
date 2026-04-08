class_name StashInventory extends Resource

signal stash_changed

@export var drugs: Dictionary = {} # StringName : int (grams)
@export var bricks: Dictionary = {} # StringName : int (count)
@export var dirty_cash: int = 0
@export var capacity: int = 500

func add_drug(drug_id: StringName, amount: int) -> bool:
	if not has_room(amount):
		return false
	if drugs.has(drug_id):
		drugs[drug_id] += amount
	else:
		drugs[drug_id] = amount
	stash_changed.emit()
	return true

func remove_drug(drug_id: StringName, amount: int) -> bool:
	if not drugs.has(drug_id) or drugs[drug_id] < amount:
		return false
	drugs[drug_id] -= amount
	if drugs[drug_id] <= 0:
		drugs.erase(drug_id)
	stash_changed.emit()
	return true

func add_brick(drug_id: StringName, amount: int) -> bool:
	if not has_room(amount * 100):
		return false
	if bricks.has(drug_id):
		bricks[drug_id] += amount
	else:
		bricks[drug_id] = amount
	stash_changed.emit()
	return true

func remove_brick(drug_id: StringName, amount: int) -> bool:
	if not bricks.has(drug_id) or bricks[drug_id] < amount:
		return false
	bricks[drug_id] -= amount
	if bricks[drug_id] <= 0:
		bricks.erase(drug_id)
	stash_changed.emit()
	return true

func add_dirty_cash(amount: int) -> void:
	dirty_cash += amount
	stash_changed.emit()

func remove_dirty_cash(amount: int) -> bool:
	if dirty_cash < amount:
		return false
	dirty_cash -= amount
	stash_changed.emit()
	return true

func get_used_capacity() -> int:
	var total: int = 0
	for amount in drugs.values():
		total += amount
	# Bricks weigh ~100g each
	for count in bricks.values():
		total += count * 100
	return total

func has_room(amount: int) -> bool:
	return get_used_capacity() + amount <= capacity

func get_free_capacity() -> int:
	return maxi(0, capacity - get_used_capacity())

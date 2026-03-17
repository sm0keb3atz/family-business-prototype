extends Node
class_name InventoryComponent

signal inventory_changed
signal girlfriends_changed

# Keys are StringName (drug id), values are integers (quantity in grams)
var drugs: Dictionary = {}
# Keys are StringName (drug id), values are integers (number of bricks)
var bricks: Dictionary = {}

var girlfriends: Array[GirlfriendResource] = []

func add_brick(id: StringName, amount: int) -> void:
	if amount <= 0: return
	if bricks.has(id):
		bricks[id] += amount
	else:
		bricks[id] = amount
	inventory_changed.emit()

func break_brick(id: StringName) -> bool:
	if bricks.has(id) and bricks[id] > 0:
		bricks[id] -= 1
		if bricks[id] == 0:
			bricks.erase(id)
		add_drug(id, 100) # 1 brick = 100g
		return true
	return false

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

func add_girlfriend(resource: GirlfriendResource) -> void:
	girlfriends.append(resource)
	girlfriends_changed.emit()

func remove_girlfriend(resource: GirlfriendResource) -> void:
	girlfriends.erase(resource)
	girlfriends_changed.emit()

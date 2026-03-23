extends Node
class_name InventoryComponent

signal inventory_changed
signal girlfriends_changed

# Keys are StringName (drug id), values are integers (quantity in grams)
var drugs: Dictionary = {}
# Keys are StringName (drug id), values are integers (number of bricks)
var bricks: Dictionary = {}

var girlfriends: Array[GirlfriendResource] = []

## Decay rate (points/sec) when a girlfriend is at home.
const GF_DECAY_RATE: float = 0.002

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


func _process(delta: float) -> void:
	var broke_up: bool = false
	for gf in girlfriends:
		if gf.is_following:
			# GirlfriendComponent on the NPC handles gain.
			# If is_following is true but the NPC is gone, flip to at-home.
			var npc_alive := _find_gf_npc(gf)
			if not npc_alive:
				gf.is_following = false
		else:
			# NPC is at home (or gone) — decay here
			gf.set_relationship(gf.relationship - GF_DECAY_RATE * delta)
			if gf.relationship <= 0.0:
				broke_up = true
				girlfriends_changed.emit() # trigger UI update
	
	if broke_up:
		# Rebuild typed array to remove broken-up GFs (filter returns untyped Array)
		var remaining: Array[GirlfriendResource] = []
		for g: GirlfriendResource in girlfriends:
			if g.relationship > 0.0:
				remaining.append(g)
		girlfriends = remaining
		girlfriends_changed.emit()

func _find_gf_npc(resource: GirlfriendResource) -> bool:
	var tree := get_tree()
	if not tree:
		return false
	for node in tree.get_nodes_in_group("girlfriend"):
		if node is NPC and node.gf_resource == resource:
			return true
	return false


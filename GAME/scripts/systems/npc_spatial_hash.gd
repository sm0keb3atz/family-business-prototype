extends RefCounted
class_name NPCSpatialHash
## Buckets NPCIdentity ghosts by world position so NPCManager can query nearby identities
## without scanning the full population.

const CELL_SIZE: float = 512.0

var _cells: Dictionary = {} # Vector2i -> Array[NPCIdentity]


func _cell_key(pos: Vector2) -> Vector2i:
	return Vector2i(floori(pos.x / CELL_SIZE), floori(pos.y / CELL_SIZE))


func insert(identity: NPCIdentity) -> void:
	var key := _cell_key(identity.global_position)
	if not _cells.has(key):
		_cells[key] = []
	_cells[key].append(identity)


func remove(identity: NPCIdentity) -> void:
	var key := _cell_key(identity.global_position)
	if not _cells.has(key):
		return
	var bucket: Array = _cells[key]
	bucket.erase(identity)
	if bucket.is_empty():
		_cells.erase(key)


func update_after_move(identity: NPCIdentity, old_pos: Vector2) -> void:
	var old_key := _cell_key(old_pos)
	var new_key := _cell_key(identity.global_position)
	if old_key == new_key:
		return
	if _cells.has(old_key):
		_cells[old_key].erase(identity)
	insert(identity)


func get_nearby(pos: Vector2, radius_cells: int) -> Array[NPCIdentity]:
	var out: Array[NPCIdentity] = []
	var center := _cell_key(pos)
	for x in range(center.x - radius_cells, center.x + radius_cells + 1):
		for y in range(center.y - radius_cells, center.y + radius_cells + 1):
			var key := Vector2i(x, y)
			if not _cells.has(key):
				continue
			for id in _cells[key]:
				out.append(id)
	return out


func clear() -> void:
	_cells.clear()

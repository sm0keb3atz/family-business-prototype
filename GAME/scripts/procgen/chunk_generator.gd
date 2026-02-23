extends Node2D
class_name ChunkGenerator

enum GenMode { WEIGHTED_RANDOM, CITY_GRID }

@export var mode: GenMode = GenMode.CITY_GRID

## Array of MapChunkData resources to pick from
@export var available_chunks: Array[MapChunkData] = []

## Size of the grid to generate (e.g., 5x5 chunks)
@export var grid_width: int = 9  # Increased for better block spread
@export var grid_height: int = 9

## Block Size (in chunks). E.g. 3 means a road every 3rd chunk.
@export var block_size: int = 3

## Pixel size of one chunk
@export var chunk_pixel_size: Vector2i = Vector2i(960, 960)

## The container to hold generated chunks
@export var chunk_container: Node2D

func _ready() -> void:
	if not chunk_container:
		chunk_container = self
	generate_map()

func generate_map() -> void:
	print("ChunkGen: Starting generation in mode: ", GenMode.keys()[mode])
	
	# Clear previous map
	for child in chunk_container.get_children():
		child.queue_free()
	
	if mode == GenMode.CITY_GRID:
		_generate_city_grid()
	else:
		_generate_weighted_random()
		
	print("ChunkGen: Generation Complete.")

# --- CITY GRID MODE ---
func _generate_city_grid() -> void:
	var occupied = {} # Track coords we manually filled (for blocks)
	
	for y in range(grid_height):
		for x in range(grid_width):
			var coords = Vector2i(x,y)
			if occupied.has(coords): continue
			
			var is_h_road_line = (y % block_size == 0)
			var is_v_road_line = (x % block_size == 0)
			
			# Case 1: Road or Intersection
			if is_h_road_line or is_v_road_line:
				var target_sockets = _get_road_sockets(is_h_road_line, is_v_road_line)
				var valid_options = _find_chunks_matching(target_sockets)
				valid_options = _filter_by_size(valid_options, Vector2i(1,1)) # Roads must be 1x1
				
				if valid_options.is_empty():
					print("ChunkGen: GRID ERROR at ", coords)
					continue
				_spawn_chunk(valid_options.pick_random(), coords)
				occupied[coords] = true
				
			# Case 2: Building Block (Interior)
			else:
				# Check if this is the start of a 2x2 block area
				# For block_size=3 (R, B, B, R), the 2x2 starts at index 1 (relative to block)
				var local_x = x % block_size
				var local_y = y % block_size
				
				if local_x == 1 and local_y == 1:
					# Try to spawn a LARGE 2x2 chunk first
					if _try_spawn_large_chunk(coords, Vector2i(2,2), occupied):
						continue
				
				# Fallback: Spawn normal 1x1 building chunk
				if not occupied.has(coords):
					var target_sockets = {"top":"!road", "bottom":"!road", "left":"!road", "right":"!road"}
					var valid = _find_chunks_matching(target_sockets)
					valid = _filter_by_size(valid, Vector2i(1,1))
					if valid: 
						_spawn_chunk(valid.pick_random(), coords)
						occupied[coords] = true

func _get_road_sockets(is_h: bool, is_v: bool) -> Dictionary:
	if is_h and is_v: return {"top":"road", "bottom":"road", "left":"road", "right":"road"}
	if is_h: return {"top":"!road", "bottom":"!road", "left":"road", "right":"road"}
	if is_v: return {"top":"road", "bottom":"road", "left":"!road", "right":"!road"}
	return {}

func _try_spawn_large_chunk(coords: Vector2i, size: Vector2i, occupied: Dictionary) -> bool:
	# Find chunks that match size and sockets (building sockets)
	var target_sockets = {"top":"!road", "bottom":"!road", "left":"!road", "right":"!road"}
	var candidates = _find_chunks_matching(target_sockets)
	candidates = _filter_by_size(candidates, size)
	
	if candidates.is_empty():
		return false
		
	var chosen = _pick_weighted(candidates)
	_spawn_chunk(chosen, coords)
	
	# Mark all covered cells as occupied
	for dy in range(size.y):
		for dx in range(size.x):
			occupied[coords + Vector2i(dx, dy)] = true
			
	return true

func _filter_by_size(chunks: Array[MapChunkData], size: Vector2i) -> Array[MapChunkData]:
	var filtered: Array[MapChunkData] = []
	for c in chunks:
		if c.size_in_chunks == size:
			filtered.append(c)
	return filtered

# --- UTILS ---
func _find_chunks_matching(criteria: Dictionary) -> Array[MapChunkData]:
	var results: Array[MapChunkData] = []
	for c in available_chunks:
		if _matches_socket(c.socket_top, criteria["top"]) and \
		   _matches_socket(c.socket_bottom, criteria["bottom"]) and \
		   _matches_socket(c.socket_left, criteria["left"]) and \
		   _matches_socket(c.socket_right, criteria["right"]):
			results.append(c)
	return results

func _matches_socket(chunk_socket: String, criteria: String) -> bool:
	if criteria == "any": return true
	if criteria == "!road": return chunk_socket != "road"
	return chunk_socket == criteria

func _pick_weighted(options: Array[MapChunkData]) -> MapChunkData:
	var total_weight = 0
	for c in options:
		total_weight += c.weight
		
	var r = randi() % total_weight
	var cursor = 0
	for c in options:
		cursor += c.weight
		if r < cursor:
			return c
	return options[0]

func _spawn_chunk(data: MapChunkData, coords: Vector2i) -> void:
	if not data.chunk_scene: return
	
	var instance = data.chunk_scene.instantiate()
	chunk_container.add_child(instance)
	
	# Position
	instance.position = Vector2(coords.x * chunk_pixel_size.x, coords.y * chunk_pixel_size.y)
	
	# Optional: If it's a large chunk, maybe we want to center it or something?
	# For now, top-left alignment is standard for grids.

# --- WEIGHTED RANDOM MODE (Legacy/Organic) ---
func _generate_weighted_random() -> void:
	var placed_data = {}
	
	for y in range(grid_height):
		for x in range(grid_width):
			var coords = Vector2i(x,y)
			var valid_options = _get_valid_chunks(coords, placed_data)
			
			if valid_options.is_empty():
				print("ChunkGen: ERROR at ", coords)
				continue
				
			var chosen_data = _pick_weighted(valid_options)
			placed_data[coords] = chosen_data
			
			_spawn_chunk(chosen_data, coords)
			
			await get_tree().process_frame

## Filter available chunks based on neighbors
func _get_valid_chunks(coords: Vector2i, placed_data: Dictionary) -> Array[MapChunkData]:
	var candidates: Array[MapChunkData] = []
	
	var top_neighbor = placed_data.get(coords + Vector2i.UP)
	var left_neighbor = placed_data.get(coords + Vector2i.LEFT)
	
	for chunk in available_chunks:
		var valid = true
		if top_neighbor:
			if top_neighbor.socket_bottom != chunk.socket_top: valid = false
		if valid and left_neighbor:
			if left_neighbor.socket_right != chunk.socket_left: valid = false
		if valid:
			candidates.append(chunk)
			
	return candidates

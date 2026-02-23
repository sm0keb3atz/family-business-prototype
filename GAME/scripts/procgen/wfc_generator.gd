extends Node
class_name WFCGenerator

## The size of the pattern to learn (NxN). N=2 or N=3 is usually best.
const N: int = 2

## Map of Pattern Hash -> Pattern Data (2D Array of Tile IDs)
var patterns: Dictionary = {}
## Frequency of each pattern in the sample input
var pattern_weights: Dictionary = {}
## Adjacency rules: pattern_hash -> direction (Vector2i) -> list of compatible pattern_hashes
var adjacency_rules: Dictionary = {}

## Special feature markers found in the sample (Tile ID -> Feature Name)
## This will be populated by scanning the sample scene for specific marker nodes.
var special_feature_map: Dictionary = {}

## Learn patterns from a sample TileMapLayer
## input_layer: The layer containing the painted sample.
## feature_map: Optional mapping of specific coordinate/tile to feature names (e.g. Doors)
func learn(input_layer: TileMapLayer, provided_feature_nodes: Array = []) -> void:
	print("WFC: Learning from ", input_layer.name, "...")
	patterns.clear()
	pattern_weights.clear()
	adjacency_rules.clear()
	special_feature_map.clear()
	
	# 1. Map features from nodes to tile coordinates
	var feature_lookup = {} # Vector2i -> Feature Name
	for node in provided_feature_nodes:
		if node is Node2D:
			var tile_pos = input_layer.local_to_map(node.position)
			# Store the feature. If it's a DoorTrigger, we mark it.
			if node.has_method("swap_map") or node.get_script().resource_path.contains("door"):
				feature_lookup[tile_pos] = "Door"
				print("  - Found Door at: ", tile_pos)
		
	# 2. Extract Patterns
	var used_rect = input_layer.get_used_rect()
	# Buffer to allow wrapping or partial matches at edges? For now, strict interior sampling.
	# We iterate through every possible NxN block in the used rect.
	for y in range(used_rect.position.y, used_rect.end.y - N + 1):
		for x in range(used_rect.position.x, used_rect.end.x - N + 1):
			var pattern = _extract_pattern(input_layer, Vector2i(x, y))
			var p_hash = _hash_pattern(pattern)
			
			if not patterns.has(p_hash):
				patterns[p_hash] = pattern
				pattern_weights[p_hash] = 0
			
			pattern_weights[p_hash] += 1
			
			# Check if this top-left tile has a feature
			if feature_lookup.has(Vector2i(x,y)):
				# We map the PATTERN to the feature.
				# Actually, simplistic approach: If the pattern's (0,0) tile has a feature, this pattern spawns it.
				special_feature_map[p_hash] = feature_lookup[Vector2i(x,y)]

	print("WFC: Extracted ", patterns.size(), " unique patterns.")
	
	# 3. Build Adjacency Rules
	await _build_adjacency()
	print("WFC: Built adjacency rules.")

## Extract an NxN block of tile data (source_id, atlas_coord)
func _extract_pattern(layer: TileMapLayer, start: Vector2i) -> Array:
	var p = []
	for dy in range(N):
		var row = []
		for dx in range(N):
			var coords = start + Vector2i(dx, dy)
			var source_id = layer.get_cell_source_id(coords)
			var atlas_coords = layer.get_cell_atlas_coords(coords)
			var alt_tile = layer.get_cell_alternative_tile(coords)
			# Store as a unique identifier for the cell state
			row.append({
				"source": source_id,
				"atlas": atlas_coords,
				"alt": alt_tile
			})
		p.append(row)
	return p

func _hash_pattern(pattern: Array) -> int:
	return hash(pattern)

func _build_adjacency() -> void:
	var directions = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	
	# 1. Precompute overlap hashes for all patterns to optimize lookups
	# Map: Direction -> { OverlapHash -> [List of Pattern Hashes] }
	var overlap_map = {}
	for dir in directions:
		overlap_map[dir] = {}
		
	for p_hash in patterns:
		for dir in directions:
			var o_hash = _get_overlap_hash(patterns[p_hash], dir)
			if not overlap_map[dir].has(o_hash):
				overlap_map[dir][o_hash] = []
			overlap_map[dir][o_hash].append(p_hash)
	
	await get_tree().process_frame
	
	# 2. Build rules by matching overlaps
	var count = 0
	for p_hash in patterns:
		adjacency_rules[p_hash] = {}
		for dir in directions:
			# My overlap exposed to this direction
			var my_overlap = _get_overlap_hash(patterns[p_hash], dir)
			
			# Compatible neighbors are those whose OPPOSITE overlap matches mine
			# e.g. If I look UP, I need a neighbor whose DOWN overlap matches my UP overlap.
			var opp_dir = -dir
			if overlap_map[opp_dir].has(my_overlap):
				adjacency_rules[p_hash][dir] = overlap_map[opp_dir][my_overlap]
			else:
				adjacency_rules[p_hash][dir] = []
		
		count += 1
		if count % 200 == 0:
			await get_tree().process_frame

## Returns a hash of the "edge" or "overlap region" of the pattern in the given direction.
## For N=2, this is the 1-pixel slice closest to that direction.
func _get_overlap_hash(pattern: Array, dir: Vector2i) -> int:
	var x_range = range(N)
	var y_range = range(N)
	
	# If we are looking UP, we expose our TOP rows (0..N-2)
	# If we are looking DOWN, we expose our BOTTOM rows (1..N-1)
	if dir == Vector2i.UP:
		y_range = range(0, N - 1)
	elif dir == Vector2i.DOWN:
		y_range = range(1, N)
	elif dir == Vector2i.LEFT:
		x_range = range(0, N - 1)
	elif dir == Vector2i.RIGHT:
		x_range = range(1, N)
		
	var sub_pattern = []
	for y in y_range:
		for x in x_range:
			# We only care about source/atlas/alt for compatibility
			var cell = pattern[y][x]
			sub_pattern.append(hash([cell["source"], cell["atlas"], cell["alt"]]))
	
	return hash(sub_pattern)

# --- GENERATION ---

# --- GENERATION ---

## Generate a map of size width x height on the target layer
func generate(width: int, height: int, target_layer: TileMapLayer, max_retries: int = 10) -> void:
	print("WFC: Generating ", width, "x", height, " map...")
	
	var attempts = 0
	while attempts < max_retries:
		print("WFC: Attempt ", attempts + 1, " / ", max_retries)
		attempts += 1
		
		# Try to generate
		var success = await _attempt_generation(width, height, target_layer)
		if success:
			print("WFC: SUCCESS on attempt ", attempts)
			return
			
	print("WFC ERROR: Failed to generate a valid map after ", max_retries, " attempts.")

## Internal generation attempt. Returns true if successful.
func _attempt_generation(width: int, height: int, target_layer: TileMapLayer) -> bool:
	target_layer.clear()
	
	# Grid of possibilities: Vector2i -> Array[int] (list of pattern hashes)
	var wave = {}
	var all_patterns = patterns.keys()
	
	# Initialize wave
	for y in range(height):
		for x in range(width):
			wave[Vector2i(x, y)] = all_patterns.duplicate()
			
	var stack = [] # For propagation
	var cells_collapsed = 0
	var total_cells = width * height
	
	# Limit processing time per frame
	var ops_since_yield = 0
	
	while cells_collapsed < total_cells:
		# 1. Observation: Find cell with min entropy
		var min_entropy = 999999
		var candidates = []
		
		for coords in wave:
			var entropy = wave[coords].size()
			if entropy == 1: continue # Already collapsed
			if entropy == 0:
				# print("WFC DEBUG: Contradiction at ", coords)
				return false # Failed attempt
			
			if entropy < min_entropy:
				min_entropy = entropy
				candidates = [coords]
			elif entropy == min_entropy:
				candidates.append(coords)
				
		if candidates.is_empty():
			break # All collapsed
			
		var current_coords = candidates.pick_random()
		
		# Collapse: Pick one pattern based on weights
		var chosen_pattern = _weighted_random_choice(wave[current_coords])
		wave[current_coords] = [chosen_pattern]
		cells_collapsed += 1
		
		# Yield checks
		ops_since_yield += 1
		if ops_since_yield > 100:
			ops_since_yield = 0
			await get_tree().process_frame
		
		stack.append(current_coords)
		
		# 2. Propagation
		while not stack.is_empty():
			var p_coords = stack.pop_back()
			var p_possible_hashes = wave[p_coords]
			
			# Yield checks inner loop too
			ops_since_yield += 1
			if ops_since_yield > 100:
				ops_since_yield = 0
				await get_tree().process_frame
				
			for dir in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
				var n_coords = p_coords + dir
				if not wave.has(n_coords): continue
				
				var n_possible_hashes = wave[n_coords]
				var original_len = n_possible_hashes.size()
				
				# Filter neighbors: Keep hash N if it is compatible with ANY of the patterns remaining in P
				# compatible means: N is in adjacency_rules[P][dir]
				
				var new_possible = []
				for h_n in n_possible_hashes:
					var valid = false
					for h_p in p_possible_hashes:
						if h_n in adjacency_rules[h_p][dir]:
							valid = true
							break
					if valid:
						new_possible.append(h_n)
				
				if new_possible.size() == 0:
					# print("WFC DEBUG: Contradiction propagated to ", n_coords)
					return false # Failed attempt
					
				if new_possible.size() < original_len:
					wave[n_coords] = new_possible
					stack.append(n_coords)

	# 3. Output to TileMap
	print("WFC: Generation complete! Rendering...")
	var empty_count = 0
	for y in range(height):
		for x in range(width):
			var p_hash = wave[Vector2i(x,y)][0]
			var pattern = patterns[p_hash]
			# Render pixel (0,0) of the pattern to the map.
			# Note: With N=2 overlapping, we only strictly determine the top-left pixel of the cell.
			var cell_data = pattern[0][0]
			
			if cell_data["source"] == -1:
				empty_count += 1
				
			target_layer.set_cell(Vector2i(x,y), cell_data["source"], cell_data["atlas"], cell_data["alt"])
			
			# Check for Features
			if special_feature_map.has(p_hash):
				var feat = special_feature_map[p_hash]
				if feat == "Door":
					_spawn_door(target_layer, Vector2i(x,y))
	
	print("WFC Render Stats: Total Cells: ", width*height, " | Empty Cells: ", empty_count)
	return true

func _weighted_random_choice(options: Array) -> int:
	var total_weight = 0.0
	for h in options:
		total_weight += pattern_weights[h]
		
	var r = randf() * total_weight
	var cursor = 0.0
	for h in options:
		cursor += pattern_weights[h]
		if r <= cursor:
			return h
	return options[0]

func _spawn_door(layer: TileMapLayer, coords: Vector2i) -> void:
	print("SPAWNING DOOR AT ", coords)
	var door_scene = load("res://GAME/scenes/test_map_swap.tscn").get_node("Exterior/DoorToInterior").duplicate()
	# The line above is a bit hacky, normally we'd instantiate a prefab.
	# But since user hasn't made a prefab, we create one dynamically or use a script approach.
	# Better: Create a minimal Area2D with script.
	
	var door = Area2D.new()
	door.name = "GeneratedDoor"
	var col = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = Vector2(40, 20)
	col.shape = rect
	door.add_child(col)
	
	door.set_script(load("res://GAME/scripts/door_trigger.gd"))
	# We need to set 'spawn_point' roughly.
	# For now, default to None or find an Interior spawn.
	
	layer.add_child(door)
	door.position = layer.map_to_local(coords)

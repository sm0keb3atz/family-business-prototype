extends Node2D

## The scene containing our painted samples
@export var samples_scene: PackedScene
## The TileMapLayer to generate into (Exterior)
@export var target_layer: TileMapLayer
## The size of the generated map
@export var map_width: int = 20
@export var map_height: int = 20

var generator: WFCGenerator

func _ready() -> void:
	if not samples_scene:
		print("WFC Test: No samples scene assigned!")
		return
		
	generator = WFCGenerator.new()
	add_child(generator)
	
	# Instantiate samples to read from them
	var samples_instance = samples_scene.instantiate()
	# We assume the structure: Root -> Exterior -> Buildings (the layer we want to learn)
	# But actually we want to learn GROUND and BUILDINGS.
	# For this prototype, let's learn "Buildings" layer first as it has the structure.
	
	# We need to add it to the tree to use it? Ideally yes.
	add_child(samples_instance)
	# Hiding it so it doesn't overlap
	samples_instance.position = Vector2(-2000, -2000)
	
	var buildings_layer = samples_instance.get_node("Exterior/Buildings")
	var ground_layer = samples_instance.get_node("Exterior/Ground")
	
	if not buildings_layer or not ground_layer:
		print("WFC Test: Could not find Exterior/Buildings or Exterior/Ground layer in samples.")
		return
		
	print("WFC Test: Merging layers for learning...")
	var learning_layer = _create_merged_layer(ground_layer, buildings_layer)
	add_child(learning_layer) # Must be in tree to work properly with some API? Safest.
		
	print("WFC Test: STARTING LEARNING...")
	
	# Find feature nodes (Doors) in the sample's Exterior
	var feature_nodes = []
	var exterior_node = samples_instance.get_node("Exterior")
	for child in exterior_node.get_children():
		if child is Area2D:
			feature_nodes.append(child)
			
	await generator.learn(learning_layer, feature_nodes)
	
	# Clean up merged layer
	learning_layer.queue_free()
	
	print("WFC Test: STARTING GENERATION...")
	
	# Wait for learning (which contains awaits now) if necessary, 
	# but actually learning was synchronous before, now it has awaits.
	# So we must await it. But the learn function handles internal awaits.
	# Wait, if I await in learn, I must await the call.
	
	await generator.generate(map_width, map_height, target_layer)
	
	# Clean up samples
	samples_instance.queue_free()
	
	print("WFC Test: DONE.")

func _create_merged_layer(base: TileMapLayer, overlay: TileMapLayer) -> TileMapLayer:
	var merged = TileMapLayer.new()
	merged.tile_set = base.tile_set
	merged.name = "MergedLearningLayer"
	
	# 1. Copy Base (Ground)
	var base_rect = base.get_used_rect()
	for y in range(base_rect.position.y, base_rect.end.y):
		for x in range(base_rect.position.x, base_rect.end.x):
			var coords = Vector2i(x, y)
			var src = base.get_cell_source_id(coords)
			if src != -1:
				merged.set_cell(coords, src, base.get_cell_atlas_coords(coords), base.get_cell_alternative_tile(coords))
				
	# 2. Copy Overlay (Buildings) - Overwrite if present
	var over_rect = overlay.get_used_rect()
	for y in range(over_rect.position.y, over_rect.end.y):
		for x in range(over_rect.position.x, over_rect.end.x):
			var coords = Vector2i(x, y)
			var src = overlay.get_cell_source_id(coords)
			if src != -1:
				# Overwrite ground with building
				merged.set_cell(coords, src, overlay.get_cell_atlas_coords(coords), overlay.get_cell_alternative_tile(coords))
				
	return merged

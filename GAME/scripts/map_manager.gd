extends Node
class_name MapManager

## Reference to the exterior map layer/scene
@export var exterior_node: Node2D
## Reference to the interior map layer/scene
@export var interior_node: Node2D
## How long to wait before allowing another swap (prevents ping-ponging)
@export var swap_cooldown: float = 0.5

var _current_is_interior: bool = false
var _on_cooldown: bool = false

# Transition UI
var _fade_layer: CanvasLayer
var _fade_rect: ColorRect
var _died_label: Label

func _ready() -> void:
	add_to_group("map_manager")
	
	if not exterior_node:
		exterior_node = get_tree().get_root().find_child("Map", true, false)
	
	_setup_fade_ui()
	_current_is_interior = false
	_apply_visibility()

func _setup_fade_ui() -> void:
	_fade_layer = CanvasLayer.new()
	_fade_layer.layer = 100
	add_child(_fade_layer)
	
	_fade_rect = ColorRect.new()
	_fade_rect.color = Color(0, 0, 0, 0)
	_fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_layer.add_child(_fade_rect)
	
	# 2. YOU DIED UI Container (to ensure centering works)
	var ui_container = Control.new()
	ui_container.name = "DeathUIContainer"
	ui_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade_layer.add_child(ui_container)
	
	_died_label = Label.new()
	_died_label.name = "YouDiedLabel"
	_died_label.text = "YOU DIED"
	_died_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_died_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_died_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT) # Now it has a Control parent!
	
	# Load font
	var font_path = "res://GAME/assets/ui/CyberpunkCraftpixPixel.otf"
	if FileAccess.file_exists(font_path):
		var font = load(font_path)
		_died_label.add_theme_font_override("font", font)
		_died_label.add_theme_font_size_override("font_size", 128) # Large font
	
	_died_label.modulate.a = 0.0 # Start hidden
	_died_label.add_theme_color_override("font_color", Color.RED)
	ui_container.add_child(_died_label)

## The main interaction function called by DoorTrigger
func interact_with_door(to_interior: bool, spawn_pos: Vector2, door: Node = null) -> void:
	if _on_cooldown:
		return
	
	_on_cooldown = true
	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.set_physics_process(false)
		if player.has_node("StateMachine"):
			player.get_node("StateMachine").set_process(false)

	print("MapManager: Interacting with door. Door: ", door.name if door else "null", " to_interior: ", to_interior)
	
	if to_interior:
		# ENTERING: Animation -> Wait -> Fade Out -> Delay -> Swap -> Fade In
		if door:
			door.visible = true
			if door.has_node("AnimationPlayer"):
				var anim = door.get_node("AnimationPlayer")
				if anim.has_animation("door_open"):
					anim.play("door_open")
					await _wait_for_anim(anim)
			elif door is AnimatedSprite2D:
				if door.sprite_frames.has_animation("door_open"):
					door.frame = 0
					door.play("door_open")
					await _wait_for_anim(door)
		
		await _fade(1.0)
		await get_tree().create_timer(0.2).timeout # Hide camera snap
		swap_map(true, spawn_pos)
		await _fade(0.0)
	else:
		# EXITING: Fade Out -> Delay -> Swap -> Fade In -> Door Close -> Wait
		await _fade(1.0)
		await get_tree().create_timer(0.2).timeout # Hide camera snap
		swap_map(false, spawn_pos)
		await _fade(0.0)
		
		# Play close animation AFTER fade in is done
		if door:
			door.visible = true
			if door.has_node("AnimationPlayer"):
				var anim = door.get_node("AnimationPlayer")
				if anim.has_animation("door_close"):
					anim.play("door_close")
					await _wait_for_anim(anim)
			elif door is AnimatedSprite2D:
				if door.sprite_frames.has_animation("door_close"):
					door.frame = 0
					door.play("door_close")
					await _wait_for_anim(door)
	
	if player:
		player.set_physics_process(true)
		if player.has_node("StateMachine"):
			player.get_node("StateMachine").set_process(true)

	await get_tree().create_timer(swap_cooldown).timeout
	_on_cooldown = false

# Helper to avoid hanging if animation doesn't finish or loops
func _wait_for_anim(node: Node) -> void:
	if node is AnimationPlayer:
		if node.is_playing():
			await node.animation_finished
		else:
			await get_tree().create_timer(0.1).timeout
	elif node is AnimatedSprite2D:
		if node.is_playing():
			await node.animation_finished
		else:
			# If it's not "playing" but we just called play, it might need a frame
			await get_tree().process_frame
			if node.is_playing():
				await node.animation_finished
			else:
				await get_tree().create_timer(0.1).timeout
	else:
		await get_tree().create_timer(0.1).timeout

func _fade(target_alpha: float, duration: float = 0.4) -> void:
	var tween = create_tween()
	await tween.tween_property(_fade_rect, "color:a", target_alpha, duration).set_trans(Tween.TRANS_SINE).finished

func swap_map(to_interior: bool, spawn_pos: Vector2 = Vector2.ZERO) -> void:
	if _current_is_interior == to_interior:
		return
		
	_current_is_interior = to_interior
	_apply_visibility()
	
	var player = get_tree().get_first_node_in_group("player")
	if player and spawn_pos != Vector2.ZERO:
		player.global_position = spawn_pos
		print("MapManager: Player moved to: ", spawn_pos)
		
		# NEW: Force camera to snap immediately while screen is black
		var camera = get_tree().get_first_node_in_group("camera")
		if camera and camera.has_method("snap_to_target"):
			camera.snap_to_target()

func _apply_visibility() -> void:
	if exterior_node:
		exterior_node.visible = !_current_is_interior
		exterior_node.set_process(!_current_is_interior)
		exterior_node.set_physics_process(!_current_is_interior)
	
	if interior_node:
		interior_node.visible = _current_is_interior
		interior_node.set_process(_current_is_interior)
		interior_node.set_physics_process(_current_is_interior)


## Triggers the player death cutscene and respawning
func trigger_death_cutscene(player: Player) -> void:
	if _on_cooldown:
		return
	
	_on_cooldown = true
	
	# 1. Start Fade Out and Camera Zoom Out
	var camera = get_tree().get_first_node_in_group("camera")
	if camera and camera.has_method("tween_zoom"):
		camera.block_input = true
		camera._manual_zoom_override = camera.camera.zoom # Initialize override to current zoom
		# Zoom out slower and further
		camera.tween_zoom(Vector2(0.2, 0.2), 8.0)
	
	# Reset Wanted Level and all NPC aggression instantly on death
	if has_node("/root/HeatManager"):
		get_node("/root/HeatManager").reset()
	
	# Faster fade out for better flow (2.5 seconds instead of 4)
	var fade_tween = create_tween()
	fade_tween.set_parallel(true)
	fade_tween.tween_property(_fade_rect, "color:a", 1.0, 2.5).set_trans(Tween.TRANS_SINE)
	fade_tween.tween_property(_died_label, "modulate:a", 1.0, 2.5).set_trans(Tween.TRANS_SINE)
	
	await fade_tween.finished
	
	# Wait shorter while screen is black (0.8 seconds instead of 2.0)
	await get_tree().create_timer(0.8).timeout
	
	# 2. Teleport to Hospital
	_died_label.modulate.a = 0.0 # Hide label before fading back in
	var world = get_tree().current_scene
	var hospital_spawn = world.find_child("HospitalSpawn", true, false)
	var spawn_pos = Vector2.ZERO
	if hospital_spawn:
		spawn_pos = hospital_spawn.global_position
	
	# Always clear interior state when respawning at hospital (which is exterior)
	_current_is_interior = false
	_apply_visibility()
	
	if player:
		player.respawn(spawn_pos)

	if camera:
		if camera.has_method("snap_to_target"):
			camera.snap_to_target()
		if camera.has_method("reset_zoom"):
			camera.reset_zoom()
	
	# 3. Fade Back In
	await _fade(0.0)
	if camera:
		camera.block_input = false
	_on_cooldown = false

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

func _fade(target_alpha: float) -> void:
	var tween = create_tween()
	await tween.tween_property(_fade_rect, "color:a", target_alpha, 0.4).set_trans(Tween.TRANS_SINE).finished

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

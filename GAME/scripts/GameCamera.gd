extends Node2D

## Dedicated GameCamera for circular transparency mask system.
## Smoothly follows a target and provides screen-space position for shaders.
## Optimized trauma-based shake system for stable performance.

@export var target: Node2D
@export var lerp_speed: float = 5.0

@export_group("Shake Settings")
@export var trauma_reduction_rate: float = 1.5 # Faster decay for snappier feel
@export var max_x: float = 40.0 # Increased horizontal jolt
@export var max_y: float = 40.0 # Increased vertical jolt
@export var noise_speed: float = 150.0 # Higher speed for faster jitter

## Radius of the circular cutout in pixels
@export var cutout_radius: float = 150.0
## Softness of the edge (0.0 to 1.0)
@export var edge_softness: float = 0.8

@export_group("Bob Settings")
@export var bob_frequency: float = 12.0 ## Speed of the view bobbing
@export var bob_amplitude: Vector2 = Vector2(2.0, 3.0) ## X and Y amplitude of the figure-8 bob

@export_group("Zoom Settings")
@export var normal_zoom: Vector2 = Vector2(2.0, 2.0)
@export var aim_zoom: Vector2 = Vector2(1.2, 1.2)
@export var zoom_speed: float = 5.0

@onready var camera: Camera2D = $Camera2D

var trauma: float = 0.0 # Current trauma level [0.0, 1.0]
var trauma_power: int = 2 # Trauma is squared for smoother feel
var time: float = 0.0

var _bob_phase: float = 0.0
var _last_target_pos: Vector2 = Vector2.ZERO

var noise: FastNoiseLite = FastNoiseLite.new()

func _ready() -> void:
	add_to_group("camera")
	if is_instance_valid(camera):
		camera.make_current()
	
	# Setup noise for shake
	noise.seed = randi()
	noise.frequency = 0.1 # High scale noise for smooth but fast movement
	
	# Snap to target immediately if it exists
	snap_to_target()

func snap_to_target() -> void:
	if is_instance_valid(target):
		global_position = target.global_position
		_last_target_pos = target.global_position
		print("GameCamera: Snapped to target position: ", global_position)

func _process(delta: float) -> void:
	var is_moving = false
	if is_instance_valid(target):
		# Smoothly interpolate position towards target
		global_position = global_position.lerp(target.global_position, lerp_speed * delta)
		
		var speed = target.global_position.distance_to(_last_target_pos) / delta
		if speed > 10.0: # threshold to avoid micro-jitter bobbing
			is_moving = true
		
		_last_target_pos = target.global_position
		
	if is_moving:
		_bob_phase += delta * bob_frequency
	else:
		# Smoothly decay bob phase to the nearest resting position (multiple of PI)
		var target_phase = round(_bob_phase / PI) * PI
		_bob_phase = lerpf(_bob_phase, target_phase, delta * 10.0)
	
	_update_shake(delta)
	
	# Handle aiming zoom
	var target_zoom = normal_zoom
	if Input.is_action_pressed("aim"):
		target_zoom = aim_zoom
		
	camera.zoom = camera.zoom.lerp(target_zoom, delta * zoom_speed)

## Adds trauma to the camera (capped at 1.0)
func add_trauma(amount: float) -> void:
	trauma = clamp(trauma + amount, 0.0, 1.0)

## Legacy shake method for compatibility, mapping to trauma
func shake(intensity: float, _duration: float = 0.0) -> void:
	# intensity here is treated as a trauma addition
	# Maps original 0-5 intensities to 0.0-0.5 trauma
	add_trauma(clamp(intensity * 0.1, 0.0, 0.5))

func _update_shake(delta: float) -> void:
	# Calculate bob offset (figure-8 motion)
	var bob_offset = Vector2(
		sin(_bob_phase * 0.5) * bob_amplitude.x,
		sin(_bob_phase) * bob_amplitude.y
	)
	
	if trauma > 0:
		time += delta * noise_speed
		trauma = max(trauma - trauma_reduction_rate * delta, 0.0)
		
		var shake_amount = pow(trauma, trauma_power)
		
		# Apply noise-based shake using separate noise lookups for X and Y
		var offset_x = max_x * shake_amount * noise.get_noise_2d(time, 0.0)
		var offset_y = max_y * shake_amount * noise.get_noise_2d(0.0, time)
		
		camera.offset = Vector2(offset_x, offset_y) + bob_offset
	else:
		camera.offset = bob_offset
		if camera.rotation != 0.0:
			camera.rotation = 0.0

## Returns the screen-space position (pixels) of the target
func get_target_screen_pos() -> Vector2:
	if !is_instance_valid(target):
		return Vector2.ZERO
	
	# get_canvas_transform() maps world coordinates to viewport coordinates (pixels)
	return get_viewport().get_canvas_transform() * target.global_position

extends Camera2D
class_name DebugCamera

@export var move_speed: float = 2000.0  # Increased speed
@export var zoom_speed: float = 0.1
@export var min_zoom: float = 0.05
@export var max_zoom: float = 5.0

func _ready() -> void:
	make_current()
	print("DebugCamera: Active at ", position)

func _process(delta: float) -> void:
	# Use standard UI actions (Arrow keys or WASD usually map to these by default)
	var move_vec = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	
	if move_vec.length() > 0:
		position += move_vec * move_speed * delta * (1.0 / zoom.x)

	# Manual WASD fallback if UI actions aren't mapped
	if move_vec == Vector2.ZERO:
		if Input.is_physical_key_pressed(KEY_W): move_vec.y -= 1
		if Input.is_physical_key_pressed(KEY_S): move_vec.y += 1
		if Input.is_physical_key_pressed(KEY_A): move_vec.x -= 1
		if Input.is_physical_key_pressed(KEY_D): move_vec.x += 1
		if move_vec.length() > 0:
			position += move_vec.normalized() * move_speed * delta * (1.0 / zoom.x)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.is_pressed():
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				zoom += Vector2(zoom_speed, zoom_speed)
				# print("DebugCamera: Zoom In ", zoom)
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				zoom -= Vector2(zoom_speed, zoom_speed)
				# print("DebugCamera: Zoom Out ", zoom)
			
			zoom.x = clamp(zoom.x, min_zoom, max_zoom)
			zoom.y = clamp(zoom.y, min_zoom, max_zoom)

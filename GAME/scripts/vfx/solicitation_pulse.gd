extends ColorRect

@export var pulse_color: Color = Color(0.0, 0.8, 1.0, 0.4) # More transparent teal
@export var thickness: float = 0.04
@export var duration: float = 1.5 # Even slower for "cool" factor
@export var fade_power: float = 2.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_level = true
	if material:
		material = material.duplicate()
		# Sync script color with material color from editor if script color is default
		if pulse_color == Color(0.0, 0.8, 1.0, 0.4): # Previous default
			pulse_color = material.get_shader_parameter("color")

func start_pulse(spawn_position: Vector2, max_radius: float) -> void:
	# Use a tighter area. 2.2 is enough for thickness + feather
	var pulse_size = max_radius * 2.2
	size = Vector2(pulse_size, pulse_size)
	position = spawn_position - size * 0.5
	pivot_offset = size * 0.5
	
	# Pull color from material if not explicitly set to something else
	var base_color = pulse_color
	if material and material.get_shader_parameter("color"):
		base_color = material.get_shader_parameter("color")
	
	material.set_shader_parameter("color", base_color)
	material.set_shader_parameter("thickness", thickness)
	
	var tween = create_tween()
	tween.set_parallel(true)
	
	# TRANS_SINE or TRANS_QUAD is smoother and less "explosive" than TRANS_EXPO
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	
	# Mapping 0.4545 * 2.2 = 1.0 (Exact max_radius)
	var target_radius_param = (max_radius / pulse_size)
	tween.tween_property(material, "shader_parameter/radius", target_radius_param, duration).from(0.0)
	
	# Fade out color
	var target_color = base_color
	target_color.a = 0.0
	# Use a softer ease for alpha fade
	tween.tween_property(material, "shader_parameter/color", target_color, duration).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	
	tween.chain().tween_callback(queue_free)

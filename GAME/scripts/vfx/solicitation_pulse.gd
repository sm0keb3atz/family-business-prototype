extends ColorRect

@export var pulse_color: Color = Color(0.18, 0.66, 1.0, 0.6)
@export var thickness: float = 0.04
@export var duration: float = 0.8
@export var fade_power: float = 2.0
@export var response_intensity_scale: float = 0.2
@export var heat_intensity_scale: float = 0.25
@export var scale_punch: Vector2 = Vector2(1.02, 1.02)
@export var spawn_scale: Vector2 = Vector2(0.92, 0.92)
@export var rotation_jitter: float = 0.08

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_level = true
	color = Color.TRANSPARENT
	if material:
		material = material.duplicate()
		var material_color = material.get_shader_parameter("color")
		if material_color != null:
			pulse_color = material_color

func start_pulse(spawn_position: Vector2, max_radius: float, response_strength: float = 0.0, heat_strength: float = 0.0) -> void:
	if not material:
		return

	response_strength = clampf(response_strength, 0.0, 1.0)
	heat_strength = clampf(heat_strength, 0.0, 1.0)

	var pulse_size = max_radius * 2.6
	size = Vector2(pulse_size, pulse_size)
	position = spawn_position - size * 0.5
	pivot_offset = size * 0.5

	var base_color: Color = _get_shader_param("color", pulse_color)
	var base_thickness: float = _get_shader_param("thickness", thickness)
	var base_feather: float = _get_shader_param("feather", 0.05)
	var base_glow: float = _get_shader_param("glow_strength", 1.25)
	var base_fill: float = _get_shader_param("fill_strength", 0.18)
	var base_flash: float = _get_shader_param("edge_flash_strength", 0.45)
	var base_noise: float = _get_shader_param("noise_intensity", 0.02)
	var base_scanlines: float = _get_shader_param("scanline_intensity", 0.05)
	var base_refraction: float = _get_shader_param("refraction_strength", 0.05)
	var base_glitch: float = _get_shader_param("glitch_intensity", 0.0)
	var base_secondary_offset: float = _get_shader_param("secondary_radius_offset", 0.05)
	var base_ripple_strength: float = _get_shader_param("ripple_strength", 0.018)
	var base_ripple_density: float = _get_shader_param("ripple_density", 16.0)
	var base_swirl: float = _get_shader_param("swirl_strength", 0.006)

	var response_boost = response_strength * response_intensity_scale
	var heat_boost = heat_strength * heat_intensity_scale

	var live_color = base_color
	live_color = live_color.lerp(Color(0.25, 1.0, 0.84, live_color.a), response_boost * 0.35)
	live_color = live_color.lerp(Color(1.0, 0.48, 0.24, live_color.a), heat_boost * 0.45)

	var live_thickness = max(base_thickness * (1.0 + response_boost * 0.45 + heat_boost * 0.18), 0.001)
	var live_feather = max(base_feather * (1.0 + response_boost * 0.2 + heat_boost * 0.12), 0.001)
	var live_glow = max(base_glow * (1.0 + response_boost * 0.35 + heat_boost * 0.3), 0.0)
	var live_fill = max(base_fill * (1.0 + response_boost * 0.28), 0.0)
	var live_flash = max(base_flash * (1.0 + heat_boost * 0.5), 0.0)
	var live_noise = max(base_noise * (1.0 + response_boost * 0.2 + heat_boost * 0.28), 0.0)
	var live_scanlines = max(base_scanlines * (1.0 + heat_boost * 0.2), 0.0)
	var live_refraction = max(base_refraction * (1.0 + response_boost * 0.18 + heat_boost * 0.32), 0.0)
	var live_glitch = max(base_glitch * (1.0 + heat_boost * 0.45), 0.0)
	var live_secondary_offset = max(base_secondary_offset * (1.0 + response_boost * 0.15), 0.0)
	var live_ripple_strength = max(base_ripple_strength * (1.0 + response_boost * 0.18 + heat_boost * 0.12), 0.0)
	var live_ripple_density = max(base_ripple_density * (1.0 + response_boost * 0.08 + heat_boost * 0.1), 1.0)
	var live_swirl = max(base_swirl * (1.0 + heat_boost * 0.2), 0.0)

	material.set_shader_parameter("color", live_color)
	material.set_shader_parameter("radius", 0.0)
	material.set_shader_parameter("thickness", live_thickness)
	material.set_shader_parameter("feather", live_feather)
	material.set_shader_parameter("glow_strength", live_glow)
	material.set_shader_parameter("fill_strength", live_fill)
	material.set_shader_parameter("edge_flash_strength", live_flash)
	material.set_shader_parameter("noise_intensity", live_noise)
	material.set_shader_parameter("scanline_intensity", live_scanlines)
	material.set_shader_parameter("refraction_strength", live_refraction)
	material.set_shader_parameter("glitch_intensity", live_glitch)
	material.set_shader_parameter("secondary_radius_offset", live_secondary_offset)
	material.set_shader_parameter("ripple_strength", live_ripple_strength)
	material.set_shader_parameter("ripple_density", live_ripple_density)
	material.set_shader_parameter("swirl_strength", live_swirl)

	scale = spawn_scale
	rotation = randf_range(-rotation_jitter, rotation_jitter)

	var tween = create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)

	var target_radius_param = max_radius / pulse_size
	tween.tween_property(material, "shader_parameter/radius", target_radius_param, duration).from(0.0)
	tween.tween_property(material, "shader_parameter/thickness", max(base_thickness * 0.9, 0.001), duration)
	tween.tween_property(material, "shader_parameter/glow_strength", base_glow * 0.35, duration)
	tween.tween_property(material, "shader_parameter/fill_strength", base_fill * 0.15, duration)
	tween.tween_property(material, "shader_parameter/edge_flash_strength", base_flash * 0.1, duration * 0.75)
	tween.tween_property(material, "shader_parameter/refraction_strength", base_refraction * 0.2, duration)
	tween.tween_property(material, "shader_parameter/noise_intensity", base_noise * 0.4, duration)
	tween.tween_property(material, "shader_parameter/glitch_intensity", base_glitch * 0.35, duration * 0.6)
	tween.tween_property(self, "scale", scale_punch, duration)

	var target_color = live_color
	target_color.a = 0.0
	tween.tween_property(material, "shader_parameter/color", target_color, duration).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)

	tween.chain().tween_callback(queue_free)

func _get_shader_param(param_name: StringName, fallback):
	if material == null:
		return fallback
	var value = material.get_shader_parameter(param_name)
	return fallback if value == null else value

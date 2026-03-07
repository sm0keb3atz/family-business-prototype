@tool
extends Node2D

@export var radius: float = 200.0:
	set(v):
		radius = v
		_update_sprite_size()

@export var fill_color: Color = Color(1, 0, 0, 0.2):
	set(v):
		fill_color = v
		_update_shader_color()

var _sprite: Sprite2D = null
var _shader_mat: ShaderMaterial = null

func _ready() -> void:
	_setup_radar_visual()

func _setup_radar_visual() -> void:
	# Create a white square texture to act as the shader canvas
	var img: Image = Image.create(2, 2, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	var tex: ImageTexture = ImageTexture.create_from_image(img)

	# Build shader material
	var shader: Shader = preload("res://GAME/assets/shaders/radar_sweep.gdshader")
	_shader_mat = ShaderMaterial.new()
	_shader_mat.shader = shader
	_shader_mat.set_shader_parameter("sweep_color", Color(fill_color.r, fill_color.g, fill_color.b, 1.0))
	_shader_mat.set_shader_parameter("sweep_speed", 2.0)
	_shader_mat.set_shader_parameter("trail_length", 1.2)
	_shader_mat.set_shader_parameter("base_alpha", 0.12)
	_shader_mat.set_shader_parameter("sweep_glow", 0.6)

	# Create sprite
	_sprite = Sprite2D.new()
	_sprite.texture = tex
	_sprite.material = _shader_mat
	add_child(_sprite)

	# Render below the police officer sprite
	z_index = -1

	_update_sprite_size()

func _update_sprite_size() -> void:
	if _sprite:
		# Scale the 2×2 px texture up to cover the full detection diameter
		var diameter: float = radius * 2.0
		_sprite.scale = Vector2(diameter / 2.0, diameter / 2.0)

func _update_shader_color() -> void:
	if _shader_mat:
		_shader_mat.set_shader_parameter("sweep_color", Color(fill_color.r, fill_color.g, fill_color.b, 1.0))

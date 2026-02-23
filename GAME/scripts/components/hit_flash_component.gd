extends Node
class_name HitFlashComponent

@export var target_node: CanvasItem
@export var flash_color: Color = Color(1.0, 0.0, 0.0, 1.0)
@export var flash_time: float = 0.1

var _material: ShaderMaterial
var _tween: Tween

func _ready() -> void:
	if not target_node:
		push_warning("HitFlashComponent: No target_node assigned.")
		return
		
	_material = ShaderMaterial.new()
	_material.shader = preload("res://GAME/assets/shaders/hit_flash.gdshader")
	_material.set_shader_parameter("flash_color", flash_color)
	_material.set_shader_parameter("flash_modifier", 0.0)
	
	target_node.material = _material
	_apply_use_parent_material(target_node)

func _apply_use_parent_material(node: Node) -> void:
	for child in node.get_children():
		if child is CanvasItem:
			child.use_parent_material = true
		_apply_use_parent_material(child)

func flash() -> void:
	if not _material:
		return
		
	if _tween and _tween.is_valid():
		_tween.kill()
	
	_material.set_shader_parameter("flash_modifier", 1.0)
	_tween = create_tween()
	_tween.tween_method(_set_flash_modifier, 1.0, 0.0, flash_time)

func _set_flash_modifier(value: float) -> void:
	_material.set_shader_parameter("flash_modifier", value)

extends Node2D
class_name FloatingIndicator

@onready var icon: TextureRect = $HBoxContainer/Icon
@onready var container: HBoxContainer = $HBoxContainer
@onready var text_node: Label = $HBoxContainer/Text

var _forced_angle: float = NAN
var _forced_distance: float = NAN

func set_forced_angle(angle_rad: float) -> void:
	_forced_angle = angle_rad

func set_forced_distance(dist: float) -> void:
	_forced_distance = dist

func _ready() -> void:
	# Random direction in an upward arc, or use forced angle if provided
	var angle: float
	if not is_nan(_forced_angle):
		angle = _forced_angle
	else:
		angle = randf_range(-PI * 0.48, PI * 0.48) - PI / 2.0 # Maximum Upward cone
		
	var distance: float
	if not is_nan(_forced_distance):
		distance = _forced_distance
	else:
		distance = randf_range(90.0, 150.0) # Much more distance
		
	var target_offset = Vector2(cos(angle), sin(angle)) * distance
	
	# Initial state
	modulate.a = 0.0
	scale = Vector2(0.2, 0.2)
	
	var tween = create_tween().set_parallel(true)
	
	# Burst movement
	tween.tween_property(self, "position", position + target_offset, 1.4).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	
	# Scale punch
	tween.tween_property(self, "scale", Vector2(1.5, 1.5), 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.chain().tween_property(self, "scale", Vector2(1.0, 1.0), 0.1)
	
	# Fade logic
	var fade_tween = create_tween()
	fade_tween.tween_property(self, "modulate:a", 1.0, 0.05)
	fade_tween.tween_interval(0.7) # visible for a bit
	fade_tween.tween_property(self, "modulate:a", 0.0, 0.6) # long fade while moving
	
	# Free when done
	tween.finished.connect(queue_free)

func setup(text: String, color: Color, p_icon: Texture2D = null) -> void:
	# Ensure nodes are ready
	if not is_node_ready():
		await ready
		
	text_node.text = text
	text_node.add_theme_color_override("font_color", color)
	
	if p_icon:
		icon.texture = p_icon
		icon.show()
	else:
		icon.hide()

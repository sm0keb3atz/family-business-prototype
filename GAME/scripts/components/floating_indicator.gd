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
		angle = randf_range(-PI * 0.35, PI * 0.35) - PI / 2.0 # Focused upward arc
		
	var distance: float
	if not is_nan(_forced_distance):
		distance = _forced_distance
	else:
		distance = randf_range(70.0, 100.0) # Slightly more controlled distance
		
	var target_offset = Vector2(cos(angle), sin(angle)) * distance
	
	# Initial state
	modulate.a = 0.0
	scale = Vector2(0.5, 0.5)
	rotation = randf_range(-0.1, 0.1)
	
	# Total move duration
	var move_duration = randf_range(1.1, 1.3)
	
	# 1. Main Movement Tween (Smooth Glide)
	var move_tween = create_tween().set_parallel(true)
	move_tween.tween_property(self, "position", position + target_offset, move_duration).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	move_tween.tween_property(self, "rotation", rotation * 2.0, move_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	# 2. Scale Pop sequence
	var scale_tween = create_tween()
	scale_tween.tween_property(self, "scale", Vector2(1.4, 1.4), 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	scale_tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.1).set_trans(Tween.TRANS_SINE)
	
	# 3. Alpha / Fade Logic (Explicitly finished before move_duration)
	var fade_tween = create_tween()
	fade_tween.tween_property(self, "modulate:a", 1.0, 0.05)
	fade_tween.tween_interval(move_duration * 0.6) # Visible for 60% of the movement duration
	fade_tween.tween_property(self, "modulate:a", 0.0, move_duration * 0.3).set_ease(Tween.EASE_IN) # Fades out over next 30%
	# Total Fade Logic = 0.05 + 0.6*1.2 + 0.3*1.2 (approx) = 0.05 + 0.72 + 0.36 = 1.13s (finished before 1.2s move ends)
	
	# Free when movement is finally over (ensures we don't leak nodes if they fade early)
	move_tween.finished.connect(queue_free)

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

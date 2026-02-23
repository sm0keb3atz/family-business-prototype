extends Control
class_name NpcUI

@onready var health_bar = $HealthBar
@onready var type_icon = $TypeIcon
@onready var dialog_bubble = $DialogBubble

func _ready():
	# Initially hide everything or just dialog bubble
	if dialog_bubble:
		dialog_bubble.hide()
	if type_icon:
		type_icon.hide()
	if health_bar:
		health_bar.hide()


func update_health(current_health: float, max_health: float):
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health
		if current_health < max_health:
			health_bar.show()
		else:
			health_bar.hide()


func set_type_icon(texture: Texture2D):
	if type_icon:
		type_icon.texture = texture

func show_dialog_bubble(text: String):
	if dialog_bubble:
		dialog_bubble.text = text
		dialog_bubble.show()


func hide_dialog_bubble():
	if dialog_bubble:
		dialog_bubble.hide()

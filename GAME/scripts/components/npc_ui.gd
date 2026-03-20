extends Control
class_name NpcUI

@onready var health_bar = $HealthBar
@onready var type_icon = $TypeIcon
@onready var dialog_bubble = $DialogBubble
@onready var dialog_label = $DialogBubble/Label
@onready var animation_player = $AnimationPlayer
@onready var arrest_bar = get_node_or_null("ArrestBar")

var FLOATING_INDICATOR = load("res://GAME/scenes/components/floating_indicator.tscn")
const WEED_ICON = preload("res://GAME/assets/icons/WeedBaggie.png")
const BRICK_ICON = preload("res://GAME/assets/icons/WeedBrick.png")
const MONEY_ICON = preload("res://GAME/assets/icons/money.png")

var _last_indicator_index: int = 0
var _last_spawn_time: int = 0

func _ready():
	# Initially hide everything or just dialog bubble
	if dialog_bubble:
		dialog_bubble.hide()
	if type_icon:
		type_icon.hide()
	if health_bar:
		health_bar.hide()
	if arrest_bar:
		arrest_bar.hide()
	if has_node("LevelLabel"):
		$LevelLabel.hide()


func update_health(current_health: float, max_health: float):
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health
		if current_health < max_health:
			health_bar.show()
		else:
			health_bar.hide()

func update_arrest_progress(value: float):
	if arrest_bar:
		arrest_bar.value = value * 100.0
		if value > 0:
			arrest_bar.show()
		else:
			arrest_bar.hide()


func set_type_icon(texture: Texture2D):
	if type_icon:
		type_icon.texture = texture

func show_type_icon(texture: Texture2D = null):
	if texture:
		set_type_icon(texture)
	if type_icon:
		type_icon.show()
	if has_node("LevelLabel") and not $LevelLabel.text.is_empty():
		$LevelLabel.show()
	if animation_player and animation_player.has_animation("icon"):
		animation_player.play("icon")

func hide_type_icon():
	if type_icon:
		type_icon.hide()
	if has_node("LevelLabel"):
		$LevelLabel.hide()
	if animation_player:
		animation_player.stop()

func update_level(level: int, role: int) -> void:
	var level_label = get_node_or_null("LevelLabel")
	if not level_label: return
	
	if role == 1: # Role.DEALER
		level_label.text = "LVL " + str(level)
		level_label.modulate = Color.YELLOW
		level_label.show()
	elif role == -1: # Special case for Girlfriend
		level_label.text = "LVL " + str(level)
		level_label.modulate = Color.PINK
		level_label.show()
	else:
		level_label.hide()

func show_dialog_bubble(text: String):
	if dialog_bubble and dialog_label:
		dialog_label.text = text
		dialog_bubble.show()
		# Boost Z-index when speaking to ensure visibility over other NPCs
		z_index = 10


func hide_dialog_bubble():
	if dialog_bubble:
		dialog_bubble.hide()
		# Reset Z-index
		z_index = 0

func spawn_indicator(type: String, value: String, custom_icon: Texture2D = null):
	var indicator = FLOATING_INDICATOR.instantiate()
	
	# Detect if multiple are spawning at once (within 100ms)
	var now = Time.get_ticks_msec()
	if now - _last_spawn_time > 100:
		_last_indicator_index = 0
	else:
		_last_indicator_index += 1
	_last_spawn_time = now
	
	# Tiered angles and distances to create a perfect fan that never overlaps
	var angles = [0.0, -0.4, 0.4, -0.7, 0.7]
	var distances = [90.0, 120.0, 100.0, 130.0, 110.0]
	
	var use_angle = angles[_last_indicator_index % angles.size()]
	var use_dist = distances[_last_indicator_index % distances.size()]
		
	add_child(indicator)
	
	# Position closer to character center for "move away" effect
	indicator.position = Vector2(0, -10)
	
	if indicator.has_method("set_forced_angle"):
		indicator.set_forced_angle(use_angle - PI/2.0)
	if indicator.has_method("set_forced_distance"):
		indicator.set_forced_distance(use_dist)
	
	var color = Color.WHITE
	var use_icon = custom_icon
	
	match type:
		"damage":
			color = Color.RED
		"xp":
			color = Color(0.0, 0.8, 1.0) # More Vibrant Cyan-Blue
		"money_up":
			color = Color.GREEN
			if not use_icon:
				use_icon = MONEY_ICON
		"money_down":
			color = Color.RED
			if not use_icon:
				use_icon = MONEY_ICON
		"product":
			color = Color.WHITE
			if not use_icon:
				if "brick" in value.to_lower():
					use_icon = BRICK_ICON
				else:
					use_icon = WEED_ICON
				
	indicator.setup(value, color, use_icon)

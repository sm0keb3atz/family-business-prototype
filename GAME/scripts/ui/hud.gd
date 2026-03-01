extends CanvasLayer
class_name HUD

@onready var health_bar: ProgressBar = $Hud/HealthBar
@onready var xp_bar: ProgressBar = $Hud/XPBar
@onready var money_label: Label = $Hud/MoneyLabel
@onready var heat_bar: ProgressBar = $Hud/HeatBar
@onready var stars_container: HBoxContainer = $Hud/StarsContainer

var player: Player
var star_texture = preload("res://GAME/assets/ui/wanted_star.png")

func _ready() -> void:
	# Add nodes dynamically since the original tscn was just a TextureRect
	_setup_ui_nodes()
	
	# Try to find player
	# Connect to health
	if player:
		if player.health_component:
			player.health_component.health_changed.connect(_on_health_changed)
			_on_health_changed(player.health_component.current_health, player.health_component.stats.max_health if player.health_component.stats else 100)
			
	# Connect to HeatManager
	if has_node("/root/HeatManager"):
		var hm = get_node("/root/HeatManager")
		hm.heat_changed.connect(_on_heat_changed)
		hm.stars_changed.connect(_on_stars_changed)
		_on_heat_changed(hm.heat_value)
		_on_stars_changed(hm.wanted_stars)

func _setup_ui_nodes() -> void:
	# Note: This is a bit of a hack since we are adding UI elements programmatically
	# instead of replacing the scene to keep it simple, but we can do it!
	pass

func _process(_delta: float) -> void:
	if not player:
		player = get_tree().get_first_node_in_group("player")
		return
		
	# Update Money and XP dynamically for now
	if is_instance_valid(money_label) and player.progression:
		money_label.text = "$" + str(player.progression.money)
	
	if is_instance_valid(xp_bar) and player.progression:
		# Assuming 1000 xp per level for demo
		var current_xp = player.progression.xp % 1000
		xp_bar.value = current_xp

func _on_heat_changed(value: float) -> void:
	if is_instance_valid(heat_bar):
		heat_bar.value = value

func _on_health_changed(current: int, maximum: int) -> void:
	if is_instance_valid(health_bar):
		health_bar.max_value = maximum
		health_bar.value = current

func _on_stars_changed(count: int) -> void:
	if not is_instance_valid(stars_container):
		return
		
	# Clear existing
	for child in stars_container.get_children():
		child.queue_free()
		
	# Add new stars
	for i in range(count):
		var star = TextureRect.new()
		star.texture = star_texture
		star.expand_mode = TextureRect.EXPAND_KEEP_SIZE
		star.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		star.custom_minimum_size = Vector2(32, 32)
		stars_container.add_child(star)

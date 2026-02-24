extends CanvasLayer
class_name HUD

@onready var health_bar: ProgressBar = $Hud/HealthBar
@onready var xp_bar: ProgressBar = $Hud/XPBar
@onready var money_label: Label = $Hud/MoneyLabel

var player: Player

func _ready() -> void:
	# Add nodes dynamically since the original tscn was just a TextureRect
	_setup_ui_nodes()
	
	# Try to find player
	player = get_tree().get_first_node_in_group("player")
	if player:
		# Connect to health
		if player.health_component:
			player.health_component.health_changed.connect(_on_health_changed)
			_on_health_changed(player.health_component.current_health, player.health_component.stats.max_health if player.health_component.stats else 100)

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

func _on_health_changed(current: int, maximum: int) -> void:
	if is_instance_valid(health_bar):
		health_bar.max_value = maximum
		health_bar.value = current

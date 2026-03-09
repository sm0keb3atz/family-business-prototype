extends CanvasLayer
class_name HUD

@onready var health_bar: ProgressBar = $Hud/HealthBar
@onready var xp_bar: ProgressBar = $Hud/XPBar
@onready var money_label: Label = $Hud/MoneyLabel
@onready var heat_bar: ProgressBar = $Hud/HeatBar
@onready var stars_container: Control = $Hud/StarsContainer

@onready var weapon_icon: Sprite2D = $Hud/WeaponIcon
@onready var level_label: Label = $Hud/LevelLabel
@onready var ammo_label: Label = $Hud/AmmoLabel
@onready var unarmed_label: Label = $Hud/UnarmedLabel

var player: Player
var star_nodes: Array[AnimatedSprite2D] = []
var displayed_money: float = 0.0
var current_weapon: WeaponBase

func _ready() -> void:
	# Add nodes dynamically since the original tscn was just a TextureRect
	_setup_ui_nodes()
	
	# Try to find player
	# Connect to health
	# player initialization moved to _process
			
	# Connect to HeatManager
	if has_node("/root/HeatManager"):
		var hm = get_node("/root/HeatManager")
		hm.heat_changed.connect(_on_heat_changed)
		hm.stars_changed.connect(_on_stars_changed)
		_on_heat_changed(hm.heat_value)
		_on_stars_changed(hm.wanted_stars)

func _setup_ui_nodes() -> void:
	if is_instance_valid(stars_container):
		for child in stars_container.get_children():
			if child is AnimatedSprite2D:
				# They are pre-placed in the editor now
				star_nodes.append(child)

func _process(delta: float) -> void:
	if not player:
		player = get_tree().get_first_node_in_group("player")
		if player:
			# Initial Setup when player is first found
			if player.health_component:
				player.health_component.health_changed.connect(_on_health_changed)
				_on_health_changed(player.health_component.current_health, player.health_component.stats.max_health if player.health_component.stats else 100)
			
			if not player.weapon_changed.is_connected(_on_weapon_changed):
				player.weapon_changed.connect(_on_weapon_changed)
			
			if player.weapon_holder_component and player.weapon_holder_component.current_weapon:
				_on_weapon_changed(player.weapon_holder_component.current_weapon)

			if player.progression:
				displayed_money = float(player.progression.money)
				if is_instance_valid(money_label):
					money_label.text = "$" + str(roundi(displayed_money))
		return
		
	# Update Money and XP dynamically for now
	if is_instance_valid(money_label) and player.progression:
		var target_money: float = float(player.progression.money)
		if abs(displayed_money - target_money) > 0.5:
			displayed_money = lerp(displayed_money, target_money, 5.0 * delta)
		else:
			displayed_money = target_money
			
		money_label.text = "$" + str(roundi(displayed_money))
	
	if is_instance_valid(xp_bar) and player.progression:
		# Assuming 1000 xp per level for demo
		var current_xp = player.progression.xp % 1000
		xp_bar.value = current_xp

	_update_stars_animation()

func _on_heat_changed(value: float) -> void:
	if is_instance_valid(heat_bar):
		heat_bar.value = value

func _on_health_changed(current: int, maximum: int) -> void:
	if is_instance_valid(health_bar):
		health_bar.max_value = maximum
		health_bar.value = current

func _update_stars_animation() -> void:
	if not has_node("/root/HeatManager") or star_nodes.is_empty():
		return
		
	var hm = get_node("/root/HeatManager")
	var wanted = hm.wanted_stars
	var unseen = hm.unseen_timer
	
	# Assume HeatConfig.STAR_DROP_TIME is 12.0 or 10.0 (user said 10, script says 12, we'll use script value dynamically)
	var max_timer = 10.0
	if hm.has_node("/root/HeatConfig") or ClassDB.class_exists("HeatConfig"):
		# Or hardcode property if it doesn't work dynamically
		max_timer = HeatConfig.STAR_DROP_TIME
		
	for i in range(star_nodes.size()):
		if i < wanted - 1:
			# Fully filled star
			star_nodes[i].frame = 4
		elif i == wanted - 1:
			# Currently draining star
			# If player is detected, unseen is 0, so fullness is 1 (frame 4)
			# As unseen approaches max_timer, fullness approaches 0 (frame 0)
			var fullness = clampf(1.0 - (unseen / max_timer), 0.0, 1.0)
			var frame_idx = clampi(round(fullness * 4.0), 0, 4)
			star_nodes[i].frame = frame_idx
		else:
			# Empty star
			star_nodes[i].frame = 0

func _on_stars_changed(count: int) -> void:
	# Keep existing signal but let process animate them
	pass

func _on_weapon_changed(weapon: WeaponBase) -> void:
	if not weapon:
		if is_instance_valid(level_label): level_label.visible = false
		if is_instance_valid(weapon_icon): weapon_icon.visible = false
		if is_instance_valid(ammo_label): ammo_label.visible = false
		if is_instance_valid(unarmed_label): unarmed_label.visible = true
		return
	
	if is_instance_valid(level_label): level_label.visible = true
	if is_instance_valid(weapon_icon): weapon_icon.visible = true
	if is_instance_valid(ammo_label): ammo_label.visible = true
	if is_instance_valid(unarmed_label): unarmed_label.visible = false
		
	# Disconnect from old weapon
	if current_weapon and is_instance_valid(current_weapon) and current_weapon.ammo_component:
		if current_weapon.ammo_component.ammo_changed.is_connected(_on_ammo_changed):
			current_weapon.ammo_component.ammo_changed.disconnect(_on_ammo_changed)
			
	current_weapon = weapon
	
	# Connect to new weapon
	if current_weapon.ammo_component:
		current_weapon.ammo_component.ammo_changed.connect(_on_ammo_changed)
		_on_ammo_changed(current_weapon.ammo_component.current_ammo, current_weapon.ammo_component.reserve_ammo)
		
	# Update level label
	if is_instance_valid(level_label):
		var level = weapon.weapon_data.level
		level_label.text = "LVL " + str(level)
		
		# Blue for 1, Green for 2, Orange for 3, Purple for 4
		var color = Color.WHITE
		match level:
			1: color = Color.SKY_BLUE
			2: color = Color.GREEN
			3: color = Color.ORANGE
			4: color = Color.PURPLE
		level_label.modulate = color
		
	# Update Icon
	if is_instance_valid(weapon_icon):
		weapon_icon.texture = weapon.weapon_data.weapon_sprite
		if weapon_icon.has_method("set_frame"):
			weapon_icon.frame = 0

func _on_ammo_changed(current: int, reserve: int) -> void:
	if is_instance_valid(ammo_label):
		ammo_label.text = str(current) + "/" + str(reserve)

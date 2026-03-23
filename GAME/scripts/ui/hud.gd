extends CanvasLayer
class_name HUD

@onready var health_bar: ProgressBar = $Hud/HealthBar
@onready var xp_bar: ProgressBar = $Hud/XPBar
@onready var money_label: Label = $Hud/MoneyLabel
@onready var heat_bar: ProgressBar = $Hud/HeatBar
@onready var heat_buff_label: Label = $Hud/HeatBuffLabel
@onready var stars_container: Control = $Hud/StarsContainer
@onready var territory_rep_bar: ProgressBar = $Hud/TerritoryReputationBar
@onready var territory_name_label: Label = $Hud/TerritoryNameLabel
@onready var prices_label: Label = $Hud/PricesLabel
@onready var clock_label: Label = $Hud/ClockLabel
@onready var date_label: Label = $Hud/DateLabel

@onready var weapon_icon: Sprite2D = $Hud/WeaponIcon
@onready var level_label: Label = $Hud/LevelLabel
@onready var ammo_label: Label = $Hud/AmmoLabel
@onready var unarmed_label: Label = $Hud/UnarmedLabel
@onready var player_level_label: Label = $Hud/PlayerLevelLabel

var player: Player
var star_nodes: Array[AnimatedSprite2D] = []
var displayed_money: float = 0.0
var current_weapon: WeaponBase
var current_territory: TerritoryArea
var territory_tracking_ready: bool = false

func _ready() -> void:
	# Add nodes dynamically since the original tscn was just a TextureRect
	_setup_ui_nodes()
	_reset_territory_ui()
	
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
	
	# Connect to TimeManager
	var tm = get_tree().get_first_node_in_group("time_manager")
	if tm:
		tm.time_updated.connect(_on_time_updated)
		tm.date_updated.connect(_on_date_updated)
		_on_time_updated(tm.current_hour, tm.current_minute)
		_on_date_updated(tm.current_day, tm.current_month, tm.current_year)

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

			if player.get("progression"):
				displayed_money = float(player.get("progression").get("money"))
				if is_instance_valid(money_label):
					money_label.text = "$" + str(roundi(displayed_money))
			
			_setup_territory_tracking()
			
			# Also check for TimeManager if not found in _ready
			var tm = get_tree().get_first_node_in_group("time_manager")
			if tm and not tm.time_updated.is_connected(_on_time_updated):
				tm.time_updated.connect(_on_time_updated)
				tm.date_updated.connect(_on_date_updated)
				_on_time_updated(tm.current_hour, tm.current_minute)
				_on_date_updated(tm.current_day, tm.current_month, tm.current_year)
		return
		
	# Update Money and XP dynamically for now
	if is_instance_valid(money_label) and player.get("progression"):
		var target_money: float = float(player.get("progression").get("money"))
		if abs(displayed_money - target_money) > 0.5:
			displayed_money = lerp(displayed_money, target_money, 5.0 * delta)
		else:
			displayed_money = target_money
			
		money_label.text = "$" + str(roundi(displayed_money))
	
	if is_instance_valid(xp_bar) and player.get("progression"):
		var current_xp = player.get("progression").get("xp")
		var required_xp = player.get("progression").get_required_xp()
		xp_bar.max_value = required_xp
		xp_bar.value = current_xp
		
		if is_instance_valid(player_level_label):
			player_level_label.text = "Level %d  %d/%d XP" % [player.get("progression").get("level"), current_xp, required_xp]

	_refresh_current_territory()
	_update_stars_animation()

	# Update Heat Decay Buff Label
	if is_instance_valid(heat_buff_label) and has_node("/root/HeatManager"):
		var hm = get_node("/root/HeatManager")
		if hm.has_method("get_gf_heat_multiplier"):
			var mult: float = hm.get_gf_heat_multiplier()
			if is_equal_approx(mult, 1.0):
				# Hide if neutral
				heat_buff_label.text = ""
			else:
				var percent: int = roundi((mult - 1.0) * 100.0)
				if percent > 0:
					heat_buff_label.text = "Decay Speed: +%d%%" % percent
					heat_buff_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4)) # Greenish
				else:
					heat_buff_label.text = "Decay Speed: %d%%" % percent
					heat_buff_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4)) # Reddish

func _setup_territory_tracking() -> void:
	if territory_tracking_ready:
		return
	territory_tracking_ready = true
	
	for territory in get_tree().get_nodes_in_group("territories"):
		if territory is TerritoryArea:
			if not territory.body_entered.is_connected(_on_territory_body_entered):
				territory.body_entered.connect(_on_territory_body_entered.bind(territory))
			if not territory.body_exited.is_connected(_on_territory_body_exited):
				territory.body_exited.connect(_on_territory_body_exited.bind(territory))
			if player and territory.get_overlapping_bodies().has(player):
				_set_current_territory(territory)

func _refresh_current_territory() -> void:
	if not player:
		return
	var found: TerritoryArea = null
	for node in get_tree().get_nodes_in_group("territories"):
		if node is TerritoryArea and node.get_overlapping_bodies().has(player):
			found = node
			break
	if found:
		_set_current_territory(found)
	else:
		if current_territory:
			_clear_current_territory()

func _on_territory_body_entered(body: Node2D, territory: TerritoryArea) -> void:
	if not player or body != player:
		return
	_set_current_territory(territory)

func _on_territory_body_exited(body: Node2D, territory: TerritoryArea) -> void:
	if not player or body != player:
		return
	if current_territory == territory and not territory.get_overlapping_bodies().has(body):
		_clear_current_territory()

func _set_current_territory(territory: TerritoryArea) -> void:
	if current_territory == territory:
		return
	_disconnect_reputation()
	current_territory = territory
	_connect_reputation()
	_update_territory_ui()

func _clear_current_territory() -> void:
	_disconnect_reputation()
	current_territory = null
	_reset_territory_ui()

func _connect_reputation() -> void:
	if current_territory and current_territory.reputation_component:
		if not current_territory.reputation_component.reputation_changed.is_connected(_on_reputation_changed):
			current_territory.reputation_component.reputation_changed.connect(_on_reputation_changed)
		_on_reputation_changed(current_territory.reputation_component.get_reputation())

func _disconnect_reputation() -> void:
	if current_territory and current_territory.reputation_component:
		if current_territory.reputation_component.reputation_changed.is_connected(_on_reputation_changed):
			current_territory.reputation_component.reputation_changed.disconnect(_on_reputation_changed)

func _on_reputation_changed(value: float) -> void:
	if is_instance_valid(territory_rep_bar):
		territory_rep_bar.value = _reputation_to_bar(value)

func _reputation_to_bar(value: float) -> float:
	return clampf((value + 100.0) * 0.5, 0.0, 100.0)

func _update_territory_ui() -> void:
	if not current_territory or not current_territory.territory_data:
		_reset_territory_ui()
		return
	
	if is_instance_valid(territory_name_label):
		territory_name_label.text = "Territory: " + current_territory.territory_data.display_name
	
	if is_instance_valid(prices_label):
		var weed_price = current_territory.get_drug_price(&"weed")
		prices_label.text = "Prices: $" + str(weed_price) + "/g"
	
	_on_reputation_changed(current_territory.reputation_component.get_reputation() if current_territory.reputation_component else 0.0)

func _reset_territory_ui() -> void:
	if is_instance_valid(territory_name_label):
		territory_name_label.text = "Territory: Neutral"
	if is_instance_valid(prices_label):
		prices_label.text = "Prices: Normal"
	if is_instance_valid(territory_rep_bar):
		territory_rep_bar.value = 50.0

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

func _on_time_updated(hours: int, minutes: int) -> void:
	if is_instance_valid(clock_label):
		var am_pm = "AM"
		var display_hour = hours
		if display_hour >= 12:
			am_pm = "PM"
			if display_hour > 12:
				display_hour -= 12
		if display_hour == 0:
			display_hour = 12
		
		clock_label.text = "%d:%02d %s" % [display_hour, minutes, am_pm]

func _on_date_updated(day: int, month: int, year: int) -> void:
	if is_instance_valid(date_label):
		var months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
		var month_str = months[(month - 1) % 12]
		date_label.text = "%s %d, %d" % [month_str, day, year]

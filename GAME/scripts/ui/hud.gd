extends CanvasLayer
class_name HUD

@onready var health_bar: ProgressBar = %HealthBar
@onready var xp_bar: ProgressBar = %XPBar
@onready var money_label: Label = %MoneyLabel
@onready var clean_money_label: Label = %CleanMoneyLabel
@onready var debt_label: Label = %DebtLabel
@onready var heat_bar: ProgressBar = %HeatBar
@onready var heat_buff_label: Label = %HeatBuffLabel
@onready var stars_container: Control = %StarsContainer
@onready var territory_rep_bar: ProgressBar = %TerritoryReputationBar
@onready var territory_name_label: Label = %TerritoryNameLabel
@onready var prices_label: Label = %PricesLabel
@onready var weed_price_icon: TextureRect = %WeedPriceIcon
@onready var weed_price_label: Label = %WeedPriceLabel
@onready var coke_price_icon: TextureRect = %CokePriceIcon
@onready var coke_price_label: Label = %CokePriceLabel
@onready var fetty_price_icon: TextureRect = %FettyPriceIcon
@onready var fetty_price_label: Label = %FettyPriceLabel
@onready var clock_label: Label = %ClockLabel
@onready var date_label: Label = %DateLabel

@onready var weapon_icon: Sprite2D = %WeaponIcon
@onready var level_label: Label = %LevelLabel
@onready var ammo_label: Label = %AmmoLabel
@onready var unarmed_label: Label = %UnarmedLabel

# New split labels for player level
@onready var player_level_value_label: Label = %PlayerLevelValueLabel
@onready var player_xp_label: Label = %PlayerXPLabel

var player: Player
var star_nodes: Array[AnimatedSprite2D] = []
var displayed_money: float = 0.0
var displayed_clean_money: float = 0.0
var displayed_level: float = 1.0
var current_weapon: WeaponBase
var current_territory: TerritoryArea
var territory_tracking_ready: bool = false

func _ready() -> void:
	# Add nodes dynamically since the original tscn was just a TextureRect
	_setup_ui_nodes()
	_setup_economy_labels()
	_reset_territory_ui()
	_on_weapon_changed(null)
	
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

func _setup_economy_labels() -> void:
	# Hide clean/debt labels initially (they appear when values > 0)
	if is_instance_valid(clean_money_label):
		clean_money_label.visible = false
	if is_instance_valid(debt_label):
		debt_label.visible = false

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
			
			if player.weapon_holder_component:
				_on_weapon_changed(player.weapon_holder_component.current_weapon)

			if is_instance_valid(money_label):
				displayed_money = float(NetworkManager.economy.dirty_money)
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
		
	# Update Money display — dirty money with smooth lerp
	if is_instance_valid(money_label):
		var target_money: float = float(NetworkManager.economy.dirty_money)
		if abs(displayed_money - target_money) > 0.5:
			displayed_money = lerp(displayed_money, target_money, 5.0 * delta)
		else:
			displayed_money = target_money
		money_label.text = "$" + str(roundi(displayed_money))
	
	# Update clean money label with rolling effect
	if is_instance_valid(clean_money_label):
		var target_clean: float = float(NetworkManager.economy.clean_money)
		if abs(displayed_clean_money - target_clean) > 0.5:
			displayed_clean_money = lerp(displayed_clean_money, target_clean, 5.0 * delta)
		else:
			displayed_clean_money = target_clean
		clean_money_label.text = "$" + str(roundi(displayed_clean_money))
		clean_money_label.visible = NetworkManager.economy.clean_money > 0 or displayed_clean_money > 0.5
	
	# Update debt label
	if is_instance_valid(debt_label):
		# Debt display with smooth lerp could be added here if needed
		debt_label.text = "-$" + str(NetworkManager.economy.debt)
		debt_label.visible = NetworkManager.economy.debt > 0
	
	if is_instance_valid(xp_bar) and player.get("progression"):
		var current_xp = player.get("progression").get("xp")
		var required_xp = player.get("progression").get_required_xp()
		xp_bar.max_value = required_xp
		xp_bar.value = current_xp
		
		var level = player.get("progression").get("level")
		if is_instance_valid(player_level_value_label):
			var target_level: float = float(level)
			if abs(displayed_level - target_level) > 0.01:
				displayed_level = lerp(displayed_level, target_level, 5.0 * delta)
			else:
				displayed_level = target_level

			var display_val = roundi(displayed_level)
			player_level_value_label.text = str(display_val)

			# Dynamic font size based on digit count
			var new_size = 40
			if display_val >= 1000:
				new_size = 20
			elif display_val >= 100:
				new_size = 30
			elif display_val >= 10:
				new_size = 35

			# Only update if changed to avoid unnecessary theme updates
			if player_level_value_label.get_theme_font_size("font_size") != new_size:
				player_level_value_label.add_theme_font_size_override("font_size", new_size)

		if is_instance_valid(player_xp_label):

			player_xp_label.text = "%d/%d XP" % [current_xp, required_xp]

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
		prices_label.visible = false

	_set_price_entry(weed_price_icon, weed_price_label, &"weed")
	_set_price_entry(coke_price_icon, coke_price_label, &"coke")
	_set_price_entry(fetty_price_icon, fetty_price_label, &"fetty")
	
	_on_reputation_changed(current_territory.reputation_component.get_reputation() if current_territory.reputation_component else 0.0)

func _reset_territory_ui() -> void:
	if is_instance_valid(territory_name_label):
		territory_name_label.text = "Territory: Neutral"
	if is_instance_valid(prices_label):
		prices_label.visible = false
	_set_price_entry(weed_price_icon, weed_price_label, &"weed", false)
	_set_price_entry(coke_price_icon, coke_price_label, &"coke", false)
	_set_price_entry(fetty_price_icon, fetty_price_label, &"fetty", false)
	if is_instance_valid(territory_rep_bar):
		territory_rep_bar.value = 50.0

func _set_price_entry(icon_node: TextureRect, label_node: Label, drug_id: StringName, has_prices: bool = true) -> void:
	var definition := DrugCatalog.get_definition(drug_id)
	if icon_node:
		icon_node.texture = definition.gram_icon if definition else null
		icon_node.visible = has_prices
	if label_node:
		if has_prices and current_territory:
			label_node.text = "$%d/g" % current_territory.get_drug_price(drug_id)
		else:
			label_node.text = "$--/g"
		label_node.visible = has_prices

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
	
	# Assume HeatConfig.STAR_DROP_TIME is 12.0 or 10.0
	var max_timer = 10.0
	if hm.has_node("/root/HeatConfig") or ClassDB.class_exists("HeatConfig"):
		max_timer = HeatConfig.STAR_DROP_TIME
		
	for i in range(star_nodes.size()):
		if i < wanted - 1:
			# Fully filled star
			star_nodes[i].frame = 4
		elif i == wanted - 1:
			# Currently draining star
			var fullness = clampf(1.0 - (unseen / max_timer), 0.0, 1.0)
			var frame_idx = clampi(round(fullness * 4.0), 0, 4)
			star_nodes[i].frame = frame_idx
		else:
			# Empty star
			star_nodes[i].frame = 0

func _on_stars_changed(count: int) -> void:
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

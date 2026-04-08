extends CanvasLayer
class_name InventoryUI

@onready var tabs: TabContainer = $Control/PanelContainer/MarginContainer/VBoxContainer/TabContainer
@onready var drugs_list: VBoxContainer = %DrugsList
@onready var weapons_list: VBoxContainer = %WeaponsList
@onready var girlfriends_list: VBoxContainer = get_node_or_null("%GirlfriendsList")
@onready var skills_list: VBoxContainer = get_node_or_null("%SkillsList")
@onready var skill_points_label: Label = get_node_or_null("%SkillPointsLabel")
@onready var main_control: Control = $Control
@onready var territories_tab: Control = tabs.get_node_or_null("Territories")
@onready var properties_tab: Control = tabs.get_node_or_null("Properties")

var inventory_component: InventoryComponent
var player: Player
var _management_refresh_timer: float = 0.0

var _current_territory_title: Label
var _current_territory_details: Label
var _territory_support_status_label: Label
var _territory_support_selector: OptionButton
var _territory_assign_button: Button
var _territory_clear_support_button: Button
var _territory_control_button: Button
var _territory_hire_button: Button
var _territory_clear_button: Button
var _territory_collect_button: Button
var _territory_list: VBoxContainer

var _properties_summary_label: Label
var _properties_list: VBoxContainer
var _pending_support_selection_by_territory: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	main_control.hide()
	_build_territories_ui()
	_build_properties_ui()

func _process(delta: float) -> void:
	if not main_control.visible:
		return
	_management_refresh_timer -= delta
	if _management_refresh_timer > 0.0:
		return
	_management_refresh_timer = 0.35
	_refresh_management_ui()

func setup(component: InventoryComponent, p_player: Player = null) -> void:
	inventory_component = component
	player = p_player
	inventory_component.inventory_changed.connect(refresh_ui)
	inventory_component.girlfriends_changed.connect(refresh_ui)
	if player and player.progression:
		if not player.progression.skill_points_changed.is_connected(_on_progression_changed):
			player.progression.skill_points_changed.connect(_on_progression_changed)
		if not player.progression.skills_changed.is_connected(_on_skill_changed):
			player.progression.skills_changed.connect(_on_skill_changed)
	if not NetworkManager.territory_control_changed.is_connected(_on_territory_runtime_changed):
		NetworkManager.territory_control_changed.connect(_on_territory_runtime_changed)
	if not NetworkManager.hired_dealers_changed.is_connected(_on_territory_runtime_changed_simple):
		NetworkManager.hired_dealers_changed.connect(_on_territory_runtime_changed_simple)
	if not NetworkManager.territory_support_property_changed.is_connected(_on_territory_support_changed):
		NetworkManager.territory_support_property_changed.connect(_on_territory_support_changed)
	if not NetworkManager.property_purchased.is_connected(_on_property_purchased):
		NetworkManager.property_purchased.connect(_on_property_purchased)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory") or (event is InputEventKey and event.keycode == KEY_I and event.pressed and not event.echo):
		toggle_inventory()

func toggle_inventory() -> void:
	main_control.visible = !main_control.visible
	get_tree().paused = main_control.visible
	if main_control.visible:
		layer = 120
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		refresh_ui()

	AudioManager.play_ui_menu()

func refresh_ui() -> void:
	for child in drugs_list.get_children():
		child.queue_free()

	if not inventory_component:
		return

	for drug_id in inventory_component.bricks:
		var qty = inventory_component.bricks[drug_id]
		if qty <= 0:
			continue
		var definition := DrugCatalog.get_definition(drug_id)

		var h_box = HBoxContainer.new()
		drugs_list.add_child(h_box)

		if definition and definition.brick_icon:
			var icon_rect := TextureRect.new()
			icon_rect.custom_minimum_size = Vector2(32, 32)
			icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon_rect.texture = definition.brick_icon
			h_box.add_child(icon_rect)

		var label = Label.new()
		var display_name := definition.display_name if definition else str(drug_id).capitalize()
		var brick_grams := definition.brick_grams if definition else 100
		label.text = "%s Brick (%dg): %d" % [display_name, brick_grams, qty]
		h_box.add_child(label)

		var break_btn = Button.new()
		break_btn.text = "Break Down"
		break_btn.pressed.connect(func():
			if inventory_component.break_brick(drug_id):
				refresh_ui()
		)
		h_box.add_child(break_btn)

	for drug_id in inventory_component.drugs:
		var qty = inventory_component.drugs[drug_id]
		var definition := DrugCatalog.get_definition(drug_id)
		var h_box = HBoxContainer.new()
		drugs_list.add_child(h_box)

		if definition and definition.gram_icon:
			var icon_rect := TextureRect.new()
			icon_rect.custom_minimum_size = Vector2(32, 32)
			icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon_rect.texture = definition.gram_icon
			h_box.add_child(icon_rect)

		var label = Label.new()
		var display_name := definition.display_name if definition else str(drug_id).capitalize()
		label.text = "%s: %dg" % [display_name, qty]
		h_box.add_child(label)

	if girlfriends_list:
		for child in girlfriends_list.get_children():
			child.queue_free()

		for gf in inventory_component.girlfriends:
			var card: GirlfriendCard = preload("res://GAME/scenes/ui/girlfriend_card.tscn").instantiate()
			girlfriends_list.add_child(card)
			card.setup(gf, self)

	if skill_points_label:
		var points := player.progression.skill_points if player and player.progression else 0
		skill_points_label.text = "Skill Points: %d" % points

	if skills_list:
		for child in skills_list.get_children():
			child.queue_free()
		if player and player.progression:
			for skill_id in PlayerSkills.SKILL_ORDER:
				var card: SkillCard = preload("res://GAME/scenes/ui/skill_card.tscn").instantiate()
				skills_list.add_child(card)
				card.setup(skill_id, player.progression, self)

	_refresh_weapons_ui()
	_refresh_management_ui()

func _refresh_weapons_ui() -> void:
	if not weapons_list or not player:
		return
	
	for child in weapons_list.get_children():
		child.queue_free()
	
	var owned_level = player.get_owned_glock_level()
	if owned_level > 0:
		var card: InventoryWeaponCard = preload("res://GAME/scenes/ui/inventory_weapon_card.tscn").instantiate()
		weapons_list.add_child(card)
		
		var weapon_data = player.glock_weapon_data_by_level.get(owned_level)
		var weapon_name = "GLOCK LV %d" % owned_level
		var icon = preload("res://GAME/assets/sprites/weapons/pistol/glocklv1.png") # Fallback to base icon for simplicity or logic if needed
		
		# More specific icon logic if possible
		var icon_path = "res://GAME/assets/sprites/weapons/pistol/glocklv%d.png" % owned_level
		if FileAccess.file_exists(icon_path):
			icon = load(icon_path)
			
		var stats_text = "Dmg: %d | Rng: %d | Mag: %d" % [weapon_data.damage, 300, weapon_data.magazine_size]
		var is_eq = player.weapon_state.is_equipped if player.weapon_state else false
		
		card.setup(weapon_name, icon, stats_text, is_eq)

func _build_territories_ui() -> void:
	if not territories_tab:
		return
	for child in territories_tab.get_children():
		child.queue_free()

	var tab_scroll := ScrollContainer.new()
	tab_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	tab_scroll.grow_horizontal = Control.GROW_DIRECTION_BOTH
	tab_scroll.grow_vertical = Control.GROW_DIRECTION_BOTH
	tab_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	territories_tab.add_child(tab_scroll)

	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.custom_minimum_size = Vector2(0, 420)
	root.add_theme_constant_override("separation", 8)
	tab_scroll.add_child(root)

	var current_panel := PanelContainer.new()
	current_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(current_panel)

	var current_margin := MarginContainer.new()
	current_margin.add_theme_constant_override("margin_left", 10)
	current_margin.add_theme_constant_override("margin_top", 10)
	current_margin.add_theme_constant_override("margin_right", 10)
	current_margin.add_theme_constant_override("margin_bottom", 10)
	current_panel.add_child(current_margin)

	var current_box := VBoxContainer.new()
	current_box.add_theme_constant_override("separation", 6)
	current_margin.add_child(current_box)

	_current_territory_title = Label.new()
	_current_territory_title.text = "Current Territory"
	current_box.add_child(_current_territory_title)

	_current_territory_details = Label.new()
	_current_territory_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_current_territory_details.text = "Step into a territory to view control, stash support, and dealer status."
	current_box.add_child(_current_territory_details)

	_territory_support_status_label = Label.new()
	_territory_support_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	current_box.add_child(_territory_support_status_label)

	var assignment_row := HBoxContainer.new()
	assignment_row.add_theme_constant_override("separation", 6)
	current_box.add_child(assignment_row)

	var assignment_label := Label.new()
	assignment_label.text = "Support Stash:"
	assignment_row.add_child(assignment_label)

	_territory_support_selector = OptionButton.new()
	_territory_support_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_territory_support_selector.item_selected.connect(_on_support_selector_item_selected)
	assignment_row.add_child(_territory_support_selector)

	_territory_assign_button = Button.new()
	_territory_assign_button.text = "Assign"
	_territory_assign_button.pressed.connect(_on_assign_current_territory_support_property)
	assignment_row.add_child(_territory_assign_button)

	_territory_clear_support_button = Button.new()
	_territory_clear_support_button.text = "Clear Link"
	_territory_clear_support_button.pressed.connect(_on_clear_current_territory_support_property)
	assignment_row.add_child(_territory_clear_support_button)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 6)
	current_box.add_child(actions)

	_territory_control_button = Button.new()
	_territory_control_button.text = "Control"
	_territory_control_button.pressed.connect(_on_toggle_current_territory_control)
	actions.add_child(_territory_control_button)

	_territory_hire_button = Button.new()
	_territory_hire_button.text = "Hire Dealer"
	_territory_hire_button.pressed.connect(_on_hire_current_territory_dealer)
	actions.add_child(_territory_hire_button)

	_territory_clear_button = Button.new()
	_territory_clear_button.text = "Clear Hires"
	_territory_clear_button.pressed.connect(_on_clear_current_territory_hires)
	actions.add_child(_territory_clear_button)

	_territory_collect_button = Button.new()
	_territory_collect_button.text = "Collect Earnings"
	_territory_collect_button.pressed.connect(_on_collect_current_territory_earnings)
	actions.add_child(_territory_collect_button)

	var list_title := Label.new()
	list_title.text = "All Territories"
	root.add_child(list_title)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)

	_territory_list = VBoxContainer.new()
	_territory_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_territory_list.add_theme_constant_override("separation", 4)
	scroll.add_child(_territory_list)

func _build_properties_ui() -> void:
	if not properties_tab:
		return
	for child in properties_tab.get_children():
		child.queue_free()

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.grow_horizontal = Control.GROW_DIRECTION_BOTH
	root.grow_vertical = Control.GROW_DIRECTION_BOTH
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 8)
	properties_tab.add_child(root)

	_properties_summary_label = Label.new()
	_properties_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_properties_summary_label)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)

	_properties_list = VBoxContainer.new()
	_properties_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_properties_list.add_theme_constant_override("separation", 4)
	scroll.add_child(_properties_list)

func _refresh_management_ui() -> void:
	_refresh_territories_ui()
	_refresh_properties_ui()

func _refresh_territories_ui() -> void:
	if not territories_tab or not _current_territory_details or not _territory_list:
		return

	var current_territory: TerritoryArea = _get_current_territory()
	var has_current: bool = current_territory != null

	if has_current and current_territory.territory_data:
		var status: Dictionary = current_territory.get_support_status()
		var controlled_text := "Controlled" if current_territory.is_controlled() else "Uncontrolled"
		var ambient_count: int = 0 if current_territory.is_controlled() else current_territory.get_active_ambient_dealer_count()
		_current_territory_title.text = current_territory.territory_data.display_name
		_current_territory_details.text = "State: %s\nRep: %.1f\nHired Dealers: %d (%d active)\nAmbient Dealers: %d\nActive Customers: %d\nDealer Traffic: %d active buyers\nSupport Stash: %s\nStash Cash: $%d" % [
			controlled_text,
			current_territory.get_reputation(),
			current_territory.get_hired_dealer_count(),
			current_territory.get_active_hired_dealer_count(),
			ambient_count,
			current_territory.get_active_customer_count(),
			current_territory.get_active_dealer_traffic_count(),
			current_territory.get_support_property_name(),
			int(status.get("stash_dirty_cash", 0))
		]
		_territory_support_status_label.text = _format_support_status_text(status)
		_territory_control_button.text = "Release" if current_territory.is_controlled() else "Control"
		_refresh_current_territory_assignment_options(current_territory)
	else:
		_current_territory_title.text = "Current Territory"
		_current_territory_details.text = "Step into a territory to manage control, hired dealers, and stash-house support."
		_territory_support_status_label.text = "Network: No current territory selected."
		_territory_control_button.text = "Control"
		_refresh_current_territory_assignment_options(null)

	_territory_control_button.disabled = not has_current
	var can_manage_hires: bool = has_current and current_territory.is_controlled()
	_territory_hire_button.disabled = not can_manage_hires
	_territory_clear_button.disabled = not can_manage_hires

	var can_collect: bool = false
	if has_current and current_territory.is_controlled():
		can_collect = current_territory.get_support_stash_dirty_cash() > 0 and current_territory.has_support_property()
	_territory_collect_button.disabled = not can_collect

	for child in _territory_list.get_children():
		child.queue_free()

	for territory in _get_all_territories():
		_territory_list.add_child(_build_territory_summary_row(territory))

func _refresh_current_territory_assignment_options(current_territory: TerritoryArea) -> void:
	if not _territory_support_selector:
		return

	_territory_support_selector.clear()
	_territory_support_selector.add_item("No stash selected")
	_territory_support_selector.set_item_metadata(0, "")
	_territory_support_selector.select(0)

	var eligible_properties: Array[OwnedPropertyState] = NetworkManager.get_owned_stash_trap_properties()
	var territory_id: StringName = current_territory.get_territory_id() if current_territory else &""
	var current_property_id: StringName = current_territory.get_support_property_id() if current_territory else &""
	var pending_property_id: StringName = StringName(_pending_support_selection_by_territory.get(territory_id, current_property_id))
	var selected_index: int = 0
	for property_state in eligible_properties:
		if not property_state or not property_state.property_data:
			continue
		var linked_territory_id: StringName = NetworkManager.get_supported_territory_for_property(property_state.property_data.property_id)
		var label := property_state.property_data.display_name
		if linked_territory_id != &"" and linked_territory_id != (current_territory.get_territory_id() if current_territory else &""):
			label += " (Linked to %s)" % String(linked_territory_id)
		_territory_support_selector.add_item(label)
		var item_index: int = _territory_support_selector.item_count - 1
		_territory_support_selector.set_item_metadata(item_index, String(property_state.property_data.property_id))
		if property_state.property_data.property_id == pending_property_id:
			selected_index = item_index
		elif pending_property_id == &"" and property_state.property_data.property_id == current_property_id:
			selected_index = item_index

	_territory_support_selector.select(selected_index)

	var can_assign: bool = current_territory != null and current_territory.is_controlled() and _territory_support_selector.item_count > 1
	_territory_support_selector.disabled = not can_assign
	_territory_assign_button.disabled = not can_assign
	_territory_clear_support_button.disabled = current_territory == null or not current_territory.has_support_property()

func _refresh_properties_ui() -> void:
	if not properties_tab or not _properties_summary_label or not _properties_list:
		return

	for child in _properties_list.get_children():
		child.queue_free()

	var owned_properties: Array[OwnedPropertyState] = NetworkManager.get_owned_properties()
	_properties_summary_label.text = "Owned Properties: %d\nUse the stash UI for inventory management. This tab shows which stash houses are supporting territories." % owned_properties.size()

	if owned_properties.is_empty():
		var empty_label := Label.new()
		empty_label.text = "No owned properties yet."
		_properties_list.add_child(empty_label)
		return

	for property_state in owned_properties:
		_properties_list.add_child(_build_property_summary_row(property_state))

func _build_territory_summary_row(territory: TerritoryArea) -> Control:
	var row := VBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var name_label := Label.new()
	name_label.text = territory.territory_data.display_name if territory.territory_data else territory.name
	row.add_child(name_label)

	var ambient_count: int = 0 if territory.is_controlled() else territory.get_active_ambient_dealer_count()
	var status: Dictionary = territory.get_support_status()
	var summary := Label.new()
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary.text = "State: %s | Hired: %d | Ambient: %d | Support: %s | Stash Cash: $%d | %s" % [
		"Controlled" if territory.is_controlled() else "Uncontrolled",
		territory.get_hired_dealer_count(),
		ambient_count,
		territory.get_support_property_name(),
		int(status.get("stash_dirty_cash", 0)),
		_format_support_status_text(status)
	]
	row.add_child(summary)
	return row

func _build_property_summary_row(property_state: OwnedPropertyState) -> Control:
	var row := VBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var title := Label.new()
	title.text = property_state.property_data.display_name if property_state and property_state.property_data else "Unknown Property"
	row.add_child(title)

	var linked_territory_id: StringName = NetworkManager.get_supported_territory_for_property(property_state.property_data.property_id if property_state and property_state.property_data else &"")
	var linked_text: String = "None"
	var status_text: String = "Idle"
	if linked_territory_id != &"":
		linked_text = String(linked_territory_id)
		status_text = _format_support_status_text(NetworkManager.get_territory_support_status(linked_territory_id))

	var stash: StashInventory = property_state.stash if property_state else null
	var used_capacity: int = stash.get_used_capacity() if stash else 0
	var capacity: int = stash.capacity if stash else 0
	var dirty_cash: int = stash.dirty_cash if stash else 0
	var type_text: String = _format_property_type(property_state.property_data.property_type if property_state and property_state.property_data else PropertyResource.PropertyType.STASH_TRAP)

	var summary := Label.new()
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary.text = "Type: %s | Capacity: %d/%d | Dirty Cash: $%d | Linked Territory: %s | Dealer Support: %s" % [
		type_text,
		used_capacity,
		capacity,
		dirty_cash,
		linked_text,
		status_text
	]
	row.add_child(summary)
	return row

func _format_support_status_text(status: Dictionary) -> String:
	if status.is_empty():
		return "Network: No territory data."
	if bool(status.get("is_productive", false)):
		return "Network: Productive"
	return "Network: %s" % String(status.get("reason", "Blocked"))

func _format_property_type(property_type: int) -> String:
	match property_type:
		PropertyResource.PropertyType.STASH_TRAP:
			return "Stash / Trap"
		PropertyResource.PropertyType.FRONT_BUSINESS:
			return "Front Business"
		_:
			return "Unknown"

func _get_current_territory() -> TerritoryArea:
	if not player:
		return null
	for node in get_tree().get_nodes_in_group("territories"):
		var territory := node as TerritoryArea
		if not territory:
			continue
		if territory.get_overlapping_bodies().has(player):
			return territory
	return null

func _get_all_territories() -> Array[TerritoryArea]:
	var territories: Array[TerritoryArea] = []
	for node in get_tree().get_nodes_in_group("territories"):
		var territory := node as TerritoryArea
		if territory and territory.territory_data:
			territories.append(territory)
	territories.sort_custom(_sort_territories_by_name)
	return territories

func _sort_territories_by_name(a: TerritoryArea, b: TerritoryArea) -> bool:
	return a.territory_data.display_name < b.territory_data.display_name

func _selected_support_property_id() -> StringName:
	if not _territory_support_selector or _territory_support_selector.item_count <= 0:
		return &""
	return StringName(_territory_support_selector.get_item_metadata(_territory_support_selector.get_selected_id()))

func _on_support_selector_item_selected(index: int) -> void:
	var territory := _get_current_territory()
	if not territory:
		return
	var territory_id: StringName = territory.get_territory_id()
	if territory_id == &"":
		return
	var property_id: StringName = StringName(_territory_support_selector.get_item_metadata(index))
	_pending_support_selection_by_territory[territory_id] = property_id

func _on_toggle_current_territory_control() -> void:
	var territory := _get_current_territory()
	if not territory:
		return
	var territory_id: StringName = territory.get_territory_id()
	NetworkManager.set_territory_controlled(territory_id, not territory.is_controlled())
	_refresh_management_ui()

func _on_assign_current_territory_support_property() -> void:
	var territory := _get_current_territory()
	if not territory or not territory.is_controlled():
		return
	var property_id: StringName = _selected_support_property_id()
	if property_id == &"":
		return
	NetworkManager.set_territory_support_property(territory.get_territory_id(), property_id)
	_pending_support_selection_by_territory.erase(territory.get_territory_id())
	_refresh_management_ui()

func _on_clear_current_territory_support_property() -> void:
	var territory := _get_current_territory()
	if not territory:
		return
	NetworkManager.clear_territory_support_property(territory.get_territory_id())
	_pending_support_selection_by_territory.erase(territory.get_territory_id())
	_refresh_management_ui()

func _on_hire_current_territory_dealer() -> void:
	var territory := _get_current_territory()
	if not territory:
		return
	NetworkManager.hire_territory_dealer(territory.get_territory_id(), 1)
	_refresh_management_ui()

func _on_clear_current_territory_hires() -> void:
	var territory := _get_current_territory()
	if not territory:
		return
	NetworkManager.clear_hired_dealers(territory.get_territory_id())
	_refresh_management_ui()

func _on_collect_current_territory_earnings() -> void:
	var territory := _get_current_territory()
	if not territory or not player:
		return
	if not territory.is_controlled() or not territory.has_support_property():
		return
	var collected: int = NetworkManager.collect_territory_support_cash(territory.get_territory_id())
	if collected <= 0:
		return
	AudioManager.play_transaction()
	if player.player_ui:
		player.player_ui.spawn_indicator("money_up", "+$" + str(collected))
	_refresh_management_ui()

func _on_territory_runtime_changed(_territory_id: StringName, _controlled: bool) -> void:
	_refresh_management_ui()

func _on_territory_runtime_changed_simple(_territory_id: StringName) -> void:
	_refresh_management_ui()

func _on_territory_support_changed(_territory_id: StringName, _property_id: StringName) -> void:
	_pending_support_selection_by_territory.erase(_territory_id)
	_refresh_management_ui()

func _on_property_purchased(_property_state: OwnedPropertyState) -> void:
	_refresh_management_ui()

func _find_gf_node(resource: GirlfriendResource) -> NPC:
	for node in get_tree().get_nodes_in_group("girlfriend"):
		if node is NPC and node.gf_resource == resource:
			return node
	return null

func _spawn_girlfriend_npc(resource: GirlfriendResource, pos: Vector2) -> void:
	var npc_scene = load("res://GAME/scenes/characters/npc.tscn")
	var instance = npc_scene.instantiate()
	var spawn_offset = Vector2.RIGHT.rotated(randf() * TAU) * 400.0
	instance.global_position = pos + spawn_offset
	instance.gf_resource = resource
	instance.stats = resource.stats
	instance.gender = NPC.Gender.FEMALE
	instance.role = NPC.Role.CUSTOMER
	var player_node = get_tree().get_first_node_in_group("player")
	if player_node:
		player_node.get_parent().add_child(instance)
	else:
		get_parent().add_child(instance)
	instance.add_to_group("girlfriend")
	instance.modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(instance, "modulate:a", 1.0, 1.0)

func _on_progression_changed(_new_amount: int) -> void:
	refresh_ui()

func _on_skill_changed(_skill_id: StringName, _new_level: int) -> void:
	refresh_ui()

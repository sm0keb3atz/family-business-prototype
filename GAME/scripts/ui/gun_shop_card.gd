extends PanelContainer
class_name GunShopCard

signal selected(level: int)
signal action_pressed(level: int)
signal ammo_pressed()

@onready var icon_rect: Sprite2D = %IconRect
@onready var name_label: Label = %NameLabel
@onready var action_button: Button = %ActionButton
@onready var hbox: HBoxContainer = $HBoxContainer

var _level: int = 1
var ammo_button: Button
var button_container: VBoxContainer

func _ready() -> void:
	gui_input.connect(_on_gui_input)
	
	# Square out the icon better
	var icon_control = icon_rect.get_parent()
	var icon_panel = icon_control.get_parent()
	if icon_panel is PanelContainer:
		icon_panel.custom_minimum_size = Vector2(52, 52)
		icon_rect.position = Vector2(26, 26)
	
	# Create a vertical container for buttons to save space
	button_container = VBoxContainer.new()
	button_container.alignment = BoxContainer.ALIGNMENT_CENTER
	button_container.add_theme_constant_override("separation", 2)
	hbox.add_child(button_container)
	
	# Move existing action button into the new container
	action_button.get_parent().remove_child(action_button)
	button_container.add_child(action_button)
	
	# Make action button more usable (wider but still stacked)
	action_button.custom_minimum_size = Vector2(110, 26)
	action_button.add_theme_font_size_override("font_size", 11)
	
	action_button.pressed.connect(_on_action_button_pressed)

func setup(level: int, weapon_name: String, icon: Texture, current_owned_level: int, cost: int, can_afford: bool, ammo_cost: int = 0, can_afford_ammo: bool = false, reserve_ammo: int = -1) -> void:
	_level = level
	name_label.text = weapon_name
	icon_rect.texture = icon
	
	_update_button_state(current_owned_level, cost, can_afford)
	_update_ammo_button(current_owned_level, ammo_cost, can_afford_ammo, reserve_ammo)

func _update_button_state(owned_level: int, cost: int, can_afford: bool) -> void:
	if owned_level >= _level:
		action_button.text = "OWNED"
		action_button.disabled = true
	elif _level == owned_level + 1:
		action_button.text = "BUY $%d" % cost if owned_level == 0 else "UPGRADE $%d" % cost
		action_button.disabled = not can_afford
	else:
		action_button.text = "LOCKED"
		action_button.disabled = true

func _update_ammo_button(owned_level: int, ammo_cost: int, can_afford_ammo: bool, reserve_ammo: int) -> void:
	if owned_level <= 0 or ammo_cost <= 0:
		if ammo_button: ammo_button.hide()
		return
		
	if not ammo_button:
		ammo_button = Button.new()
		ammo_button.name = "AmmoButton"
		ammo_button.custom_minimum_size = Vector2(110, 26)
		ammo_button.add_theme_font_size_override("font_size", 11)
		button_container.add_child(ammo_button)
		ammo_button.pressed.connect(func(): ammo_pressed.emit())
	
	ammo_button.show()
	ammo_button.text = "REFILL AMMO $%d" % ammo_cost
	ammo_button.disabled = not can_afford_ammo
	
	if reserve_ammo >= 0:
		name_label.text = "%s (%d)" % [name_label.text.split(" (")[0], reserve_ammo]

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		selected.emit(_level)

func _on_action_button_pressed() -> void:
	action_pressed.emit(_level)

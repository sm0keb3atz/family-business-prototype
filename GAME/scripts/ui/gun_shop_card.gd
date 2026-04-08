extends PanelContainer
class_name GunShopCard

signal selected(level: int)
signal action_pressed(level: int)

@onready var icon_rect: Sprite2D = %IconRect
@onready var name_label: Label = %NameLabel
@onready var action_button: Button = %ActionButton

var _level: int = 1

func _ready() -> void:
	gui_input.connect(_on_gui_input)
	action_button.pressed.connect(_on_action_button_pressed)

func setup(level: int, weapon_name: String, icon: Texture, current_owned_level: int, cost: int, can_afford: bool) -> void:
	_level = level
	name_label.text = weapon_name
	icon_rect.texture = icon
	
	_update_button_state(current_owned_level, cost, can_afford)

func _update_button_state(owned_level: int, cost: int, can_afford: bool) -> void:
	if owned_level >= _level:
		action_button.text = "Owned"
		action_button.disabled = true
	elif _level == owned_level + 1:
		action_button.text = "Buy ($%d)" % cost if owned_level == 0 else "Upgrade ($%d)" % cost
		action_button.disabled = not can_afford
	else:
		action_button.text = "Locked"
		action_button.disabled = true

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		selected.emit(_level)

func _on_action_button_pressed() -> void:
	action_pressed.emit(_level)

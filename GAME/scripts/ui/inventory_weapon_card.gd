extends PanelContainer
class_name InventoryWeaponCard

@onready var icon_rect: Sprite2D = %IconRect
@onready var name_label: Label = %NameLabel
@onready var stats_label: Label = %StatsLabel
@onready var status_label: Label = %StatusLabel

func setup(weapon_name: String, icon: Texture, stats_text: String, is_equipped: bool) -> void:
	if not is_inside_tree(): await ready
	
	name_label.text = weapon_name
	icon_rect.texture = icon
	icon_rect.hframes = 12
	icon_rect.frame = 0 # Default profile view
	stats_label.text = stats_text
	status_label.text = "EQUIPPED" if is_equipped else "IN BACKPACK"
	status_label.modulate = Color.CYAN if is_equipped else Color.GRAY

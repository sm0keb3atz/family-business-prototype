extends PanelContainer
class_name SkillCard

@onready var icon_rect: TextureRect = $OuterRow/IconPanel/Icon
@onready var name_label: Label = $OuterRow/Content/TopRow/NameLabel
@onready var level_label: Label = $OuterRow/Content/TopRow/LevelLabel
@onready var current_label: Label = $OuterRow/Content/CurrentLabel
@onready var next_label: Label = $OuterRow/Content/NextLabel
@onready var cost_label: Label = $OuterRow/Content/BottomRow/CostLabel
@onready var buy_button: Button = $OuterRow/Content/BottomRow/BuyButton

var _skill_id: StringName
var _progression: PlayerProgressionResource
var _inventory_ui: InventoryUI

func setup(skill_id: StringName, progression: PlayerProgressionResource, inventory_ui: InventoryUI) -> void:
	_skill_id = skill_id
	_progression = progression
	_inventory_ui = inventory_ui
	if not buy_button.pressed.is_connected(_on_buy_pressed):
		buy_button.pressed.connect(_on_buy_pressed)
	_refresh()

func _refresh() -> void:
	if not _progression:
		return
	var current_level := _progression.get_skill_level(_skill_id)
	name_label.text = PlayerSkills.get_display_name(_skill_id)
	level_label.text = "Lv. %d" % current_level
	current_label.text = "Current: " + PlayerSkills.get_effect_summary(_skill_id, current_level)
	next_label.text = PlayerSkills.get_next_level_text(_skill_id, current_level)

	var icon_path := PlayerSkills.get_icon_path(_skill_id, current_level)
	if not icon_path.is_empty():
		icon_rect.texture = load(icon_path)

	if current_level >= PlayerSkills.MAX_LEVEL:
		cost_label.text = "Cost: MAX"
		buy_button.text = "Maxed"
		buy_button.disabled = true
	else:
		var next_cost := _progression.get_next_skill_cost(_skill_id)
		cost_label.text = "Cost: %d SP" % next_cost
		buy_button.text = "Buy"
		buy_button.disabled = not _progression.can_purchase_skill(_skill_id)

func _on_buy_pressed() -> void:
	if not _progression:
		return
	if _progression.purchase_skill(_skill_id) and _inventory_ui:
		_inventory_ui.refresh_ui()

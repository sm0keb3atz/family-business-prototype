extends PanelContainer
class_name GirlfriendCard

## UI card for a single girlfriend entry in the inventory screen.
## Call setup() after instantiating.
## Uses explicit node paths instead of % to avoid editor stripping unique_name_in_owner.

@onready var name_label: Label = $OuterRow/VBoxContainer/TopRow/NameLabel
@onready var status_label: Label = $OuterRow/VBoxContainer/TopRow/StatusLabel
@onready var level_label: Label = $OuterRow/VBoxContainer/TopRow/LevelLabel
@onready var relationship_bar: ProgressBar = $OuterRow/VBoxContainer/RelationshipRow/RelationshipBar
@onready var rel_value_label: Label = $OuterRow/VBoxContainer/RelationshipRow/RelValueLabel
@onready var buff_label: Label = $OuterRow/VBoxContainer/RelationshipRow/BuffLabel
@onready var toggle_btn: Button = $OuterRow/VBoxContainer/ButtonRow/ToggleBtn
@onready var breakup_btn: Button = $OuterRow/VBoxContainer/ButtonRow/BreakupBtn
@onready var body_preview: Sprite2D = $OuterRow/SpritePanel/SpriteStack/BodyPreview
@onready var outfit_preview: Sprite2D = $OuterRow/SpritePanel/SpriteStack/OutfitPreview
@onready var hair_preview: Sprite2D = $OuterRow/SpritePanel/SpriteStack/HairPreview



var _resource: GirlfriendResource
var _inventory_ui: InventoryUI

func setup(resource: GirlfriendResource, inventory_ui: InventoryUI) -> void:
	_resource = resource
	_inventory_ui = inventory_ui

	_refresh()
	_setup_sprite_preview()

	# Live-update progress bar while the inventory is open
	if not _resource.relationship_changed.is_connected(_on_relationship_changed):
		_resource.relationship_changed.connect(_on_relationship_changed)

	toggle_btn.pressed.connect(_on_toggle_pressed)
	breakup_btn.pressed.connect(_on_breakup_pressed)

func _refresh() -> void:
	if not _resource:
		return

	name_label.text = _resource.npc_name
	level_label.text = "Lv. " + str(_resource.level)
	status_label.text = "Following" if _resource.is_following else "At Home"
	toggle_btn.text = "Send Home" if _resource.is_following else "Call"

	relationship_bar.value = _resource.relationship
	rel_value_label.text = "%.1f" % _resource.relationship
	_tint_bar(_resource.relationship)
	_update_buff_label()

func _setup_sprite_preview() -> void:
	if not _resource or not _resource.appearance:
		return
	var app: AppearanceResource = _resource.appearance

	# Body texture - show custom region defined in editor
	if app.body_texture and body_preview:
		body_preview.texture = app.body_texture

	# Outfit texture layered on top
	if app.outfit_texture and outfit_preview:
		outfit_preview.texture = app.outfit_texture

	# Hair texture layered on top
	if app.hair_texture and hair_preview:
		hair_preview.texture = app.hair_texture

func _tint_bar(value: float) -> void:
	# Colour shifts: red (0) -> orange (50) -> green (100)
	var colour: Color
	if value >= 50.0:
		colour = Color.ORANGE.lerp(Color.GREEN, (value - 50.0) / 50.0)
	else:
		colour = Color.RED.lerp(Color.ORANGE, value / 50.0)
	relationship_bar.modulate = colour

func _update_buff_label() -> void:
	if not _resource or not is_instance_valid(buff_label):
		return
	var level_buff = 0.0
	match _resource.level:
		1: level_buff = 0.10
		2: level_buff = 0.25
		3: level_buff = 0.50
		_: level_buff = 0.10 * _resource.level
	
	var rel_mult: float = lerp(0.5, 1.5, _resource.relationship / 100.0)
	var final_buff: float = level_buff * rel_mult
	var percent: int = roundi(final_buff * 100.0)
	
	if percent >= 0:
		buff_label.text = "(+%d%%)" % percent
		buff_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
	else:
		buff_label.text = "(%d%%)" % percent
		buff_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))

func _on_relationship_changed(value: float) -> void:
	relationship_bar.value = value
	rel_value_label.text = "%.1f" % value
	_tint_bar(value)
	_update_buff_label()

func _on_toggle_pressed() -> void:
	if not _resource or not _inventory_ui:
		return
	var npc_node: NPC = _inventory_ui._find_gf_node(_resource)
	if _resource.is_following:
		# Send home
		if npc_node:
			npc_node.dismiss(false)
	else:
		# Call back
		var player = _inventory_ui.get_tree().get_first_node_in_group("player")
		if player:
			if npc_node:
				npc_node.call_back(player.global_position)
			else:
				_inventory_ui._spawn_girlfriend_npc(_resource, player.global_position)
		_resource.is_following = true
	_refresh()

func _on_breakup_pressed() -> void:
	if not _resource or not _inventory_ui:
		return
	var npc_node: NPC = _inventory_ui._find_gf_node(_resource)
	if npc_node:
		npc_node.dismiss(true)
	else:
		_inventory_ui.inventory_component.remove_girlfriend(_resource)
	_inventory_ui.refresh_ui()

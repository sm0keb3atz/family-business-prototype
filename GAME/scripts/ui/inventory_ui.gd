extends CanvasLayer
class_name InventoryUI

@onready var tabs: TabContainer = $Control/PanelContainer/MarginContainer/VBoxContainer/TabContainer
@onready var drugs_list: VBoxContainer = %DrugsList
@onready var main_control: Control = $Control

var inventory_component: InventoryComponent

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	main_control.hide()

func setup(component: InventoryComponent) -> void:
	inventory_component = component
	inventory_component.inventory_changed.connect(refresh_ui)

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

func refresh_ui() -> void:
	for child in drugs_list.get_children():
		child.queue_free()
		
	if not inventory_component: return
	
	for drug_id in inventory_component.drugs:
		var qty = inventory_component.drugs[drug_id]
		var label = Label.new()
		label.text = str(drug_id).capitalize() + ": " + str(qty) + "g"
		drugs_list.add_child(label)

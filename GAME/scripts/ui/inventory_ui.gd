extends CanvasLayer
class_name InventoryUI

@onready var tabs: TabContainer = $Control/PanelContainer/MarginContainer/VBoxContainer/TabContainer
@onready var drugs_list: VBoxContainer = %DrugsList
@onready var girlfriends_list: VBoxContainer = get_node_or_null("%GirlfriendsList")
@onready var skills_list: VBoxContainer = get_node_or_null("%SkillsList")
@onready var skill_points_label: Label = get_node_or_null("%SkillPointsLabel")
@onready var main_control: Control = $Control

var inventory_component: InventoryComponent
var player: Player

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	main_control.hide()

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
		
	if not inventory_component: return
	
	# Show Bricks (if any)
	for drug_id in inventory_component.bricks:
		var qty = inventory_component.bricks[drug_id]
		if qty <= 0: continue
		
		var h_box = HBoxContainer.new()
		drugs_list.add_child(h_box)
		
		var label = Label.new()
		label.text = str(drug_id).capitalize() + " Brick: " + str(qty)
		h_box.add_child(label)
		
		var break_btn = Button.new()
		break_btn.text = "Break Down"
		break_btn.pressed.connect(func():
			if inventory_component.break_brick(drug_id):
				refresh_ui()
		)
		h_box.add_child(break_btn)
	
	# Show Grams
	for drug_id in inventory_component.drugs:
		var qty = inventory_component.drugs[drug_id]
		var label = Label.new()
		label.text = str(drug_id).capitalize() + ": " + str(qty) + "g"
		drugs_list.add_child(label)
	
	# Show Girlfriends
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



func _find_gf_node(resource: GirlfriendResource) -> NPC:
	for node in get_tree().get_nodes_in_group("girlfriend"):
		if node is NPC and node.gf_resource == resource:
			return node
	return null

func _spawn_girlfriend_npc(resource: GirlfriendResource, pos: Vector2) -> void:
	var npc_scene = load("res://GAME/scenes/characters/npc.tscn")
	var instance = npc_scene.instantiate()
	# Spawn at a distance so she walks up
	var spawn_offset = Vector2.RIGHT.rotated(randf() * TAU) * 400.0
	instance.global_position = pos + spawn_offset
	instance.gf_resource = resource
	instance.stats = resource.stats
	instance.gender = NPC.Gender.FEMALE
	instance.role = NPC.Role.CUSTOMER
	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.get_parent().add_child(instance)
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

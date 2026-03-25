extends CanvasLayer
class_name DebugConsole

@onready var panel: PanelContainer = $Panel
@onready var help_label: Label = $Panel/Margin/Layout/HelpLabel
@onready var status_label: Label = $Panel/Margin/Layout/StatusLabel
@onready var command_input: LineEdit = $Panel/Margin/Layout/CommandInput

var player: Player
var console_visible: bool = false

func _ready() -> void:
	panel.visible = false
	help_label.text = "Debug Console (`)\nadd money <amount>\nadd skill point <amount>\nplayer level <amount>"
	status_label.text = "Enter a command and press Enter."
	command_input.placeholder_text = "Example: add money 500"
	command_input.text_submitted.connect(_on_command_submitted)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_QUOTELEFT:
		_toggle_console()
		get_viewport().set_input_as_handled()

func _toggle_console() -> void:
	console_visible = not console_visible
	panel.visible = console_visible
	_set_player_input_locked(console_visible)

	if console_visible:
		command_input.clear()
		command_input.grab_focus()
		status_label.text = "Enter a command and press Enter."
	else:
		command_input.release_focus()

func _set_player_input_locked(is_locked: bool) -> void:
	if not player:
		player = get_tree().get_first_node_in_group("player")
	if not player:
		return

	player.velocity = Vector2.ZERO

	if player.input_component:
		player.input_component.set_process(not is_locked)
		player.input_component.set_process_unhandled_input(not is_locked)

	if player.state_machine:
		player.state_machine.set_process(not is_locked)
		player.state_machine.set_physics_process(not is_locked)

func _on_command_submitted(command_text: String) -> void:
	var trimmed: String = command_text.strip_edges()
	if trimmed.is_empty():
		status_label.text = "Enter a command first."
		return

	var result: String = _run_command(trimmed)
	status_label.text = result
	command_input.clear()

func _run_command(command_text: String) -> String:
	if not player:
		player = get_tree().get_first_node_in_group("player")
	if not player or not player.progression:
		return "Player progression is not ready yet."

	var parts: PackedStringArray = command_text.split(" ", false)
	if parts.is_empty():
		return "Unknown command."

	var root: String = parts[0].to_lower()
	match root:
		"help":
			return "Commands: add money <amount>, add skill point <amount>, player level <amount>"
		"add":
			return _handle_add_command(parts)
		"player":
			return _handle_player_command(parts)
		_:
			return "Unknown command. Try: help"

func _handle_add_command(parts: PackedStringArray) -> String:
	if parts.size() == 3 and parts[1].to_lower() == "money":
		if not parts[2].is_valid_int():
			return "Money amount must be a whole number."

		var amount: int = parts[2].to_int()
		player.progression.add_money(amount)
		return "Money updated to $%d." % player.progression.money

	if parts.size() == 4 and parts[1].to_lower() == "skill" and parts[2].to_lower() == "point":
		if not parts[3].is_valid_int():
			return "Skill point amount must be a whole number."

		var amount: int = parts[3].to_int()
		player.progression.skill_points += amount
		return "Skill points updated to %d." % player.progression.skill_points

	return "Usage: add money <amount> or add skill point <amount>"

func _handle_player_command(parts: PackedStringArray) -> String:
	if parts.size() != 3 or parts[1].to_lower() != "level":
		return "Usage: player level <amount>"

	if not parts[2].is_valid_int():
		return "Level must be a whole number."

	var target_level: int = max(parts[2].to_int(), 1)
	player.progression.set_level_value(target_level)
	return "Player level set to %d." % player.progression.level

func _process(_delta: float) -> void:
	if not player:
		player = get_tree().get_first_node_in_group("player")
		if player and console_visible:
			_set_player_input_locked(true)

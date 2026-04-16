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
	help_label.text = "Debug Console (`)\nadd money <amount>\nadd clean <amount>\nadd debt <amount>\nset time <11am/23/etc>\nplayer level <amount>\nterritory control <id> on|off\nterritory hire <id> [tier 1-4]\nterritory clear hires <id>"
	status_label.text = "Enter a command and press Enter."
	command_input.placeholder_text = "Example: set time 11am"
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
			return "Commands: add money|clean|debt, add skill point, player level, territory control <id> on|off, territory hire <id> [tier], territory clear hires <id>"
		"add":
			return _handle_add_command(parts)
		"set":
			return _handle_set_command(parts)
		"player":
			return _handle_player_command(parts)
		"territory":
			return _handle_territory_command(parts)
		_:
			return "Unknown command. Try: help"

func _handle_add_command(parts: PackedStringArray) -> String:
	if parts.size() == 3 and parts[1].to_lower() == "money":
		if not parts[2].is_valid_int():
			return "Money amount must be a whole number."
		var amount: int = parts[2].to_int()
		NetworkManager.economy.add_dirty(amount)
		return "Dirty money updated to $%d." % NetworkManager.economy.dirty_money

	if parts.size() == 3 and parts[1].to_lower() == "clean":
		if not parts[2].is_valid_int():
			return "Clean amount must be a whole number."
		var amount: int = parts[2].to_int()
		NetworkManager.economy.add_clean(amount)
		return "Clean money updated to $%d." % NetworkManager.economy.clean_money

	if parts.size() == 3 and parts[1].to_lower() == "debt":
		if not parts[2].is_valid_int():
			return "Debt amount must be a whole number."
		var amount: int = parts[2].to_int()
		NetworkManager.economy.add_debt(amount)
		return "Debt updated to $%d." % NetworkManager.economy.debt

	if parts.size() == 4 and parts[1].to_lower() == "skill" and parts[2].to_lower() == "point":
		if not parts[3].is_valid_int():
			return "Skill point amount must be a whole number."

		var amount: int = parts[3].to_int()
		player.progression.skill_points += amount
		return "Skill points updated to %d." % player.progression.skill_points

	return "Usage: add money <amount>, add clean <amount>, add debt <amount>, or add skill point <amount>"

func _handle_set_command(parts: PackedStringArray) -> String:
	if parts.size() < 3:
		return "Usage: set <variable> <value>. Example: set time 11am"
	
	var variable = parts[1].to_lower()
	match variable:
		"time":
			var time_str = parts[2].to_lower()
			var hour = 0
			var minute = 0
			
			if time_str.ends_with("am") or time_str.ends_with("pm"):
				var is_pm = time_str.ends_with("pm")
				var val_str = time_str.substr(0, time_str.length() - 2)
				if val_str.is_valid_int():
					hour = val_str.to_int()
					if is_pm and hour < 12: hour += 12
					if not is_pm and hour == 12: hour = 0
				else:
					return "Invalid time format. Use: 11am, 2pm, or 14"
			elif time_str.is_valid_int():
				hour = time_str.to_int()
			else:
				return "Invalid time format. Use: 11am, 2pm, or 14"
			
			var tm = get_tree().get_first_node_in_group("time_manager")
			if tm:
				tm.set_time(hour, minute)
				return "Time set to %02d:%02d" % [hour, minute]
			return "TimeManager not found."
		_:
			return "Unknown variable to set. Try: time"

func _handle_player_command(parts: PackedStringArray) -> String:
	if parts.size() != 3 or parts[1].to_lower() != "level":
		return "Usage: player level <amount>"

	if not parts[2].is_valid_int():
		return "Level must be a whole number."

	var target_level: int = max(parts[2].to_int(), 1)
	player.progression.set_level_value(target_level)
	return "Player level set to %d." % player.progression.level


func _handle_territory_command(parts: PackedStringArray) -> String:
	if parts.size() < 2:
		return "Usage: territory control <id> on|off — territory hire <id> [tier] — territory clear hires <id>"

	var sub: String = parts[1].to_lower()
	match sub:
		"control":
			if parts.size() < 4:
				return "Usage: territory control <territory_id> on|off"
			var tid := StringName(parts[2])
			var mode := parts[3].to_lower()
			if mode == "on" or mode == "true" or mode == "1":
				NetworkManager.set_territory_controlled(tid, true)
				return "Territory %s: player control ON." % String(tid)
			if mode == "off" or mode == "false" or mode == "0":
				NetworkManager.set_territory_controlled(tid, false)
				return "Territory %s: player control OFF." % String(tid)
			return "Third arg must be on or off."
		"hire":
			if parts.size() < 3:
				return "Usage: territory hire <territory_id> [tier 1-4]"
			var tid2 := StringName(parts[2])
			var tier := 1
			if parts.size() >= 4 and parts[3].is_valid_int():
				tier = clampi(parts[3].to_int(), 1, 4)
			NetworkManager.hire_territory_dealer(tid2, tier)
			return "Hired dealer (tier %d) in %s. Total slots: %d." % [tier, String(tid2), NetworkManager.get_hired_dealer_slots(tid2).size()]
		"clear":
			if parts.size() < 4 or parts[2].to_lower() != "hires":
				return "Usage: territory clear hires <territory_id>"
			var tid3 := StringName(parts[3])
			NetworkManager.clear_hired_dealers(tid3)
			return "Cleared hired dealers for %s." % String(tid3)
		_:
			return "Unknown territory subcommand. Use control, hire, or clear hires."

func _process(_delta: float) -> void:
	if not player:
		player = get_tree().get_first_node_in_group("player")
		if player and console_visible:
			_set_player_input_locked(true)

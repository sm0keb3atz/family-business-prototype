@tool
extends BTAction
## An NPC stops to "chat" with a nearby NPC for a random duration.
## Shows a dialog bubble on both NPCs while chatting.

@export var chat_range: float = 120.0
@export var min_chat_time: float = 3.0
@export var max_chat_time: float = 7.0
## Chance (0.0 to 1.0) that this action triggers each time it's entered.
@export var chat_chance: float = 0.15

var _duration: float = 0.0
var _elapsed: float = 0.0
var _partner: NPC = null
var _should_chat: bool = false

const CHAT_LINES: Array[String] = [
	"Hey, what's up?",
	"Nice weather today.",
	"Did you hear about...",
	"How's it going?",
	"See you around!",
	"Take care!",
	"Yo, what's good?",
	"Man, it's busy today.",
]

func _generate_name() -> String:
	return "Chat With Nearby NPC (%s%%)" % [chat_chance * 100]

func _enter() -> void:
	_elapsed = 0.0
	_partner = null
	_should_chat = randf() < chat_chance
	
	if not _should_chat:
		return
	
	_duration = randf_range(min_chat_time, max_chat_time)
	
	# Find a nearby NPC to chat with
	var npc: NPC = agent as NPC
	if not npc:
		_should_chat = false
		return
	
	var npcs_in_range: Array = []
	for other in npc.get_tree().get_nodes_in_group("npc"):
		if other == npc:
			continue
		if other is NPC and npc.global_position.distance_to(other.global_position) < chat_range:
			# Don't chat with someone already chatting
			if not other._is_interacting:
				npcs_in_range.append(other)
	
	if npcs_in_range.size() > 0:
		_partner = npcs_in_range.pick_random()
		# Show bubbles on both
		if npc.npc_ui:
			npc.npc_ui.show_dialog_bubble(CHAT_LINES.pick_random())
		if _partner.npc_ui:
			_partner.npc_ui.show_dialog_bubble(CHAT_LINES.pick_random())
		# Make both face each other
		if npc.animation_component:
			var dir: Vector2 = npc.global_position.direction_to(_partner.global_position)
			npc.animation_component.last_direction = dir
			npc.animation_component.update_animation(Vector2.ZERO)
		if _partner.animation_component:
			var dir: Vector2 = _partner.global_position.direction_to(npc.global_position)
			_partner.animation_component.last_direction = dir
			_partner.animation_component.update_animation(Vector2.ZERO)
	else:
		_should_chat = false

func _tick(delta: float) -> Status:
	if not _should_chat:
		return SUCCESS
	
	_elapsed += delta
	if _elapsed >= _duration:
		_cleanup()
		return SUCCESS
	return RUNNING

func _exit() -> void:
	_cleanup()

func _cleanup() -> void:
	var npc: NPC = agent as NPC
	if npc and npc.npc_ui:
		npc.npc_ui.hide_dialog_bubble()
	if _partner and is_instance_valid(_partner) and _partner.npc_ui:
		_partner.npc_ui.hide_dialog_bubble()
	_partner = null

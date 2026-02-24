@tool
extends BTAction
## Resets 'is_solicited' and 'is_interacting' variables on the blackboard.

func _generate_name() -> String:
	return "Reset Solicitation"

func _tick(_delta: float) -> Status:
	blackboard.set_var(&"is_solicited", false)
	blackboard.set_var(&"is_interacting", false)
	
	var npc: NPC = agent as NPC
	if npc and npc.npc_ui:
		npc.npc_ui.hide_dialog_bubble()
		
	return SUCCESS

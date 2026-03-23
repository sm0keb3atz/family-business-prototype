@tool
extends BTCondition

func _tick(_delta: float) -> Status:
	var npc: NPC = agent as NPC
	if npc and npc.get("gf_is_requesting"):
		return SUCCESS
	return FAILURE

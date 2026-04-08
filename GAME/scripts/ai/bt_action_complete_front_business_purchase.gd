@tool
extends BTAction

@export var distance_threshold: float = 85.0

func _generate_name() -> String:
	return "Complete Front Business Purchase"

func _clear_front_business_customer_state(npc: NPC) -> void:
	if not blackboard:
		return
	blackboard.set_var(&"is_front_business_customer", false)
	blackboard.set_var(&"approach_target", null)
	blackboard.set_var(&"front_business_purchase_target", null)
	blackboard.set_var(&"front_business_level", 0)
	if npc and npc.has_method("_update_ui_icon"):
		npc._update_ui_icon()

func _tick(_delta: float) -> Status:
	var npc: NPC = agent as NPC
	if not npc or not blackboard:
		return FAILURE

	var target: Node2D = null
	var raw_target: Variant = blackboard.get_var(&"approach_target", null)
	if is_instance_valid(raw_target) and raw_target is Node2D:
		target = raw_target
	if not is_instance_valid(target):
		_clear_front_business_customer_state(npc)
		return FAILURE

	if npc.global_position.distance_to(target.global_position) > distance_threshold:
		return RUNNING

	var business_area: FrontBusinessInteractArea = null
	var raw_area: Variant = blackboard.get_var(&"front_business_purchase_target", null)
	if is_instance_valid(raw_area) and raw_area is FrontBusinessInteractArea:
		business_area = raw_area
	if not business_area:
		_clear_front_business_customer_state(npc)
		return FAILURE

	var level: int = int(blackboard.get_var(&"front_business_level", 0))
	if level <= 0:
		_clear_front_business_customer_state(npc)
		return FAILURE

	if business_area.npc_purchase(level):
		_clear_front_business_customer_state(npc)
		return SUCCESS

	_clear_front_business_customer_state(npc)
	return FAILURE

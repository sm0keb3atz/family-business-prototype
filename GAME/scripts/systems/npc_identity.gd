extends RefCounted
class_name NPCIdentity

var role: int
var gender: int
var global_position: Vector2
var appearance_data: Resource
var behavior_tree: Resource
var stats: Resource
var dealer_tier: Resource
var path_markers: Array = []
var territory_id: StringName

var target_position: Vector2
var velocity: Vector2
var metadata: Dictionary = {}
var current_actor: NPC = null # The physical node if "Realized"
## O(1) alternative to scanning _realization_queue for duplicates when many NPCs become eligible at once.
var queued_for_realization: bool = false
## Eligible but intentionally delayed so NPCs wake in over time instead of all at once.
var queued_for_staggered_realization: bool = false
var realization_ready_msec: int = 0

func is_realized() -> bool:
	return is_instance_valid(current_actor)

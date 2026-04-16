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

func is_realized() -> bool:
	return is_instance_valid(current_actor)

extends Node
class_name NpcLodManager

## Central NPC Level-of-Detail controller.
## Runs once per frame tick budget, assigns LOD tiers to all NPCs based on
## distance from the player. No NPCs are ever freed — they just cost less
## the further away they are, giving smooth performance with no pop-in.
##
## TIER 0 — FULL     : Within FULL_DIST px  → full physics + AI + avoidance
## TIER 1 — REDUCED  : Within REDUCED_DIST px → physics on, avoidance off
## TIER 2 — DORMANT  : Beyond REDUCED_DIST px → physics off, AI off

## Distance thresholds (pixels). Tune in Inspector at runtime.
@export var full_dist: float = 850.0
@export var reduced_dist: float = 2400.0

## Buffer added to boundaries to prevent rapid LOD toggling (flapping)
@export var hysteresis: float = 150.0

## Max number of NPCs whose distance is checked per frame.
@export var evaluations_per_frame: int = 70

## HARD LIMIT on how many NPCs are allowed to change LOD tiers in a single frame.
## This completely flattens CPU spikes when crossing a boundary where 20 NPCs wake up.
@export var max_transitions_per_frame: int = 4
@export var debug_logging: bool = false
@export var cache_refresh_interval: float = 1.0 # Refresh node list every second

var _npc_index: int = 0
var _cached_npcs: Array[Node] = []
var _refresh_timer: float = 0.0

func _process(delta: float) -> void:
	var player: Node2D = _get_player()
	if not player:
		return

	_refresh_timer += delta
	if _refresh_timer >= cache_refresh_interval or _cached_npcs.is_empty():
		_refresh_timer = 0.0
		_cached_npcs = get_tree().get_nodes_in_group("npc")

	if _cached_npcs.is_empty():
		return

	var count: int = _cached_npcs.size()
	var evaluated: int = 0
	var transitions: int = 0
	var pooled_skips: int = 0

	# Keep evaluating until we hit evaluation limit, all NPCs are checked, OR we max out our transition budget.
	while evaluated < evaluations_per_frame and evaluated < count and transitions < max_transitions_per_frame:
		_npc_index = _npc_index % count
		var npc: Node = _cached_npcs[_npc_index]
		
		# Some generic check for validity
		if is_instance_valid(npc) and npc.has_method("set_lod_tier") and npc.get("_is_dead") == false:
			if bool(npc.get("_is_pooled")):
				pooled_skips += 1
				_npc_index += 1
				evaluated += 1
				continue
			
			var dist: float = player.global_position.distance_to(npc.global_position)
			var current_tier: int = npc.get("_lod_tier")
			if current_tier == null: current_tier = 0
			var target_tier: int = current_tier
			
			match current_tier:
				0:
					if dist > full_dist + hysteresis:
						target_tier = 1
				1:
					if dist <= full_dist:
						target_tier = 0
					elif dist > reduced_dist + hysteresis:
						target_tier = 2
				2:
					if dist <= reduced_dist:
						# Progressive stepping. If it needs to go to 0, it goes to 1 first.
						# The next time this NPC is evaluated, it will go to 0. Spreads the load!
						target_tier = 1
						
			if target_tier != current_tier:
				npc.set_lod_tier(target_tier)
				transitions += 1
				
		_npc_index += 1
		evaluated += 1

	if debug_logging and transitions > 0:
		print("[NpcLodManager] transitions=%d evaluated=%d pooled_skips=%d total=%d" % [transitions, evaluated, pooled_skips, count])


func _get_player() -> Node2D:
	var nodes: Array[Node] = get_tree().get_nodes_in_group("player")
	if nodes.is_empty():
		return null
	return nodes[0] as Node2D

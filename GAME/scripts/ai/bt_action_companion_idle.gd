@tool
extends BTAction
## Idle behavior for companions (Girlfriends).
## Performs micro-wanders and occasional speech barks while waiting for the player.

@export var idle_wander_radius: float = 40.0
@export var bark_chance: float = 0.05
@export_multiline var barks: Array[String] = [
	"You're doing great, babe.",
	"I'm right behind you.",
	"So, where are we going next?",
	"I love spending time with you.",
	"Be careful out here.",
	"You looking for something?",
]

var _timer: float = 0.0
var _is_wandering: bool = false
var _target_pos: Vector2

func _generate_name() -> String:
	return "Companion Idle"

func _enter() -> void:
	_timer = randf_range(2.0, 5.0)
	_is_wandering = false

func _tick(delta: float) -> Status:
	var npc: NPC = agent as NPC
	if not npc: return FAILURE
	
	_timer -= delta
	
	if _timer <= 0:
		if _is_wandering:
			# Finished wandering, wait.
			_is_wandering = false
			_timer = randf_range(3.0, 8.0)
			npc.movement_component.move(Vector2.ZERO)
		else:
			# Start a micro-wander or bark
			if randf() < 0.3: # 30% chance to wander
				_is_wandering = true
				_timer = 2.0 # Wander for 2 seconds max
				var offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized() * randf_range(20, idle_wander_radius)
				_target_pos = npc.global_position + offset
			else:
				# Just wait and maybe bark
				_timer = randf_range(2.0, 5.0)
				if randf() < bark_chance:
					npc.bark(barks.pick_random())

	if _is_wandering:
		var dir = npc.global_position.direction_to(_target_pos)
		if npc.global_position.distance_to(_target_pos) > 5.0:
			npc.movement_component.move(dir * npc.stats.move_speed * 0.5) # Walk slowly
		else:
			_is_wandering = false
			npc.movement_component.move(Vector2.ZERO)
			
	return RUNNING

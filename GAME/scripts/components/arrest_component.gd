extends Node
class_name ArrestComponent

@export var arrest_area: Area2D
@export var arrest_speed: float = 0.4 # Progress per second
@export var release_speed: float = 0.6 # Progress decrease per second when no police near
@export var slow_multiplier: float = 0.1 # Multiply player speed by this when arrested

var arrest_progress: float = 0.0
var is_being_arrested: bool = false
var police_nodes: Array[Node2D] = []

signal arrest_started
signal arrest_finished # BUSTED
signal arrest_cancelled
signal progress_changed(value: float)

@onready var player: Player = owner

func _ready() -> void:
	if arrest_area:
		arrest_area.body_entered.connect(_on_body_entered)
		arrest_area.body_exited.connect(_on_body_exited)
		# Ensure it's detecting the NPC layer (layer 2)
		arrest_area.collision_mask = 2 # NPC layer

func _on_body_entered(body: Node2D) -> void:
	if body is NPC and body.role == NPC.Role.POLICE:
		if not police_nodes.has(body):
			police_nodes.append(body)
		
		if not is_being_arrested:
			is_being_arrested = true
			arrest_started.emit()
			print("ARREST STARTED!")

func _on_body_exited(body: Node2D) -> void:
	if body in police_nodes:
		police_nodes.erase(body)
		if police_nodes.is_empty():
			is_being_arrested = false
			arrest_cancelled.emit()
			print("ARREST CANCELLED!")
			
			# Escaping arrest at 1 star escalates wanted level
			if arrest_progress > 0.0 and HeatManager.wanted_stars == 1:
				print("Player escaped arrest! Escalating heat to 2 stars.")
				HeatManager.set_stars(2)

func _process(delta: float) -> void:
	var prev_progress = arrest_progress
	
	var valid_arrest = is_being_arrested and HeatManager.wanted_stars > 0
	
	if valid_arrest:
		# If the player is armed while being arrested, escalate
		if player and player.has_owned_glock() and HeatManager.wanted_stars == 1:
			print("Player is armed during arrest! Escalating heat to 2 stars.")
			HeatManager.set_stars(2)
			
		arrest_progress += arrest_speed * delta
		if arrest_progress >= 1.0:
			arrest_progress = 1.0
			_handle_busted()
	else:
		arrest_progress -= release_speed * delta
		if arrest_progress < 0.0:
			arrest_progress = 0.0
	
	if prev_progress != arrest_progress:
		progress_changed.emit(arrest_progress)
		_update_player_speed()

func _update_player_speed() -> void:
	if not player or not player.movement_component:
		return
	
	# Immediate slow-down: If we are in the arrest zone or have progress, the player is pinned.
	var current_mult = 1.0
	if is_being_arrested or arrest_progress > 0.0:
		current_mult = slow_multiplier
		
	player.movement_component.speed_multiplier = current_mult

func _handle_busted() -> void:
	is_being_arrested = false
	arrest_finished.emit()
	print("PLAYER BUSTED!")
	if player.has_method("show_bark"):
		player.show_bark("BUSTED!", "combat")
	# You could trigger a signal here for the Game Manager

## Call when the player respawns (e.g. after death) so movement and arrest UI are not stuck.
func reset_for_respawn() -> void:
	is_being_arrested = false
	arrest_progress = 0.0
	police_nodes.clear()
	progress_changed.emit(arrest_progress)
	_update_player_speed()

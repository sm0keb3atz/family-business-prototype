extends Node
class_name StateMachine

signal state_changed(state_name: StringName)

@export var initial_state: NodePath

@onready var state: PlayerState = get_node(initial_state)

func _ready() -> void:
	# Wait for parent to be ready so dependencies are injected
	await owner.ready
	for child in get_children():
		if child is PlayerState:
			child.state_machine = self
			child.player = owner
	
	if state:
		state.enter()

func _unhandled_input(event: InputEvent) -> void:
	if state:
		state.handle_input(event)

func _process(delta: float) -> void:
	if state:
		state.update(delta)

func _physics_process(delta: float) -> void:
	if state:
		state.physics_update(delta)

func transition_to(target_state_name: String, msg: Dictionary = {}) -> void:
	if not has_node(target_state_name):
		return

	state.exit()
	state = get_node(target_state_name)
	state.enter(msg)
	emit_signal("state_changed", target_state_name)

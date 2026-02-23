extends Node
class_name PlayerState

var state_machine: StateMachine
var player: CharacterBody2D # Typed as Player in children if needed

func handle_input(_event: InputEvent) -> void:
	pass

func update(_delta: float) -> void:
	pass

func physics_update(_delta: float) -> void:
	pass

func enter(_msg: Dictionary = {}) -> void:
	pass

func exit() -> void:
	pass

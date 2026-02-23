extends Node2D

@onready var sprite: AnimatedSprite2D = $ShotSpray/AnimatedSprite2D
@onready var particles: GPUParticles2D = $ShotSpray/GPUParticles2D

func _ready() -> void:
	# Start animation
	if sprite:
		sprite.play("default")
		sprite.animation_finished.connect(_on_animation_finished)
	
	# Start particles
	if particles:
		particles.emitting = true
		
	# Fallback timer for cleanup - let particles stay for a bit
	var timer = get_tree().create_timer(30.0)
	timer.timeout.connect(queue_free)

func _on_animation_finished() -> void:
	# Hide sprite but keep the node alive for particles and timer
	if sprite:
		sprite.visible = false

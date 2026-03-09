extends Node2D

@onready var sprite: AnimatedSprite2D = $ShotSpray/AnimatedSprite2D
@onready var particles: GPUParticles2D = $ShotSpray/GPUParticles2D
@onready var pool_particles: GPUParticles2D = $BloodPool/GPUParticles2D

func _ready() -> void:
	# Fallback timer for cleanup - let particles stay for a bit
	var timer = get_tree().create_timer(40.0)
	timer.timeout.connect(queue_free)

func start_spray() -> void:
	if sprite:
		sprite.visible = true
		sprite.play("default")
		if not sprite.animation_finished.is_connected(_on_animation_finished):
			sprite.animation_finished.connect(_on_animation_finished)
	
	if particles:
		particles.emitting = true

func start_pooling() -> void:
	if pool_particles:
		pool_particles.emitting = true

func _on_animation_finished() -> void:
	# Hide sprite but keep the node alive for particles and timer
	if sprite:
		sprite.visible = false

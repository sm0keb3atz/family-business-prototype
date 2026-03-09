extends Area2D
class_name BulletBase

@export var speed: float = 1000.0
@export var damage: int = 0
@export var lifetime: float = 2.0

@export_group("Impact Sounds")
@export var body_impact_sounds: Array[AudioStream] = []
@export var stone_impact_sounds: Array[AudioStream] = []

var direction: Vector2 = Vector2.ZERO
var shooter: Node2D

func initialize(p_direction: Vector2, p_damage: int, p_shooter: Node2D = null) -> void:
	direction = p_direction.normalized()
	damage = p_damage
	shooter = p_shooter
	rotation = direction.angle()

func _ready() -> void:
	var timer = Timer.new()
	timer.wait_time = lifetime
	timer.one_shot = true
	timer.timeout.connect(queue_free)
	add_child(timer)
	timer.start()
	
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

func _physics_process(delta: float) -> void:
	position += direction * speed * delta

func _on_area_entered(area: Area2D) -> void:
	# Forward to parent body if it has health
	var parent = area.get_parent()
	if parent:
		_on_body_entered(parent)

func _on_body_entered(body: Node) -> void:
	if body == shooter:
		return
		
	if body.is_in_group("player") and shooter and shooter.is_in_group("player"): # Don't hit shooter if player
		return
		
	# Play Impact Sound
	_play_impact_sound(body)
		
	if body.has_method("take_damage"):
		body.take_damage(damage, global_position, direction)
	elif body.has_node("HealthComponent"):
		var health = body.get_node("HealthComponent")
		if health.has_method("take_damage"):
			health.take_damage(damage)
			 
	queue_free()

func _play_impact_sound(body: Node) -> void:
	var sound_pool = stone_impact_sounds
	if body.is_in_group("npc") or body.is_in_group("player"):
		sound_pool = body_impact_sounds
		
	if sound_pool.size() > 0:
		var sound = sound_pool.pick_random()
		if sound:
			var player = AudioStreamPlayer2D.new()
			player.stream = sound
			player.global_position = global_position
			player.bus = &"Master" # Or specific SFX bus if available
			get_tree().current_scene.add_child(player)
			player.play()
			player.finished.connect(player.queue_free)

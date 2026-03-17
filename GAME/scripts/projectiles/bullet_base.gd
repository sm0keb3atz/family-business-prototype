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
var _destroyed: bool = false

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
	if _destroyed:
		return

	_check_direct_overlaps()
	if _destroyed:
		return

	var motion := direction * speed * delta
	if motion.is_zero_approx():
		return

	var start := global_position
	var target := start + motion
	var hit := _sweep_for_hit(start, target)
	if hit.is_empty():
		global_position = target
		return

	global_position = hit.get("position", target)
	_handle_collision(hit.get("collider"))


func _sweep_for_hit(start: Vector2, target: Vector2) -> Dictionary:
	var query := PhysicsRayQueryParameters2D.create(start, target, collision_mask)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.hit_from_inside = true
	query.exclude = [self]
	if shooter:
		query.exclude.append(shooter)

	return get_world_2d().direct_space_state.intersect_ray(query)


func _check_direct_overlaps() -> void:
	for body in get_overlapping_bodies():
		if _is_valid_hit_target(body):
			_handle_collision(body)
			return

	for area in get_overlapping_areas():
		if area == self:
			continue
		if _is_valid_hit_target(area):
			_handle_collision(area)
			return

		var parent := area.get_parent()
		if _is_valid_hit_target(parent):
			_handle_collision(parent)
			return

func _on_area_entered(area: Area2D) -> void:
	if _destroyed:
		return

	_handle_collision(area)
	# Forward to parent body if it has health
	var parent = area.get_parent()
	if parent:
		_on_body_entered(parent)

func _on_body_entered(body: Node) -> void:
	if _destroyed:
		return

	_handle_collision(body)


func _resolve_hit_target(collider: Node) -> Node:
	var current := collider
	while current:
		if current.has_method("take_damage") or current.has_node("HealthComponent"):
			return current
		current = current.get_parent()
	return collider


func _is_valid_hit_target(body: Node) -> bool:
	if not body:
		return false

	var target := _resolve_hit_target(body)
	if target == shooter:
		return false

	if target.is_in_group("player") and shooter and shooter.is_in_group("player"):
	if body == shooter:
		return false

	if body.is_in_group("player") and shooter and shooter.is_in_group("player"):
		return false

	return true


func _handle_collision(collider: Node) -> void:
	if _destroyed:
		return

	var body := _resolve_hit_target(collider)
	if not _is_valid_hit_target(body):
		return

func _handle_collision(body: Node) -> void:
	if _destroyed or not _is_valid_hit_target(body):
		return

	_destroyed = true

	# Play Impact Sound
	_play_impact_sound(body)
		
	if body.has_method("take_damage"):
		body.take_damage(damage, global_position, direction, shooter)
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

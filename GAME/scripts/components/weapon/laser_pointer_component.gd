extends Node2D
class_name LaserPointerComponent

@export var is_active: bool = false:
	set(value):
		is_active = value
		_update_visibility()

var is_aiming: bool = false:
	set(value):
		is_aiming = value
		_update_visibility()

@export var beam_color: Color = Color.RED:
	set(value):
		beam_color = value
		if line:
			line.default_color = value
		if dot:
			dot.modulate = value

@onready var ray_cast: RayCast2D = $RayCast2D
@onready var line: Line2D = $Line2D
@onready var dot: Sprite2D = $Dot

var is_blocked: bool = false # True if laser is hitting a solid wall/building

func _ready() -> void:
	_update_visibility()
	if line:
		line.default_color = beam_color
	if dot:
		dot.modulate = beam_color

func _process(_delta: float) -> void:
	if not is_aiming:
		is_blocked = false
		return
		
	if ray_cast.is_colliding():
		var collision_point = ray_cast.get_collision_point()
		var local_point = to_local(collision_point)
		
		# Visuals: only update if active
		if is_active:
			line.points = [Vector2.ZERO, local_point]
			line.visible = true
			dot.visible = true
			dot.position = local_point
		else:
			line.visible = false
			dot.visible = false
		
		# Blocking logic: always update when aiming
		var collider = ray_cast.get_collider()
		if collider and (collider.collision_layer & 1): # Layer 1 check
			is_blocked = true
		else:
			is_blocked = false
	else:
		# Visuals: only update if active
		if is_active:
			var end_point = Vector2(ray_cast.target_position.x, 0)
			line.points = [Vector2.ZERO, end_point]
			line.visible = true
			dot.visible = false
		else:
			line.visible = false
			dot.visible = false
			
		is_blocked = false

func _update_visibility() -> void:
	# Note: We now always process if is_aiming is true, so we can detect blocking for all weapons
	visible = is_aiming # Container must be visible to process children
	set_process(is_aiming)
	
	# Initial visual state
	if line: line.visible = is_active and is_aiming
	if dot: dot.visible = is_active and is_aiming and ray_cast.is_colliding()

func add_collision_exception(node: CollisionObject2D) -> void:
	if not is_node_ready(): await ready
	if ray_cast and node:
		ray_cast.add_exception(node)

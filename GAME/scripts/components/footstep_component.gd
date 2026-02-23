extends Node
class_name FootstepComponent

@export var animation_player: AnimationPlayer
@export var body_sprite: Sprite2D
@export var dust_sprite: AnimatedSprite2D
@export var footstep_audio: AudioStreamPlayer2D

var footstep_sounds: Array[AudioStream] = []

var _last_anim_pos: float = 0.0
var _last_sprite_frame: int = -1
var _walk_frame_index: int = 0
var _current_anim: String = ""

func _ready() -> void:
	_load_footstep_sounds()
	if dust_sprite:
		dust_sprite.animation_finished.connect(func(): dust_sprite.visible = false)
		dust_sprite.visible = false

func _load_footstep_sounds() -> void:
	var dir = DirAccess.open("res://GAME/assets/audio/footsteps")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".ogg") and not file_name.ends_with(".import"):
				var sound = load("res://GAME/assets/audio/footsteps/" + file_name)
				if sound:
					footstep_sounds.append(sound)
			file_name = dir.get_next()

func _process(_delta: float) -> void:
	if not animation_player or not body_sprite:
		return
		
	var anim = animation_player.current_animation
	if anim != _current_anim:
		_current_anim = anim
		_walk_frame_index = 1
		_last_anim_pos = 0.0
		_last_sprite_frame = body_sprite.frame
		
	if anim.begins_with("walk"):
		var pos = animation_player.current_animation_position
		
		# Detect loop wrap-around
		if pos < _last_anim_pos:
			_walk_frame_index = 1
			_last_sprite_frame = body_sprite.frame
			
		_last_anim_pos = pos
		
		# Detect when the sprite actually changes frame to count walk steps
		if body_sprite.frame != _last_sprite_frame:
			_last_sprite_frame = body_sprite.frame
			_walk_frame_index += 1
			
			if _walk_frame_index == 2 or _walk_frame_index == 5:
				_trigger_footstep()

func _trigger_footstep() -> void:
	if dust_sprite:
		dust_sprite.visible = true
		dust_sprite.frame = 0
		dust_sprite.play("default")
		
	if footstep_audio and footstep_sounds.size() > 0:
		var rand_index = randi() % footstep_sounds.size()
		footstep_audio.stream = footstep_sounds[rand_index]
		footstep_audio.pitch_scale = randf_range(0.9, 1.1)
		footstep_audio.play()

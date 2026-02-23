extends Node2D
class_name WeaponBase

@export var weapon_data: WeaponDataResource

# Node References
@export_group("Visuals")
@export var visual_root: Node2D
@export var sprite: Sprite2D
@export var reload_sprite: Sprite2D
@export var muzzle_flash: Sprite2D
@export var muzzle_light: PointLight2D
@export var animation_player: AnimationPlayer
@export var audio_stream_player_2d: AudioStreamPlayer2D
@export var fire_point: Marker2D

@export_group("Components")
@export var ammo_component: AmmoComponent
@export var fire_control_component: FireControlComponent
@export var recoil_component: RecoilComponent
@export var spread_component: SpreadComponent

@export_group("Timers")
@export var cooldown_timer: Timer
@export var reload_timer: Timer

@export_group("Feedback")
@export var shoot_sound: AudioStream
@export var empty_mag_sound: AudioStream
@export var shake_intensity: float = 0.7
@export var shake_duration: float = 0.5 # No longer used but kept for data compatibility if needed

var is_reloading: bool = false # Local tracking for animation state if needed

func _ready() -> void:
	# Fallback/Auto-injection for nodes by name if exports are NULL
	if not fire_point: fire_point = get_node_or_null("FirePoint")
	if not animation_player: animation_player = get_node_or_null("AnimationPlayer")
	if not audio_stream_player_2d: audio_stream_player_2d = get_node_or_null("AudioStreamPlayer2D")
	if not visual_root: visual_root = get_node_or_null("Visual")
	if not sprite: 
		sprite = get_node_or_null("Visual/GlockShoot")
		if not sprite: sprite = get_node_or_null("Visual/Sprite")
	if not reload_sprite:
		reload_sprite = get_node_or_null("Visual/GlockReload")
		if not reload_sprite: reload_sprite = get_node_or_null("Visual/ReloadSprite")
	if not muzzle_flash: muzzle_flash = get_node_or_null("Visual/MuzzleFlash")
	if not muzzle_light: muzzle_light = get_node_or_null("Visual/MuzzleLight")
	
	# Components
	if not ammo_component and has_node("Components/AmmoComponent"): ammo_component = $Components/AmmoComponent
	if not fire_control_component and has_node("Components/FireControlComponent"): fire_control_component = $Components/FireControlComponent
	if not recoil_component and has_node("Components/RecoilComponent"): recoil_component = $Components/RecoilComponent
	if not spread_component and has_node("Components/SpreadComponent"): spread_component = $Components/SpreadComponent
	
	# Timers
	if not cooldown_timer: cooldown_timer = get_node_or_null("CooldownTimer")
	if not reload_timer: reload_timer = get_node_or_null("ReloadTimer")
	
	if weapon_data:
		initialize(weapon_data)

func initialize(data: WeaponDataResource) -> void:
	weapon_data = data
	
	# Initialize components
	if fire_control_component and not fire_control_component.cooldown_timer:
		fire_control_component.cooldown_timer = cooldown_timer
		
	ammo_component.initialize(data)
	fire_control_component.initialize(data)
	spread_component.initialize(data)
	recoil_component.initialize(data)
	
	# Setup Timers
	reload_timer.wait_time = data.reload_time
	reload_timer.one_shot = true
	
	# Connect signals
	if not reload_timer.timeout.is_connected(_on_reload_timer_timeout):
		reload_timer.timeout.connect(_on_reload_timer_timeout)
		
	if not ammo_component.reload_finished.is_connected(_on_reload_finished):
		ammo_component.reload_finished.connect(_on_reload_finished)

	if muzzle_flash:
		muzzle_flash.visible = false
	if muzzle_light:
		muzzle_light.enabled = false
	if reload_sprite:
		reload_sprite.visible = false
	if sprite:
		sprite.visible = true
	
	if animation_player and animation_player.has_animation("RESET"):
		animation_player.play("RESET")

func fire() -> void:
	if is_reloading:
		return
		
	if not fire_control_component.can_fire():
		return
		
	if not ammo_component.can_fire():
		if ammo_component.current_ammo == 0:
			if ammo_component.can_reload():
				reload()
			_play_empty_sound()
		return

	# Execute Fire
	print("Fire executed!")
	ammo_component.consume_ammo()
	fire_control_component.start_cooldown()
	
	_spawn_bullet()
	_play_fire_effects()
	recoil_component.apply_recoil()

func reload() -> void:
	if is_reloading or not ammo_component.can_reload():
		return
		
	is_reloading = true
	
	if sprite: sprite.visible = false
	if reload_sprite: reload_sprite.visible = true
	
	ammo_component.start_reload()
	reload_timer.start()
	
	if animation_player:
		if animation_player.has_animation("glock_reload"):
			animation_player.play("glock_reload")
		elif animation_player.has_animation("reload"):
			animation_player.play("reload")

func _spawn_bullet() -> void:
	if not weapon_data.bullet_scene:
		printerr("No bullet scene assigned to weapon data!")
		return
		
	if not fire_point:
		printerr("ERROR: fire_point is NULL on ", name, ". Placing bullet at weapon root.")
	
	var bullet = weapon_data.bullet_scene.instantiate()
	
	# Calculate direction with spread
	var dir = Vector2.RIGHT.rotated(global_rotation)
	# Apply spread
	dir = spread_component.get_spread_direction(dir)
	
	bullet.global_position = fire_point.global_position if fire_point else global_position
	bullet.initialize(dir, weapon_data.damage)
	
	get_tree().current_scene.add_child(bullet)

func _play_fire_effects() -> void:
	var animation_played = false
	if animation_player == null:
		print("ERROR: animation_player is NULL on ", name)
	
	if animation_player:
		var anim_to_play = ""
		if animation_player.has_animation("fire"):
			anim_to_play = "fire"
		elif animation_player.has_animation("glock_shoot"): 
			anim_to_play = "glock_shoot"
			
		if anim_to_play != "":
			print("Playing animation: ", anim_to_play)
			animation_player.stop()
			animation_player.play(anim_to_play)
			animation_played = true
		else:
			print("No animation found 'fire' or 'glock_shoot'. Available: ", animation_player.get_animation_list())
	
	# Play Fire Sound
	if shoot_sound and audio_stream_player_2d:
		audio_stream_player_2d.stream = shoot_sound
		audio_stream_player_2d.play()
	
	# Trigger Screen Shake
	var cameras = get_tree().get_nodes_in_group("camera")
	for cam in cameras:
		if cam.has_method("add_trauma"):
			cam.add_trauma(shake_intensity)
		elif cam.has_method("shake"):
			cam.shake(shake_intensity, shake_duration)
		
	# Only use manual effects/fallback if no animation handled it
	if not animation_played:
		if muzzle_flash:
			muzzle_flash.visible = true
			var tween = create_tween()
			tween.tween_property(muzzle_flash, "visible", false, 0.05)
			
		if muzzle_light:
			muzzle_light.enabled = true
			var tween = create_tween()
			tween.tween_property(muzzle_light, "enabled", false, 0.05)

func _on_reload_timer_timeout() -> void:
	ammo_component.finish_reload()

func _on_reload_finished() -> void:
	is_reloading = false
	if sprite: sprite.visible = true
	if reload_sprite: reload_sprite.visible = false
	print("Reload finished.")

func _play_empty_sound() -> void:
	if empty_mag_sound and audio_stream_player_2d:
		# Don't interrupt shooting sounds if possible, but dry fire is exclusive usually
		audio_stream_player_2d.stream = empty_mag_sound
		audio_stream_player_2d.play()

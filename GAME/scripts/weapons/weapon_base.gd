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
@export var laser_pointer: LaserPointerComponent

@export_group("Timers")
@export var cooldown_timer: Timer
@export var reload_timer: Timer

@export_group("Feedback")
@export var shake_intensity: float = 0.7
@export var shake_duration: float = 0.5 # No longer used but kept for data compatibility if needed
var shooter: Node2D # The character firing this weapon
var is_aiming: bool = false:
	set(value):
		if is_aiming == value:
			return
		is_aiming = value
		
		# Update Laser Pointer
		if laser_pointer:
			laser_pointer.is_aiming = value
			
		# Handle Player-only feedback
		if shooter and shooter.is_in_group("player"):
			_update_aiming_feedback(value)
			if value and weapon_data and weapon_data.aim_sound:
				_play_sound(weapon_data.aim_sound)

func _update_aiming_feedback(active: bool) -> void:
	# 1. Update Cursor
	if active and weapon_data and weapon_data.crosshair_texture:
		if _crosshair_sprite:
			_crosshair_sprite.texture = weapon_data.crosshair_texture
			_crosshair_sprite.visible = true
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
		print("WeaponBase: Showing Sprite2D crosshair: ", weapon_data.crosshair_texture.resource_path)
	else:
		if _crosshair_sprite:
			_crosshair_sprite.visible = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		print("WeaponBase: Hidden Sprite2D crosshair")
	
	# 2. Update Camera Parameters
	var cameras = get_tree().get_nodes_in_group("camera")
	for cam in cameras:
		if cam.has_method("set_weapon_aim_params"):
			if active:
				cam.set_weapon_aim_params(weapon_data.aim_zoom, weapon_data.camera_follow_distance)
			else:
				cam.set_weapon_aim_params(Vector2(1.0, 1.0), 0.0) # Reset to defaults

var is_reloading: bool = false # Local tracking for animation state if needed
var _trigger_released: bool = true # For semi-auto behavior
var _last_empty_sound_time: float = 0.0
var _crosshair_sprite: Sprite2D
var _scouting_raycast: RayCast2D # Universal raycast for transparency checks

func _ready() -> void:
	# Fallback/Auto-injection for nodes by name if exports are NULL
	if not fire_point: fire_point = get_node_or_null("FirePoint")
	if not animation_player: animation_player = get_node_or_null("AnimationPlayer")
	if not audio_stream_player_2d: audio_stream_player_2d = get_node_or_null("AudioStreamPlayer2D")
	if not visual_root: visual_root = get_node_or_null("Visual")
	if not sprite: 
		sprite = get_node_or_null("Glock/GlockShoot")
		if not sprite: sprite = get_node_or_null("Visual/GlockShoot")
		if not sprite: sprite = get_node_or_null("Visual/Sprite")
	if not reload_sprite:
		reload_sprite = get_node_or_null("Glock/GlockReload")
		if not reload_sprite: reload_sprite = get_node_or_null("Visual/GlockReload")
		if not reload_sprite: reload_sprite = get_node_or_null("Visual/ReloadSprite")
	if not muzzle_flash: 
		muzzle_flash = get_node_or_null("Visual/MuzzleFlash")
		if not muzzle_flash: muzzle_flash = get_node_or_null("MuzzleFlash")
	if not muzzle_light: 
		muzzle_light = get_node_or_null("Visual/MuzzleLight")
		if not muzzle_light: muzzle_light = get_node_or_null("MuzzleLight")
	if not laser_pointer:
		laser_pointer = get_node_or_null("LaserPointer")
		if not laser_pointer: laser_pointer = get_node_or_null("Visual/LaserPointer")
	
	_setup_custom_crosshair()
	_setup_scouting_raycast()
	
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
	
	# Auto-assign defaults for empty fields to ensure level distinction
	_ensure_weapon_defaults()
	
	if audio_stream_player_2d:
		audio_stream_player_2d.max_polyphony = 8
		if data.switch_sound:
			_play_sound(data.switch_sound)
	
	# Update Visuals
	if sprite and data.weapon_sprite:
		sprite.texture = data.weapon_sprite
	
	if laser_pointer:
		laser_pointer.is_active = data.has_laser
		laser_pointer.beam_color = data.laser_color
		if shooter:
			laser_pointer.add_collision_exception(shooter)
	
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

func _setup_custom_crosshair() -> void:
	if _crosshair_sprite: return
	
	# Create a CanvasLayer so the crosshair is always on top of everything
	var cl = CanvasLayer.new()
	cl.name = "CrosshairLayer"
	add_child(cl)
	
	_crosshair_sprite = Sprite2D.new()
	_crosshair_sprite.name = "CustomCrosshair"
	_crosshair_sprite.top_level = true
	_crosshair_sprite.z_index = 100
	_crosshair_sprite.centered = true
	_crosshair_sprite.scale = Vector2(0.35, 0.35) # Made even smaller
	_crosshair_sprite.visible = false
	cl.add_child(_crosshair_sprite)

func _setup_scouting_raycast() -> void:
	if _scouting_raycast: return
	_scouting_raycast = RayCast2D.new()
	_scouting_raycast.name = "ScoutingRayCast"
	_scouting_raycast.enabled = true
	_scouting_raycast.collision_mask = 1 # Building/World layer
	_scouting_raycast.target_position = Vector2(1000, 0) # Long range
	add_child(_scouting_raycast)
	if shooter:
		_scouting_raycast.add_exception(shooter)

func _ensure_weapon_defaults() -> void:
	if not weapon_data: return
	
	# 1. Auto-assign Crosshair if missing
	if weapon_data.crosshair_texture == null:
		# Try to find a crosshair in the assets folder
		var crosshair_path = "res://GAME/assets/sprites/weapons/crosshairs/crosshair134.png" # Safe fallback
		if FileAccess.file_exists(crosshair_path):
			weapon_data.crosshair_texture = load(crosshair_path)
			weapon_data.crosshair_hotspot = Vector2(16, 16)
	
	# 2. Level-based distinct behavior if values are default/minimal
	# Level 4 should feel MASSIVE, Level 1 should feel TIGHT
	var lv = weapon_data.level
	
	# If follow distance is small/default, scale it by level
	if weapon_data.camera_follow_distance <= 200.0:
		weapon_data.camera_follow_distance = 150.0 + (lv * 100.0) # Lv1: 250, Lv4: 550
	
	# If zoom is default, scale it
	# Note: Higher level = MORE zoomed out (lower Vector2 values) to see more
	# Rebalanced: Lv4 was 0.7, now making it ~0.9 for less "ridiculous" zoom
	if weapon_data.aim_zoom == Vector2(1.2, 1.2):
		var zoom_val = 1.2 - (lv * 0.08) # Lv1: 1.12, Lv4: 0.88
		weapon_data.aim_zoom = Vector2(zoom_val, zoom_val)

func fire() -> void:
	if is_reloading:
		return
		
	# Handle Semi-Auto trigger
	if weapon_data and not weapon_data.automatic and not _trigger_released:
		return
	
	if not fire_control_component.can_fire():
		return
		
	if not ammo_component.can_fire():
		if ammo_component.current_ammo == 0:
			if _trigger_released:
				_play_empty_sound()
				_trigger_released = false # Anti-spam
		return

	# Execute Fire
	_trigger_released = false
	print("Fire executed!")
	ammo_component.consume_ammo()
	fire_control_component.start_cooldown()
	
	_spawn_bullet()
	_play_fire_effects()
	recoil_component.apply_recoil()
	
	if shooter and shooter.is_in_group("player") and has_node("/root/HeatManager"):
		get_node("/root/HeatManager").on_gunshot(global_position)

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
	bullet.initialize(dir, weapon_data.damage, shooter if shooter else owner)
	
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
	
	# Play Fire Sound (AI officers get subtle random pitch/volume variation for less robotic volleys)
	if weapon_data and weapon_data.shoot_sound:
		if _is_police_shooter():
			_play_sound_with_variation(weapon_data.shoot_sound, randf_range(0.93, 1.08), randf_range(-1.5, 0.5))
		else:
			_play_sound(weapon_data.shoot_sound)
	
	# Trigger Screen Shake (Only if player is the shooter)
	if shooter and shooter.is_in_group("player"):
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

func _process(_delta: float) -> void:
	if is_aiming:
		var mouse_pos = get_global_mouse_position()
		if _crosshair_sprite and _crosshair_sprite.visible:
			_crosshair_sprite.global_position = get_viewport().get_mouse_position()
		
		if _scouting_raycast:
			_scouting_raycast.look_at(mouse_pos)
			_scouting_raycast.force_raycast_update()
		
	if shooter and shooter.is_in_group("player"):
		if not Input.is_action_pressed("fire"):
			_trigger_released = true
	else:
		# For non-players (AI), we might want a different way to reset trigger 
		# but for now we assume they call fire() deliberately.
		# If AI calls fire every frame, it will still be auto.
		# This is a documented limitation/behavior for semi-auto weapons in this system.
		_trigger_released = true 

func is_aiming_blocked() -> bool:
	if not is_aiming: return false
	
	if _scouting_raycast and _scouting_raycast.is_colliding():
		var col_point = _scouting_raycast.get_collision_point()
		
		# User Logic: 
		# If player is North of the hit (player.y < col_point.y), they CAN see.
		# If player is South of the hit (player.y >= col_point.y), they CANNOT see.
		if shooter:
			if shooter.global_position.y < col_point.y:
				return false # Not blocked (Can see)
			else:
				return true # Blocked (South of wall)
				
	return false

func _on_reload_timer_timeout() -> void:
	ammo_component.finish_reload()

func _on_reload_finished() -> void:
	is_reloading = false
	if sprite: sprite.visible = true
	if reload_sprite: reload_sprite.visible = false
	print("Reload finished.")

func _play_empty_sound() -> void:
	# Prevent spamming the sound
	if Time.get_ticks_msec() - _last_empty_sound_time < 500:
		return
		
	if weapon_data and weapon_data.empty_mag_sound:
		_last_empty_sound_time = Time.get_ticks_msec()
		_play_sound(weapon_data.empty_mag_sound)


func _is_police_shooter() -> bool:
	if not shooter:
		return false
	if not shooter.is_in_group("npc"):
		return false
	var role_value = shooter.get("role")
	if role_value == null:
		return false
	# NPC.Role.POLICE == 2
	return int(role_value) == 2

func _play_sound_with_variation(stream: AudioStream, pitch_scale: float, volume_db: float = 0.0) -> void:
	if not stream or not audio_stream_player_2d:
		return
	audio_stream_player_2d.pitch_scale = pitch_scale
	audio_stream_player_2d.volume_db = volume_db
	_play_sound(stream)
	# Reset to defaults so UI/reload sounds aren't permanently modified.
	audio_stream_player_2d.pitch_scale = 1.0
	audio_stream_player_2d.volume_db = 0.0

func _play_sound(stream: AudioStream) -> void:
	if not stream or not audio_stream_player_2d: return
	
	# If we are using polyphony, we should avoid resetting the stream 
	# if it's already the same, or just use play() if it's already set.
	if audio_stream_player_2d.stream != stream:
		audio_stream_player_2d.stream = stream
	
	audio_stream_player_2d.play()

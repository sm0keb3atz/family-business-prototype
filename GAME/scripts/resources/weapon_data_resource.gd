extends Resource
class_name WeaponDataResource

@export var level: int = 1

@export var damage: int = 10
@export var fire_rate: float = 0.5
@export var reload_time: float = 1.0
@export var magazine_size: int = 30
@export var reserve_ammo: int = 120
@export var bullet_scene: PackedScene
@export var recoil_strength: float = 5.0
@export var spread_degrees: float = 5.0
@export var automatic: bool = false

@export_group("Visuals")
@export var weapon_sprite: Texture2D
@export var crosshair_texture: Texture2D ## Texture to use for the mouse cursor when aiming
@export var has_laser: bool = false
@export var laser_color: Color = Color.RED

@export_group("Aiming")
@export var aim_zoom: Vector2 = Vector2(1.2, 1.2) ## Zoom level when aiming (lower = more visible area)
@export var camera_follow_distance: float = 200.0 ## Max pixels to offset camera towards mouse
@export var crosshair_hotspot: Vector2 = Vector2(16, 16) ## Center of the crosshair image

@export_group("Audio")
@export var shoot_sound: AudioStream
@export var empty_mag_sound: AudioStream
@export var switch_sound: AudioStream
@export var aim_sound: AudioStream

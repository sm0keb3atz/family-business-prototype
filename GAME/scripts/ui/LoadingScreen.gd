extends Control

@export var scene_to_load: String = "res://GAME/scenes/World.tscn"
@export var prewarm_duration: float = 1.5
@export var fade_duration: float = 0.5

@onready var progress_bar: ProgressBar = $ProgressBar
@onready var bg: ColorRect = $ColorRect

var _is_loading: bool = false
var _is_prewarming: bool = false
var _loading_progress: Array = []
var _cached_hud: CanvasLayer = null

func _ready() -> void:
	# Ensure smooth start
	modulate.a = 1.0
	
	# Start background load
	var err = ResourceLoader.load_threaded_request(scene_to_load)
	if err == OK:
		_is_loading = true
		print("LoadingScreen: Started background load for %s" % scene_to_load)
	else:
		push_error("LoadingScreen: Failed to start loading %s. Error: %s" % [scene_to_load, err])

func _process(_delta: float) -> void:
	if not _is_loading or _is_prewarming:
		return
		
	var status = ResourceLoader.load_threaded_get_status(scene_to_load, _loading_progress)
	
	match status:
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			if _loading_progress.size() > 0:
				progress_bar.value = _loading_progress[0] * 100.0
		ResourceLoader.THREAD_LOAD_LOADED:
			progress_bar.value = 100.0
			_is_loading = false
			_start_prewarm_phase()
		ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			push_error("LoadingScreen: Background load failed!")
			_is_loading = false

func _start_prewarm_phase() -> void:
	print("LoadingScreen: Scene fully loaded. Starting pre-warm phase.")
	_is_prewarming = true
	
	# Instance the loaded scene
	var packed_scene = ResourceLoader.load_threaded_get(scene_to_load) as PackedScene
	var new_scene = packed_scene.instantiate()
	
	# Add to root (behind this loading screen, which should be on top either via CanvasLayer or order)
	var root = get_tree().root
	root.add_child(new_scene)
	get_tree().current_scene = new_scene
	
	# Find and hide HUD
	_cached_hud = _find_hud(new_scene)
	if _cached_hud:
		_cached_hud.visible = false
	
	# Visual indication that we are pre-arming (spawning NPCs, etc)
	# ProgressBar can stay at 100%
	
	print("LoadingScreen: Waiting %s seconds for system initialization and spawns..." % prewarm_duration)
	await get_tree().create_timer(prewarm_duration).timeout
	print("LoadingScreen: Pre-warm complete. Transitioning.")
	
	_finish_loading()

func _finish_loading() -> void:
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, fade_duration).set_ease(Tween.EASE_OUT)
	tween.finished.connect(func():
		if is_instance_valid(_cached_hud):
			_cached_hud.visible = true
		queue_free()
	)

func _find_hud(node: Node) -> CanvasLayer:
	if node is HUD:
		return node
	for child in node.get_children():
		var found = _find_hud(child)
		if found:
			return found
	return null

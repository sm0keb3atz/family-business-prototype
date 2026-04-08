extends Control

@export var scene_to_load: String = "res://GAME/scenes/World.tscn"
@export var fade_duration: float = 0.5

@onready var progress_bar: ProgressBar = $ProgressBar

var _loading_started: bool = false

func _ready() -> void:
	modulate.a = 1.0
	progress_bar.value = 0.0
	# Wait a frame to ensure the UI is visible before starting the thread
	call_deferred("_begin_load")

func _begin_load() -> void:
	var err = ResourceLoader.load_threaded_request(scene_to_load)
	if err != OK:
		push_error("LoadingScreen: Failed to initiate threaded load for %s (Error: %d)" % [scene_to_load, err])
		return
	_loading_started = true

func _process(_delta: float) -> void:
	if not _loading_started:
		return
		
	var progress = []
	var status = ResourceLoader.load_threaded_get_status(scene_to_load, progress)
	
	match status:
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			progress_bar.value = progress[0] * 100.0
		ResourceLoader.THREAD_LOAD_LOADED:
			_loading_started = false
			progress_bar.value = 100.0
			var packed_scene = ResourceLoader.load_threaded_get(scene_to_load) as PackedScene
			# Small delay so user sees 100%
			await get_tree().create_timer(0.5).timeout
			_transition_to_scene(packed_scene)
		ResourceLoader.THREAD_LOAD_FAILED:
			_loading_started = false
			push_error("LoadingScreen: Threaded load FAILED for %s" % scene_to_load)
		ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			_loading_started = false
			push_error("LoadingScreen: Invalid resource path: %s" % scene_to_load)

func _transition_to_scene(packed_scene: PackedScene) -> void:
	if not packed_scene:
		push_error("LoadingScreen: Cannot transition, packed_scene is null")
		return
		
	# Smoothly fade out the Loading Screen UI to black
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, fade_duration).set_ease(Tween.EASE_OUT)
	await tween.finished
	
	# Transition to the black World scene.
	# The World scene (via MapManager) will handle the synchronized fade-in.
	get_tree().change_scene_to_packed(packed_scene)

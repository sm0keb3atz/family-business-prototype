extends Node

# UI Sounds
var sound_ui_click = preload("res://GAME/assets/audio/ui-feedback/menu_button_click.ogg")
var sound_ui_menu = preload("res://GAME/assets/audio/ui-feedback/menu_close-open.ogg")
var sound_transaction = preload("res://GAME/assets/audio/ui-feedback/transaction.ogg")

# Solicitation Sounds
var solicitation_sounds: Array[AudioStream] = [
	preload("res://GAME/assets/audio/dialog/solicitation1.ogg"),
	preload("res://GAME/assets/audio/dialog/solicitation2.ogg"),
	preload("res://GAME/assets/audio/dialog/solicitation3.ogg")
]

# Customer Voice Sounds
var customer_male_sounds: Array[AudioStream] = []
var customer_female_sounds: Array[AudioStream] = []

func _ready() -> void:
	# Keep running during pause for UI sounds
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	_load_customer_sounds()
	
	# Hook into tree to catch new buttons and connect click sounds
	get_tree().node_added.connect(_on_node_added)
	
	# Connect existing buttons
	for node in get_tree().get_nodes_in_group("buttons"):
		if node is Button:
			_connect_button(node)
	
	# Also search all existing buttons initially
	_connect_all_buttons(get_tree().root)

func _load_customer_sounds() -> void:
	# Load male sounds
	var male_path = "res://GAME/assets/audio/dialog/customer/male/"
	var dir_m = DirAccess.open(male_path)
	if dir_m:
		dir_m.list_dir_begin()
		var file_name = dir_m.get_next()
		while file_name != "":
			if file_name.ends_with(".ogg") and not file_name.ends_with(".import"):
				customer_male_sounds.append(load(male_path + file_name))
			file_name = dir_m.get_next()
			
	# Load female sounds
	var female_path = "res://GAME/assets/audio/dialog/customer/female/"
	var dir_f = DirAccess.open(female_path)
	if dir_f:
		dir_f.list_dir_begin()
		var file_name = dir_f.get_next()
		while file_name != "":
			if file_name.ends_with(".ogg") and not file_name.ends_with(".import"):
				customer_female_sounds.append(load(female_path + file_name))
			file_name = dir_f.get_next()

func _on_node_added(node: Node) -> void:
	if node is BaseButton or node is TabContainer:
		_connect_button(node)

func _connect_all_buttons(root: Node) -> void:
	for child in root.get_children():
		if child is BaseButton or child is TabContainer:
			_connect_button(child)
		_connect_all_buttons(child)

func _connect_button(node: Node) -> void:
	if node is BaseButton:
		if not node.pressed.is_connected(play_ui_click):
			node.pressed.connect(play_ui_click)
	elif node is TabContainer:
		if not node.tab_clicked.is_connected(_on_tab_clicked):
			node.tab_clicked.connect(_on_tab_clicked)

func _on_tab_clicked(_tab: int) -> void:
	play_ui_click()

# --- Playback Functions ---

func play_ui_click() -> void:
	_play_sound(sound_ui_click, "UI_Click", 0.8)

func play_ui_menu() -> void:
	_play_sound(sound_ui_menu, "UI_Menu", 1.0)

func play_transaction() -> void:
	_play_sound(sound_transaction, "Transaction", 1.0)

func play_random_solicitation() -> void:
	if solicitation_sounds.is_empty(): return
	var sound = solicitation_sounds.pick_random()
	_play_sound(sound, "Solicitation", 1.0)


func play_customer_dialog(gender: int, pos: Vector2) -> void:
	var pool = customer_male_sounds if gender == 0 else customer_female_sounds
	if pool.is_empty(): return
	var sound = pool.pick_random()
	# Full volume (0.0 dB) for better clarity
	_play_sound_2d(sound, pos, "Dialog", 0.0)

func _play_sound(stream: AudioStream, bus: String = "Master", volume_db: float = 0.0) -> void:
	if not stream: return
	var player = AudioStreamPlayer.new()
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(player)
	player.stream = stream
	player.bus = bus
	player.volume_db = volume_db
	player.play()
	player.finished.connect(player.queue_free)

func _play_sound_2d(stream: AudioStream, pos: Vector2, bus: String = "Master", volume_db: float = 0.0) -> void:
	if not stream: return
	var player = AudioStreamPlayer2D.new()
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(player)
	player.global_position = pos
	player.stream = stream
	player.bus = bus
	player.volume_db = volume_db
	player.max_distance = 1000.0
	player.attenuation = 2.0
	player.play()
	player.finished.connect(player.queue_free)

extends CanvasLayer
class_name ATMUI

@onready var panel: Control = $Control
@onready var dirty_money_label: Label = %DirtyMoneyLabel
@onready var clean_money_label: Label = %CleanMoneyLabel
@onready var daily_progress_label: Label = %DailyProgressLabel
@onready var remaining_limit_label: Label = %RemainingLimitLabel
@onready var amount_spinbox: SpinBox = %AmountSpinBox
@onready var deposit_button: Button = %DepositButton
@onready var withdraw_button: Button = %WithdrawButton
@onready var close_button: Button = %CloseButton
@onready var feedback_label: Label = %FeedbackLabel

var _player: Player

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	deposit_button.pressed.connect(_on_deposit_pressed)
	withdraw_button.pressed.connect(_on_withdraw_pressed)
	close_button.pressed.connect(close)
	if NetworkManager and not NetworkManager.atm_state_changed.is_connected(_on_atm_state_changed):
		NetworkManager.atm_state_changed.connect(_on_atm_state_changed)
	if NetworkManager and NetworkManager.economy:
		if not NetworkManager.economy.dirty_money_changed.is_connected(_on_money_changed):
			NetworkManager.economy.dirty_money_changed.connect(_on_money_changed)
		if not NetworkManager.economy.clean_money_changed.is_connected(_on_money_changed):
			NetworkManager.economy.clean_money_changed.connect(_on_money_changed)

func open(player: Player) -> void:
	_player = player
	feedback_label.text = ""
	layer = 120
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	show()
	_refresh_ui()
	AudioManager.play_ui_menu()

func close() -> void:
	hide()
	if _player:
		_player._is_interacting = false

func _on_deposit_pressed() -> void:
	var moved: int = NetworkManager.deposit_dirty_to_clean(int(amount_spinbox.value))
	if moved > 0:
		feedback_label.text = "Deposited $%d dirty into clean." % moved
		AudioManager.play_transaction()
	else:
		feedback_label.text = "Deposit blocked by cash or today's ATM limit."
	_refresh_ui()

func _on_withdraw_pressed() -> void:
	var moved: int = NetworkManager.withdraw_clean_to_dirty(int(amount_spinbox.value))
	if moved > 0:
		feedback_label.text = "Withdrew $%d clean into dirty cash." % moved
		AudioManager.play_transaction()
	else:
		feedback_label.text = "Not enough clean money to withdraw."
	_refresh_ui()

func _on_atm_state_changed(_daily_deposited: int, _remaining_limit: int, _date_key: String) -> void:
	_refresh_ui()

func _on_money_changed(_amount: int) -> void:
	_refresh_ui()

func _refresh_ui() -> void:
	if not is_node_ready():
		return
	dirty_money_label.text = "Dirty: $%d" % NetworkManager.economy.dirty_money
	clean_money_label.text = "Clean: $%d" % NetworkManager.economy.clean_money
	daily_progress_label.text = "Deposited Today: $%d / $%d" % [NetworkManager.get_atm_daily_deposited(), NetworkManager.get_atm_daily_limit()]
	remaining_limit_label.text = "Remaining ATM Limit: $%d" % NetworkManager.get_atm_remaining_deposit_limit()
	deposit_button.disabled = NetworkManager.economy.dirty_money <= 0 or NetworkManager.get_atm_remaining_deposit_limit() <= 0
	withdraw_button.disabled = NetworkManager.economy.clean_money <= 0


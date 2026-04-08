extends Resource
class_name OwnedFrontBusinessState

signal purchased_changed(purchased: bool)
signal stock_changed(stock_key: StringName, new_amount: int)
signal earnings_changed(total_clean_earnings: int)

@export var business_data: FrontBusinessResource
@export var is_purchased: bool = false
@export var total_clean_earnings: int = 0

var stock_by_item: Dictionary = {}

func initialize(data: FrontBusinessResource) -> void:
	business_data = data
	is_purchased = false
	total_clean_earnings = 0
	stock_by_item.clear()

func set_purchased(value: bool) -> void:
	if is_purchased == value:
		return
	is_purchased = value
	purchased_changed.emit(is_purchased)

func get_stock_amount(stock_key: StringName) -> int:
	return int(stock_by_item.get(stock_key, 0))

func add_stock(stock_key: StringName, amount: int) -> void:
	if stock_key == &"" or amount <= 0:
		return
	var new_amount: int = get_stock_amount(stock_key) + amount
	stock_by_item[stock_key] = new_amount
	stock_changed.emit(stock_key, new_amount)

func remove_stock(stock_key: StringName, amount: int) -> bool:
	if stock_key == &"" or amount <= 0:
		return false
	var current_amount: int = get_stock_amount(stock_key)
	if current_amount < amount:
		return false
	var new_amount: int = current_amount - amount
	if new_amount <= 0:
		stock_by_item.erase(stock_key)
		new_amount = 0
	else:
		stock_by_item[stock_key] = new_amount
	stock_changed.emit(stock_key, new_amount)
	return true

func record_clean_earnings(amount: int) -> void:
	if amount <= 0:
		return
	total_clean_earnings += amount
	earnings_changed.emit(total_clean_earnings)


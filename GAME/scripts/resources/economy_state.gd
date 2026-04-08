extends Resource
class_name EconomyState

## Emitted when dirty money changes. Passes new total.
signal dirty_money_changed(new_amount: int)
## Emitted when clean money changes. Passes new total.
signal clean_money_changed(new_amount: int)
## Emitted when debt changes. Passes new total.
signal debt_changed(new_amount: int)

@export var dirty_money: int = 0:
	set(v):
		dirty_money = max(v, 0)
		dirty_money_changed.emit(dirty_money)

@export var clean_money: int = 0:
	set(v):
		clean_money = max(v, 0)
		clean_money_changed.emit(clean_money)

@export var debt: int = 0:
	set(v):
		debt = max(v, 0)
		debt_changed.emit(debt)

## Add dirty money (from street sales, dealer collections, etc.)
func add_dirty(amount: int) -> void:
	if amount <= 0:
		return
	dirty_money += amount

## Spend dirty money. Returns true if successful, false if insufficient.
func spend_dirty(amount: int) -> bool:
	if amount <= 0:
		return true
	if dirty_money < amount:
		return false
	dirty_money -= amount
	return true

## Add clean money (from laundering fronts)
func add_clean(amount: int) -> void:
	if amount <= 0:
		return
	clean_money += amount

## Spend clean money. Returns true if successful, false if insufficient.
func spend_clean(amount: int) -> bool:
	if amount <= 0:
		return true
	if clean_money < amount:
		return false
	clean_money -= amount
	return true

## Add debt (from hospital bills, court fees, etc.)
func add_debt(amount: int) -> void:
	if amount <= 0:
		return
	debt += amount

## Pay down debt. Deducts from clean money first, then dirty. Returns amount actually paid.
func pay_debt(amount: int) -> int:
	if amount <= 0 or debt <= 0:
		return 0
	var to_pay: int = mini(amount, debt)
	# Try clean money first
	var from_clean: int = mini(to_pay, clean_money)
	if from_clean > 0:
		clean_money -= from_clean
	var remaining: int = to_pay - from_clean
	# Then dirty money
	var from_dirty: int = mini(remaining, dirty_money)
	if from_dirty > 0:
		dirty_money -= from_dirty
	var paid: int = from_clean + from_dirty
	debt -= paid
	return paid

## Convenience: total liquid cash (dirty + clean)
func get_total_cash() -> int:
	return dirty_money + clean_money

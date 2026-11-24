class_name ShopHours
extends Resource
## The shop's hours, in minutes since midnight, on half-hour steps: prep (staff can work,
## no customers), open (customers come in and order), last orders (no new orders; those
## already waiting are still served) and close. Always in that order.

enum Mark { PREP, OPEN, LAST_ORDER, CLOSE }

const STEP_MINUTES: int = 30
const DAY_MINUTES: int = 24 * 60
const MARK_NAMES: Array[String] = ["Prep", "Open", "Last orders", "Close"]

@export var prep_minute: int = 8 * 60
@export var open_minute: int = 10 * 60
@export var last_order_minute: int = 21 * 60
@export var close_minute: int = 22 * 60


func get_mark(mark: Mark) -> int:
	match mark:
		Mark.PREP:
			return prep_minute
		Mark.OPEN:
			return open_minute
		Mark.LAST_ORDER:
			return last_order_minute
	return close_minute


## Moves a mark to `minute`, snapped to a half hour and kept between its neighbors.
func set_mark(mark: Mark, minute: int) -> void:
	var low: int = 0 if mark == Mark.PREP else get_mark((mark - 1) as Mark)
	var high: int = DAY_MINUTES if mark == Mark.CLOSE else get_mark((mark + 1) as Mark)
	minute = clampi(snappedi(minute, STEP_MINUTES), low, high)
	if minute == get_mark(mark):
		return
	match mark:
		Mark.PREP:
			prep_minute = minute
		Mark.OPEN:
			open_minute = minute
		Mark.LAST_ORDER:
			last_order_minute = minute
		Mark.CLOSE:
			close_minute = minute
	emit_changed()


## True while customers can come in and order.
func is_taking_orders(minute_of_day: int) -> bool:
	return minute_of_day >= open_minute and minute_of_day < last_order_minute

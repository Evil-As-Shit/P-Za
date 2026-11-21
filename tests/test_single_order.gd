extends "res://tests/test_base.gd"
## One pizza on its own goes out in about the time a real shop takes (~10-15 shop minutes).

const MAX_MINUTES: int = 20

var _ticket: Ticket
var _start_minutes: int


func _start() -> void:
	stop_random_orders()
	clock.set_speed(6)
	_start_minutes = clock.get_open_minutes()
	_ticket = order_pizzas(1)
	rack.ticket_completed.connect(_on_completed)


func _on_completed(ticket: Ticket) -> void:
	if ticket != _ticket:
		return
	var minutes: int = clock.get_open_minutes() - _start_minutes
	if minutes > MAX_MINUTES:
		fail("one pizza took %d shop minutes (max %d)" % [minutes, MAX_MINUTES])
	else:
		pass_test("one pizza out in %d shop minutes" % minutes)

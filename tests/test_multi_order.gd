extends "res://tests/test_base.gd"
## Orders of several sizes all go out, each as one stack holding every box.

const SIZES: Array[int] = [1, 3, 8, 2]

var _remaining: Dictionary[Ticket, int] = {}
var _stack_sizes: Dictionary[Ticket, int] = {}


func _start() -> void:
	stop_random_orders()
	clock.set_speed(6)
	# Plenty of patience: this test is about stacking, not speed.
	rack.patience_minutes = 100000
	rack.patience_past_quote = 100000
	for size: int in SIZES:
		_remaining[order_pizzas(size)] = size
	rack.ticket_completed.connect(_on_completed)


func _step() -> void:
	keep_flat_boxes_stocked()
	for ticket: Ticket in _remaining:
		if ticket.ready and not _stack_sizes.has(ticket):
			_stack_sizes[ticket] = ticket.stack_base.item.get_units().size() + 1


func _on_completed(ticket: Ticket) -> void:
	var size: int = _remaining[ticket]
	var stacked: int = _stack_sizes.get(ticket, 0)
	if stacked != size:
		fail("order of %d went out as a stack of %d" % [size, stacked])
		return
	_remaining.erase(ticket)
	if _remaining.is_empty():
		pass_test("orders of %s all went out as full stacks" % [SIZES])

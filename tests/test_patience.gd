extends "res://tests/test_base.gd"
## An order that runs out of patience mid-way is cancelled, counted as missed, and
## everything made for it ends up in the garbage.

const PATIENCE: int = 8

var _ticket: Ticket
var _cancelled: bool = false


func _start() -> void:
	stop_random_orders()
	clock.set_speed(6)
	_ticket = order_pizzas(3)
	_ticket.patience = PATIENCE
	rack.ticket_cancelled.connect(_on_cancelled)
	rack.ticket_completed.connect(
		func(_t: Ticket) -> void: fail("the order went out instead of being cancelled")
	)


func _on_cancelled(ticket: Ticket) -> void:
	_cancelled = ticket == _ticket


func _step() -> void:
	if not _cancelled:
		return
	# Give the pawns time to clear the leftovers, then check nothing is left behind.
	if not work.get_shop_jobs().is_empty():
		return
	for child: Node in world.get_node("Entities").get_children():
		if child is Item:
			fail("a leftover item is still lying on the floor")
			return
	if finances.get_today().orders_missed != 1:
		fail("missed orders is %d, expected 1" % finances.get_today().orders_missed)
		return
	pass_test("cancelled after %d min, leftovers thrown out" % PATIENCE)

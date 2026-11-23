extends "res://tests/test_base.gd"
## An order that runs out of patience mid-way is cancelled, counted as missed, and
## everything made for it ends up in the garbage.

const PATIENCE: int = 8

var _ticket: Ticket
var _cancelled: bool = false


func _start() -> void:
	stop_random_orders()
	# Patience runs to the manager's quote plus a fixed grace (or a flat wait with no quote).
	if rack.get_patience(17) != 17 + rack.patience_past_quote:
		fail("a 17 min quote gave %d min patience, expected %d" % [rack.get_patience(17), 17 + rack.patience_past_quote])
		return
	if rack.get_patience(-1) != rack.patience_minutes:
		fail("an unquoted order doesn't use the flat patience")
		return
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

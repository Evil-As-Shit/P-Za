extends "res://tests/test_base.gd"
## Orders are taken at the register: a customer's order waits there until a Cashier pawn
## takes it, then its ticket prints, timed from when they ordered. With no register, the
## customer gives up after their patience and the sale is missed.

const SHORT_PATIENCE: int = 5

var _register: Station
var _placed_at: int = -1
var _taken_by: Pawn = null
var _printed: Ticket = null
var _second_placed: bool = false


func _start() -> void:
	stop_random_orders()
	clock.set_speed(6)
	_register = world.get_node("Entities/Register")
	if _register.data.get_facings() != [0, 1, 2, 3]:
		fail("the register can face %s, expected all four" % [_register.data.get_facings()])
		return
	_placed_at = rack.now_minutes
	world._on_order_placed([world.debug_recipe] as Array[Recipe])
	if rack.get_ticket_count() != 0:
		fail("the ticket printed before anyone took the order")
		return
	if work.get_waiting_orders().size() != 1:
		fail("the order isn't waiting at the register")
		return


func _step() -> void:
	if _printed == null:
		_watch_first_order()
	elif not _second_placed:
		_order_with_no_register()
	elif work.get_waiting_orders().is_empty():
		# The first order may have gone out meanwhile (the customer waits past their quote).
		for section: Ticket.Section in [Ticket.Section.WAIT, Ticket.Section.MAKE]:
			for ticket: Ticket in rack.get_tickets(section):
				if ticket != _printed:
					fail("an order printed with no register to take it")
					return
		if finances.get_today().orders_missed != 1:
			fail("missed orders is %d, expected 1" % finances.get_today().orders_missed)
			return
		pass_test("order taken at the register by %s; with no register the customer left" % _taken_by.display_name)


func _watch_first_order() -> void:
	var waiting: Array[Job] = work.get_waiting_orders()
	if not waiting.is_empty() and waiting[0].claimed_by != null:
		_taken_by = waiting[0].claimed_by
		if waiting[0].station != _register:
			fail("the order was taken somewhere other than the register")
			return
		if _taken_by.get_priority(load("res://resources/work_types/cashier.tres")) == 0:
			fail("%s took an order without Cashier work" % _taken_by.display_name)
			return
	var make: Array[Ticket] = rack.get_tickets(Ticket.Section.MAKE)
	if make.is_empty():
		return
	_printed = make[0]
	if _taken_by == null:
		fail("the ticket printed but nobody was seen taking the order")
		return
	if _printed.printed_at != _placed_at:
		fail("the ticket is timed from %d, but the customer ordered at %d" % [_printed.printed_at, _placed_at])
		return


## Sells the register, then a customer orders: nobody can take it, so they give up.
func _order_with_no_register() -> void:
	if not _register.is_idle():
		return
	var build: BuildMode = world.get_node("BuildMode")
	world._set_build_mode(true)
	if not build.pick_up(_register) or not build.sell():
		fail("couldn't sell the idle register")
		return
	world._set_build_mode(false)
	rack.patience_minutes = SHORT_PATIENCE
	rack.patience_past_quote = SHORT_PATIENCE
	world._on_order_placed([world.debug_recipe] as Array[Recipe])
	_second_placed = true

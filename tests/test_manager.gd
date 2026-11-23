extends "res://tests/test_base.gd"
## Manager: one pawn at a time, picked in the priority grid. They quote each order's wait
## from a queue-aware estimate, off by less with more Managing skill (none at 20), and each
## quote is practice. The quote shows on the ticket. With no manager no orders come in.

var _estimate_empty: float = 0.0
var _ticket: Ticket = null


func _start() -> void:
	stop_random_orders()
	var manager: Pawn = work.get_manager()
	if manager == null:
		fail("the shop starts with no manager")
		return
	var rules: QuoteRules = work.quote_rules
	for check: Array in [[0, 0.5], [10, 0.15], [20, 0.0]]:
		if not is_equal_approx(rules.max_error(check[0], manager.skill_rules), check[1]):
			fail("level %d can be off by %.2f, expected %.2f" % [check[0], rules.max_error(check[0], manager.skill_rules), check[1]])
			return

	# One manager at a time.
	var other: Pawn = work.get_pawns()[1]
	world._on_manager_change_requested(other, true)
	if work.get_manager() != other or manager.is_manager:
		fail("picking a new manager didn't replace the old one")
		return
	world._on_manager_change_requested(manager, true)

	# A perfect manager quotes the estimate; more work queued means a longer quote.
	manager.set_skill(work.managing, 20)
	var recipes: Array[Recipe] = [world.debug_recipe]
	_estimate_empty = _estimate(recipes)
	var quote: int = work.quote_order(recipes)
	if quote != roundi(_estimate_empty):
		fail("a level 20 manager quoted %d for an estimate of %.1f" % [quote, _estimate_empty])
		return
	manager.set_skill(work.managing, 5)
	work.quote_order(recipes)
	if not is_equal_approx(manager.get_practice(work.managing), rules.practice_per_quote):
		fail("quoting gave %.1f min of practice, expected %.1f" % [manager.get_practice(work.managing), rules.practice_per_quote])
		return
	manager.set_skill(work.managing, 20)

	# Place an order through the register: its ticket carries the quote.
	clock.set_speed(6)
	rack.ticket_completed.connect(_on_completed)
	world._on_order_placed(recipes)


func _step() -> void:
	if _ticket == null:
		var make: Array[Ticket] = rack.get_tickets(Ticket.Section.MAKE)
		if not make.is_empty():
			_ticket = make[0]
			if _ticket.quoted_minutes != roundi(_estimate_empty):
				fail("the ticket's quote is %d, expected %d" % [_ticket.quoted_minutes, roundi(_estimate_empty)])


func _on_completed(ticket: Ticket) -> void:
	if ticket != _ticket:
		return
	var took: int = ticket.get_age(rack.now_minutes)
	var miss: int = ticket.get_quote_miss(rack.now_minutes)

	# Once pawns have walked for orders, quotes count walking too.
	var walk: float = work.get_average_walk_minutes()
	var recipes: Array[Recipe] = [world.debug_recipe]
	var with_walking: float = _estimate(recipes)
	if walk <= 0.0 or with_walking <= _estimate_empty:
		fail("after an order the average walk is %.2f min and the estimate %.1f (was %.1f)" % [walk, with_walking, _estimate_empty])
		return

	# A busier rack gives a longer estimate.
	for i: int in 3:
		order_pizzas(2)
	var busy: float = _estimate(recipes)
	if busy <= _estimate_empty:
		fail("with 6 pizzas queued the estimate is %.1f, not more than %.1f empty" % [busy, _estimate_empty])
		return

	# No manager: closed to orders.
	world._on_manager_change_requested(work.get_manager(), false)
	var orders: OrderSource = world.get_node("OrderSource")
	if orders.open or work.quote_order(recipes) != -1:
		fail("with no manager the shop still takes or quotes orders")
		return
	if not (world.get_node("Hud/TicketRackPanel").get_node("%ManagerLabel") as Label).visible:
		fail("no warning shows with no manager")
		return
	pass_test("quoted %d min without walking data (took %d, %+d); with %.2f min walk per job %.1f, %.1f with 6 pizzas queued; closed without a manager" % [ticket.quoted_minutes, took, miss, walk, with_walking, busy])


func _estimate(recipes: Array[Recipe]) -> float:
	var estimate := WaitEstimate.new(
		work.get_pawns(), work.take_order_task, rack.stack_task, rack.hand_off_task,
		work.get_average_walk_minutes()
	)
	var tickets: Array[Ticket] = rack.get_tickets(Ticket.Section.WAIT)
	tickets.append_array(rack.get_tickets(Ticket.Section.MAKE))
	return estimate.estimate(recipes, tickets, work.get_waiting_orders())

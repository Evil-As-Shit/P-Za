extends "res://tests/test_base.gd"
## An order's wait ends when it's handed off (ready), not when it's collected: the ticket
## stamps the minute it became ready, and its age, quote miss and review stop counting then.

const PICKUP_WAIT: float = 4.0

var _ticket: Ticket


func _start() -> void:
	stop_random_orders()
	# Judged on a made-up ticket: quoted 10 min, ready at 10, collected at 30.
	var ticket := Ticket.new(0, [world.debug_recipe] as Array[Recipe], rack.stack_task, rack.hand_off_task)
	ticket.printed_at = 0
	ticket.quoted_minutes = 10
	ticket.patience = 30
	ticket.ready = true
	ticket.ready_at = 10
	if ticket.get_age(30) != 10 or ticket.get_quote_miss(30) != 0:
		fail("ready at 10, collected at 30: age %d, quote miss %d (expected 10, 0)" % [ticket.get_age(30), ticket.get_quote_miss(30)])
		return
	var rules: ReviewRules = (world.get_node("ShopReputation") as ShopReputation).rules
	if rules != null:
		var review: Review = rules.judge_order(ticket, 30)
		if review.complaints.has(rules.late_text):
			fail("an order ready on time was judged late because of its pickup")
			return
	ticket.release()

	# A real order: with nobody to collect it, it goes out a while after it's ready.
	world.pickup_wait_minutes = PICKUP_WAIT
	clock.set_speed(6)
	_ticket = order_pizzas(1)
	rack.ticket_completed.connect(_on_completed)


func _on_completed(ticket: Ticket) -> void:
	if ticket != _ticket:
		return
	if ticket.ready_at < 0:
		fail("the ticket went out without a ready time")
		return
	var now: int = rack.now_minutes
	if now - ticket.ready_at < 2:
		fail("it went out at %d, only %d min after it was ready at %d" % [now, now - ticket.ready_at, ticket.ready_at])
		return
	if ticket.get_age(now) != ticket.ready_at - ticket.printed_at:
		fail("its age is %d min, expected %d (ordering to ready)" % [ticket.get_age(now), ticket.ready_at - ticket.printed_at])
		return
	pass_test("ready after %d min, went out %d min later; age stays %d" % [ticket.ready_at - ticket.printed_at, now - ticket.ready_at, ticket.get_age(now)])

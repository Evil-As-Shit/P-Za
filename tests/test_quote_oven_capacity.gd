extends "res://tests/test_base.gd"
## The wait estimate: with many pizzas queued the ovens are the bottleneck, so queued bake
## time is spread over the oven spots (fewer spots, longer quote). Orders still in line at
## the register only need the pawns on Cashier: fewer cashiers, longer quote.

const CASHIER := preload("res://resources/work_types/cashier.tres")


func _start() -> void:
	stop_random_orders()
	var recipes: Array[Recipe] = [world.debug_recipe]
	var bake: TaskType = null
	for step: TaskType in world.debug_recipe.steps:
		if step.unattended:
			bake = step
	if bake == null:
		fail("the debug recipe has no unattended step")
		return
	var ovens: Array[Station] = []
	var spots: int = 0
	for station: Station in work.get_stations():
		if station.can_do(bake):
			ovens.append(station)
			spots += station.get_spot_count()
	if spots == 0:
		fail("no station can %s" % bake.display_name)
		return

	# Queue tickets in Wait, so nothing is worked on while we estimate.
	var pizzas: int = 0
	for i: int in 8:
		rack.print_ticket([world.debug_recipe, world.debug_recipe, world.debug_recipe] as Array[Recipe])
		pizzas += 3
	var tickets: Array[Ticket] = rack.get_tickets(Ticket.Section.WAIT)
	var none: Array[Job] = []
	var stations: Array[Station] = work.get_stations()
	var minutes: float = _estimate(stations).estimate(recipes, tickets, none)
	var oven_queue: float = pizzas * bake.work_minutes / spots
	if minutes < oven_queue:
		fail("with %d pizzas queued for %d oven spots the estimate is %.1f min, less than the %.1f min of baking ahead" % [pizzas, spots, minutes, oven_queue])
		return
	# Twice the ovens: the bottleneck halves, so the quote drops.
	var doubled: Array[Station] = stations.duplicate()
	doubled.append_array(ovens)
	var with_more: float = _estimate(doubled).estimate(recipes, tickets, none)
	if with_more >= minutes:
		fail("twice the oven spots didn't shorten the estimate (%.1f vs %.1f)" % [with_more, minutes])
		return

	# Orders waiting at the register: only Cashier pawns take them. Waiting orders with no
	# recipes add only the order-taking (and a hand-off), not station work.
	var empty: Array[Ticket] = []
	var waiting: Array[Job] = []
	for i: int in 6:
		var job := Job.new(work.take_order_task, null, null)
		waiting.append(job)
	var pawns: Array[Pawn] = work.get_pawns()
	if pawns.size() < 2:
		fail("the shop needs at least two pawns for this test")
		return
	for pawn: Pawn in pawns:
		pawn.set_priority(CASHIER, 1)
	var all_cashiers: float = _estimate(doubled).estimate(recipes, empty, waiting)
	for pawn: Pawn in pawns:
		pawn.set_priority(CASHIER, 1 if pawn == pawns[0] else 0)
	var one_cashier: float = _estimate(doubled).estimate(recipes, empty, waiting)
	if one_cashier <= all_cashiers:
		fail("with one cashier the line ahead didn't take longer (%.1f vs %.1f with all)" % [one_cashier, all_cashiers])
		return
	pass_test("%d pizzas ahead: %.1f min (%.1f with twice the ovens); 6 in line: %.1f min with one cashier, %.1f with all" % [pizzas, minutes, with_more, one_cashier, all_cashiers])


func _estimate(stations: Array[Station]) -> WaitEstimate:
	return WaitEstimate.new(
		work.get_pawns(), work.take_order_task, rack.stack_task, rack.hand_off_task, 0.0, stations
	)

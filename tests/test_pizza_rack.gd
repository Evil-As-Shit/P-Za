extends "res://tests/test_base.gd"
## The pizza rack: while every oven spot is taken, made pizzas are parked on the rack
## (bottom slot first, each on its screen, higher ones drawn over lower ones), then loaded
## from it once a spot frees up, and the order still goes out.

const PIZZA_RACK := preload("res://resources/stations/pizza_rack.tres")
const LOAD_OVEN := preload("res://resources/tasks/load_oven.tres")

var _rack_station: Station
var _ticket: Ticket
var _parked_max: int = 0
var _saw_loaded_from_rack: bool = false
## Parking jobs under way, already checked.
var _parking: Array[Job] = []


func _start() -> void:
	stop_random_orders()
	# One oven (two spots), so five pizzas overflow onto the starting shop's rack.
	var build: BuildMode = world.get_node("BuildMode")
	world._set_build_mode(true)
	if not build.pick_up(world.get_node("Entities/PizzaOven2")) or not build.sell():
		fail("couldn't sell the second pizza oven")
		return
	world._set_build_mode(false)
	_rack_station = world.get_node("Entities/PizzaRack")
	if _rack_station.data != PIZZA_RACK or _rack_station.get_spot_count() != 17:
		fail("the pizza rack wasn't set up with 17 slots")
		return

	clock.set_speed(6)
	rack.patience_minutes = 100000
	rack.patience_past_quote = 100000
	_ticket = order_pizzas(5)
	rack.ticket_completed.connect(_on_completed)


func _step() -> void:
	if _rack_station == null:
		return
	var parked: Array[Item] = []
	for spot: int in _rack_station.get_spot_count():
		var item: Item = _rack_station.get_item(spot)
		if item == null:
			continue
		parked.append(item)
		if item._under.texture == null:
			fail("a parked pizza had no screen under it")
			return
	if parked.size() < _parked_max:
		_saw_loaded_from_rack = true
	# A pawn only sets out to park a pizza while the ovens are full.
	for pawn: Pawn in work.get_pawns():
		var job: Job = pawn.get_job()
		if job != null and job.task_type == LOAD_OVEN and job.part == RackWhenFullBehavior.PARKING \
				and not _parking.has(job):
			_parking.append(job)
			if not _ovens_full():
				fail("a pawn set out to park a pizza with an oven spot free")
				return
	_parking.assign(_parking.filter(func(job: Job) -> bool: return job.claimed_by != null))
	_parked_max = maxi(_parked_max, parked.size())
	# Higher slots draw over lower ones.
	for i: int in parked.size() - 1:
		if parked[i].get_index() > parked[i + 1].get_index():
			fail("a pizza on a lower slot drew over a higher one")
			return


## True if every oven spot holds a pizza or is claimed by a pawn bringing one.
func _ovens_full() -> bool:
	for station: Station in work.get_stations():
		if not station.can_do(LOAD_OVEN):
			continue
		for spot: int in station.get_spot_count():
			if station.get_item(spot) == null and not station.is_reserved(spot):
				return false
	return true


func _on_completed(ticket: Ticket) -> void:
	if ticket != _ticket:
		return
	if _parked_max == 0:
		fail("no pizza was ever parked on the rack while the ovens were full")
		return
	if not _saw_loaded_from_rack:
		fail("no pizza was ever loaded from the rack")
		return
	for spot: int in _rack_station.get_spot_count():
		if _rack_station.get_item(spot) != null:
			fail("a pizza was left on the rack after the order went out")
			return
	pass_test("up to %d pizzas waited on the rack while the ovens were full" % _parked_max)

extends "res://tests/test_base.gd"
## Dish sink:
## 1. Three dirty dough containers on the dirty drainboard are washed as one batch by one
##    pawn: taken together, then worked at the wash, rinse and sanitize basins in turn, then
##    set down on the clean drainboard and put away in Dough storage, which counts them full.
## 2. A container emptied while making a pizza goes to the sink's dirty board (not Empty
##    Dough storage), and comes back to Dough storage clean.

const DISH := preload("res://resources/items/dough_container_dish.tres")

var _sink: Station
var _boards: DishBoards
var _dough: Station
var _empties: Station
var _full_stock: int = 0
var _phase: int = 0
## Each wash job seen, with the spots it worked at in order.
var _wash_spots: Dictionary[Job, Array] = {}
var _batch_sizes: Dictionary[Job, int] = {}
var _ticket_done: bool = false


func _start() -> void:
	stop_random_orders()
	clock.set_speed(6)
	rack.patience_minutes = 100000
	rack.patience_past_quote = 100000
	_sink = world.get_node("Entities/DishSink")
	_boards = _sink.get_dish_boards()
	_dough = world.get_node("Entities/DoughRack")
	_empties = world.get_node("Entities/EmptyDoughTable")
	_full_stock = _dough.get_stock()
	# Three containers were used up: they're dirty at the sink, with room for them in storage.
	_dough._stock -= 3
	for i: int in 3:
		_boards.claim_dirty_room()
		_boards.add_dirty(DISH)
	rack.ticket_completed.connect(func(_t: Ticket) -> void: _ticket_done = true)
	work.assign_all()


func _step() -> void:
	_watch_washing()
	if _empties.get_stock() > 0:
		fail("an empty container went to Empty Dough storage while the sink had room")
		return
	match _phase:
		0:
			if _wash_spots.size() > 1:
				fail("the batch was split over %d wash jobs" % _wash_spots.size())
			elif _all_back():
				var job: Job = _wash_spots.keys()[0]
				var spots: Array = _wash_spots[job]
				if _batch_sizes[job] != 3:
					fail("batch held %d dishes, not 3" % _batch_sizes[job])
				elif spots != [0, 1, 2, 3, 4]:
					fail("batch went through spots %s, not dirty board, 3 basins, clean board" % [spots])
				else:
					_wash_spots.clear()
					_batch_sizes.clear()
					# One ball left in the next container, so one pizza empties it.
					_dough._partial.append(1)
					order_pizzas(1)
					_phase = 1
		1:
			if _ticket_done and _all_back() and not _wash_spots.is_empty():
				pass_test("batch of 3 washed through every basin; a used-up container came back clean")


## Records the spot each wash job is at, part by part.
func _watch_washing() -> void:
	for pawn: Pawn in work.get_pawns():
		var job: Job = pawn.get_job()
		if job == null or job.task_type.id != &"wash_dishes" or job.spot < 0:
			continue
		var spots: Array = _wash_spots.get_or_add(job, [])
		if spots.is_empty() or spots.back() != job.spot:
			spots.append(job.spot)
		_batch_sizes[job] = maxi(_batch_sizes.get(job, 0), job.dishes.size())


## Nothing left at the sink and Dough storage is full again.
func _all_back() -> bool:
	return (
		_boards.get_dirty_count() == 0 and _boards.get_clean_count() == 0
		and _dough.get_stock() == _full_stock and not _container_out()
	)


func _container_out() -> bool:
	for station: Station in work.get_stations():
		for spot: int in station.get_spot_count():
			var item: Item = station.get_item(spot)
			if item != null and item.ingredient != null:
				return true
	for item: Item in work.get_floor_items():
		if item.ingredient != null:
			return true
	return false

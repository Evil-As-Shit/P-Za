extends "res://tests/test_base.gd"
## Once no pizzas are being made, the dough bucket left out on the prep table goes back to
## dough storage with what's left in it, and the next pizza takes that one out again:
## one pizza leaves a bucket of 5 put away, a second one takes it and leaves 4. It's never
## put away while a pizza is waiting to be stretched.

var _rack: Station
var _start_stock: int = 0
var _phase: int = 0
var _seen_jobs: Dictionary[Job, bool] = {}


func _start() -> void:
	stop_random_orders()
	clock.set_speed(6)
	rack.patience_minutes = 100000
	rack.patience_past_quote = 100000
	_rack = dough_storage()
	_start_stock = _rack.get_stock()
	order_pizzas(1)


func _step() -> void:
	for pawn: Pawn in work.get_pawns():
		var job: Job = pawn.get_job()
		if job == null or job.task_type.id != &"put_away_dough" or _seen_jobs.has(job):
			continue
		_seen_jobs[job] = true
		if _stretch_waiting():
			fail("the dough was put away while a pizza was waiting to be stretched")
			return
	match _phase:
		0:
			if _bucket_put_away([5]):
				order_pizzas(1)
				_phase = 1
		1:
			if _bucket_put_away([4]):
				pass_test("bucket put away with 5, taken out again, put away with 4 (%d put-aways)" % _seen_jobs.size())


## True once no bucket is out, the rack is back to its starting count, and the partly used
## buckets in it hold `expected`.
func _bucket_put_away(expected: Array[int]) -> bool:
	for station: Station in work.get_stations():
		for spot: int in station.get_spot_count():
			var item: Item = station.get_item(spot)
			if item != null and item.ingredient != null:
				return false
	for item: Item in work.get_floor_items():
		if item.ingredient != null:
			return false
	return _rack.get_stock() == _start_stock and _rack.get_partial_stock() == expected


func _stretch_waiting() -> bool:
	for ticket: Ticket in rack.get_tickets(Ticket.Section.MAKE):
		for order_item: OrderItem in ticket.order_items:
			if order_item.current_job != null and order_item.current_job.task_type.id == &"stretch":
				return true
	return false

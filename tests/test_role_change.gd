extends "res://tests/test_base.gd"
## Changing a station's role while a pawn is on the way to fetch from it: the pawn stops
## (the job keeps its progress and is offered again) and nothing stays promised to them,
## so the station's counts stay right. Given its role back, the order still goes out.

const DOUGH_STORAGE := preload("res://resources/station_roles/dough_storage.tres")

var _dough_rack: Station
var _ticket: Ticket
var _changed: bool = false


func _start() -> void:
	stop_random_orders()
	clock.set_speed(6)
	rack.patience_minutes = 100000
	rack.patience_past_quote = 100000
	_dough_rack = dough_storage()
	_ticket = order_pizzas(1)
	rack.ticket_completed.connect(_on_completed)


func _step() -> void:
	if _changed or not _fetching_dough():
		return
	_changed = true
	world._on_role_change_requested(_dough_rack, null)
	if _fetching_dough():
		fail("a pawn still heads to the dough rack after its role changed")
		return
	if _dough_rack._stock_claimed != 0 or _dough_rack._room_claimed != 0:
		fail("the re-roled rack still has %d stock and %d room promised" % [
			_dough_rack._stock_claimed, _dough_rack._room_claimed])
		return
	world._on_role_change_requested(_dough_rack, DOUGH_STORAGE)


## True if a pawn's job has a stop to take supply from the dough rack.
func _fetching_dough() -> bool:
	for pawn: Pawn in work.get_pawns():
		var job: Job = pawn.get_job()
		if job == null:
			continue
		for stop: JobStop in job.stops:
			if stop.action == JobStop.Action.TAKE_SUPPLY and stop.station == _dough_rack:
				return true
	return false


func _on_completed(ticket: Ticket) -> void:
	if ticket != _ticket:
		return
	if not _changed:
		fail("never saw a pawn fetching dough")
		return
	if _dough_rack._stock_claimed != 0:
		fail("the dough rack has %d stock promised after the order" % _dough_rack._stock_claimed)
		return
	pass_test("re-roled the dough rack mid-fetch; nothing left promised and the order went out")

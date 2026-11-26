extends "res://tests/test_base.gd"
## Changing a station's role while a pawn is on the way to fetch from it: the pawn stops
## (the job keeps its progress and is offered again) and nothing stays promised to them, so
## the station's counts stay right. Here a pawn heads to the Empty Dishes table for a dish
## to take to the sink. Racks and pallets are always storage, so their role can't change.

const STORAGE := preload("res://resources/station_roles/storage.tres")
const EMPTY := preload("res://resources/storage_kinds/empty_dishes.tres")
const DISH := preload("res://resources/items/dough_container_dish.tres")

var _table: Station
var _changed_at: int = -1


func _start() -> void:
	stop_random_orders()
	clock.set_speed(6)
	var rack_station: Station = world.get_node("Entities/BoxRack")
	world._on_role_change_requested(rack_station, null)
	if rack_station.role != STORAGE:
		fail("a rack's role changed")
		return
	_table = world.get_node("Entities/EmptyDishesTable")
	for i: int in 2:
		_table.claim_room(EMPTY, DISH)
		_table.add_stock(EMPTY, -1, DISH)
	work.assign_all()


func _step() -> void:
	if _changed_at >= 0:
		# A while later: given its role back, nothing's promised and nobody heads there.
		if frame - _changed_at < 60:
			return
		if stock_claimed(_table) != 0 or room_claimed(_table) != 0 or _fetching():
			fail("the re-roled table has stock or room promised again")
			return
		pass_test("re-roled the Empty Dishes table mid-fetch; nothing left promised")
		return
	if not _fetching():
		return
	world._on_role_change_requested(_table, null)
	if _fetching():
		fail("a pawn still heads to the table after its role changed")
		return
	if stock_claimed(_table) != 0 or room_claimed(_table) != 0:
		fail("the re-roled table still has %d stock and %d room promised" % [
			stock_claimed(_table), room_claimed(_table)])
		return
	world._on_role_change_requested(_table, STORAGE)
	_changed_at = frame


## True if a pawn's job has a stop to take supply from the table.
func _fetching() -> bool:
	for pawn: Pawn in work.get_pawns():
		var job: Job = pawn.get_job()
		if job == null:
			continue
		for stop: JobStop in job.stops:
			if stop.action == JobStop.Action.TAKE_SUPPLY and stop.station == _table:
				return true
	return false

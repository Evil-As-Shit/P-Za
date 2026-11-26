extends "res://tests/test_base.gd"
## Clean dishes and bulk sauce: a washed sauce bucket goes from the sink to the Clean Dishes
## rack. With no bulk sauce bucket it waits there (the cooler stays a bucket short). Once
## the bulk bucket is back, a pawn takes it from the rack, fills it at the bulk bucket and
## puts it in the prep table's cooler, which is full again.

const SAUCE_BUCKET := preload("res://resources/items/sauce_bucket.tres")
const SAUCE := preload("res://resources/storage_kinds/sauce.tres")
## Frames the bucket must wait on the rack while there's no bulk sauce.
const WAIT_FRAMES: int = 300

var _sink: Station
var _bulk: Station
var _clean_rack: Station
var _cooler: Station
var _build: BuildMode
var _full_stock: int = 0
var _phase: int = 0
var _waiting_since: int = -1
var _filled_at_bulk: bool = false


func _start() -> void:
	stop_random_orders()
	clock.set_speed(6)
	_sink = world.get_node("Entities/DishSink")
	_bulk = world.get_node("Entities/BulkSauce")
	_clean_rack = world.get_node("Entities/CleanDishesRack")
	_build = world.get_node("BuildMode")
	for station: Station in work.get_stations():
		if station.holds(SAUCE):
			_cooler = station
	_full_stock = _cooler.get_stock()
	# A bucket was used up: it's dirty at the sink, with room for it in the cooler.
	take_units(_cooler, SAUCE, 1)
	var boards: DishBoards = _sink.get_dish_boards()
	boards.claim_dirty_room()
	boards.add_dirty(SAUCE_BUCKET.dish)
	# No bulk sauce for now: the bulk bucket is picked up.
	world._set_build_mode(true)
	_build.pick_up(_bulk)
	work.assign_all()


func _step() -> void:
	for pawn: Pawn in work.get_pawns():
		var job: Job = pawn.get_job()
		if job != null and job.task_type.id == &"put_away_dishes" and job.station == _bulk \
				and job.part == PutAwayDishBehavior.Part.FILL and pawn.is_working():
			_filled_at_bulk = true
	match _phase:
		0:
			if not _clean_rack.get_stock_dishes(preload("res://resources/storage_kinds/clean_dishes.tres")).has(SAUCE_BUCKET.dish):
				return
			if _waiting_since < 0:
				_waiting_since = frame
			if _cooler.get_stock() != _full_stock - 1:
				fail("the cooler was refilled with no bulk sauce")
			elif frame - _waiting_since >= WAIT_FRAMES:
				# Bulk sauce is back.
				_build.cancel()
				world._set_build_mode(false)
				_phase = 1
		1:
			if _cooler.get_stock() == _full_stock and _clean_rack.get_stock() == 0:
				if not _filled_at_bulk:
					fail("the bucket reached the cooler without being filled at the bulk bucket")
				else:
					pass_test("bucket waited on the Clean Dishes rack, then was filled and put in the cooler")

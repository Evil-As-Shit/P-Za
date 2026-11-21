extends "res://tests/test_base.gd"
## Empty dough buckets never stay on the prep table:
## 1. A bucket put away with one ball left is carried straight to storage for empties when
##    that ball is taken, instead of being set out and left there empty.
## 2. An empty bucket left out anyway (here: put there by the test) is cleared off to
##    storage for empties by the Put away dough job.

const DOUGH := preload("res://resources/items/dough_container.tres")
var _rack: Station
var _prep: Station
var _phase: int = 0
var _planted: Item
var _ticket_done: bool = false


func _start() -> void:
	stop_random_orders()
	clock.set_speed(6)
	rack.patience_minutes = 100000
	_rack = world.get_node("Entities/DoughRack")
	_prep = world.get_node("Entities/PrepTable")
	# A bucket with one ball left was put away earlier: it's the next one taken out.
	_rack._partial.append(1)
	rack.ticket_completed.connect(func(_t: Ticket) -> void: _ticket_done = true)
	order_pizzas(1)


func _step() -> void:
	match _phase:
		0:
			if _empty_on_station():
				fail("the one-ball bucket was set out and left there empty")
			elif _ticket_done:
				if _rack.get_partial_stock().size() != 0:
					fail("the one-ball bucket wasn't the one used")
					return
				_planted = IngredientBehavior.spawn_container(DOUGH, work, 0)
				_planted.set_lid(null)
				_prep.put_item(2, _planted)
				_phase = 1
		1:
			# Stored: the bucket item is gone.
			if not is_instance_valid(_planted) or _planted.is_queued_for_deletion():
				pass_test("one-ball bucket carried off; a left-out empty one cleared off too")
			elif frame > 60 * 120:
				fail("the empty bucket left on the prep table was never cleared off")


## True if an empty bucket is sitting on a station.
func _empty_on_station() -> bool:
	for station: Station in work.get_stations():
		for spot: int in station.get_spot_count():
			var item: Item = station.get_item(spot)
			if item != null and item.ingredient != null and item.get_units().is_empty():
				return true
	return false

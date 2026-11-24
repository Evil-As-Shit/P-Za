extends "res://tests/test_base.gd"
## Deliveries: day 1 is a Monday and deliveries come Monday, Wednesday and Friday. Targets
## start at what the starting shop's storage holds, which opens full, so nothing is short.
## With stock used up, Wednesday's delivery brings whole cases up to each target, paid on
## arrival, onto the delivery pallet; Tuesday brings nothing. Hauling pawns put each case
## away once there's room for all of it: bags onto the Cheese rack, flat boxes onto the box
## pallet, sauce and dough poured into their bulk tubs. A sauce case with no room waits on
## the pallet until some is used. A clean dough container waits while the bulk dough tub is
## empty, then is filled there (using up the tub) and put away.

const SUPPLIES := preload("res://resources/supplies/supply_catalog.tres")
const CHEESE := preload("res://resources/supplies/cheese.tres")
const BOXES := preload("res://resources/supplies/flat_boxes.tres")
const SAUCE := preload("res://resources/supplies/sauce.tres")
const DOUGH := preload("res://resources/supplies/dough.tres")
const DOUGH_DISH := preload("res://resources/items/dough_container_dish.tres")
## Frames the dough container must wait on the rack while the bulk dough tub is empty.
const WAIT_FRAMES: int = 200

var _deliveries: Deliveries
var _cheese_rack: Station
var _box_pallet: Station
var _bulk_sauce: Station
var _bulk_dough: Station
var _dock: Station
var _clean_rack: Station
var _dough_rack: Station
var _phase: int = 0
var _since: int = 0
## Cases of each supply Wednesday's delivery brought.
var _ordered: Dictionary[SupplyItem, int] = {}
## Sauce the bulk bucket should hold once the last case is poured.
var _sauce_after: int = 0


func _start() -> void:
	stop_random_orders()
	_deliveries = world.get_node("Deliveries")
	_cheese_rack = world.get_node("Entities/CheeseRack")
	_box_pallet = world.get_node("Entities/BoxPallet")
	_bulk_sauce = world.get_node("Entities/BulkSauce")
	_bulk_dough = world.get_node("Entities/BulkDough")
	_dock = world.get_node("Entities/DeliveryPallet")
	_clean_rack = world.get_node("Entities/CleanDishesRack")
	_dough_rack = world.get_node("Entities/DoughRack")

	if ShopClock.get_weekday(1) != ShopClock.Weekday.MONDAY \
			or ShopClock.get_weekday_name(3) != "Wed" or ShopClock.get_weekday(8) != ShopClock.Weekday.MONDAY:
		fail("day 1 should be a Monday, day 3 a Wednesday and day 8 a Monday again")
		return
	if not _deliveries.is_delivery_day(5) or _deliveries.is_delivery_day(2) \
			or _deliveries.get_next_delivery_day(5) != 8:
		fail("deliveries should come Monday, Wednesday and Friday")
		return
	for supply: SupplyItem in SUPPLIES.items:
		var target: int = _deliveries.get_target(supply)
		if target <= 0 or target != _deliveries.get_stock(supply):
			fail("%s should start full at its target, has %d of %d" % [
				supply.display_name, _deliveries.get_stock(supply), target])
			return
	if _deliveries.deliver(1) != 0.0 or _dock.get_dock_cases().has_cases():
		fail("a full shop got a delivery")
		return

	# Stock gets used up: 6 cheese bags, a bundle of flat boxes, a case and a half of sauce and
	# all the dough.
	for i: int in 6:
		_take_unit(_cheese_rack)
	for i: int in BOXES.units_per_case:
		_take_unit(_box_pallet)
	_bulk_sauce._bulk_left -= SAUCE.units_per_case + SAUCE.units_per_case / 2
	_bulk_dough._bulk_left = 0
	# A washed dough container waits on the Clean Dishes rack, with room for it on the rack.
	_take_unit(_dough_rack)
	_clean_rack.claim_room()
	_clean_rack.add_stock(-1, DOUGH_DISH)

	if _deliveries.deliver(2) != 0.0:
		fail("a delivery came on a Tuesday")
		return
	# Whole cases up to each target: 2 cheese, 1 box bundle, 2 sauce, and enough dough to fill
	# the tub.
	for supply: SupplyItem in SUPPLIES.items:
		var short: int = _deliveries.get_target(supply) - _deliveries.get_stock(supply)
		_ordered[supply] = ceili(float(short) / supply.units_per_case)
	if _ordered[CHEESE] != 2 or _ordered[BOXES] != 1 or _ordered[SAUCE] != 2 or _ordered[DOUGH] < 1:
		fail("unexpected shortfall in cases: %s" % [_ordered])
		return
	var expected: float = 0.0
	for supply: SupplyItem in SUPPLIES.items:
		expected += _ordered[supply] * supply.get_case_price()
	var cash_before: float = finances.cash
	var cost: float = _deliveries.deliver(3)
	if not is_equal_approx(cost, expected) or not is_equal_approx(cash_before - finances.cash, expected) \
			or not is_equal_approx(finances.get_today().supplies, expected):
		fail("Wednesday's delivery cost %.2f (cash down %.2f), expected %.2f" % [
			cost, cash_before - finances.cash, expected])
		return
	for supply: SupplyItem in SUPPLIES.items:
		if _count_cases(supply) != _ordered[supply]:
			fail("the delivery pallets hold %d %s cases, expected %d" % [
				_count_cases(supply), supply.display_name, _ordered[supply]])
			return
	for supply: SupplyItem in SUPPLIES.items:
		if _deliveries.get_stock(supply) < _deliveries.get_target(supply):
			fail("%s is still short with its cases on the pallet" % supply.display_name)
			return
	clock.set_speed(6)


func _step() -> void:
	match _phase:
		0:
			# The dough container can't be filled until dough is poured into the tub.
			if _count_cases(DOUGH) == _ordered[DOUGH] and _bulk_dough.get_bulk_left() == 0 and _clean_rack.get_stock() != 1:
				fail("the dough container left the rack while the bulk dough tub was empty")
				return
			# Everything but one sauce case is put away; that one has no room yet.
			if _count_cases(SAUCE) != 1 or _count_cases(CHEESE) + _count_cases(BOXES) + _count_cases(DOUGH) > 0:
				return
			if _clean_rack.get_stock() != 0 or _dough_rack.get_stock() != _dough_rack.get_capacity():
				return
			# (Flat boxes start being folded as soon as they're on the box pallet.)
			if _cheese_rack.get_stock() != _cheese_rack.get_capacity():
				fail("the cheese cases weren't put away in full")
				return
			var dough_poured: int = _ordered[DOUGH] * DOUGH.units_per_case
			if _bulk_dough.get_bulk_left() != dough_poured - _dough_fill():
				fail("the bulk dough tub has %d, expected %d poured less one fill" % [
					_bulk_dough.get_bulk_left(), dough_poured])
				return
			var sauce_expected: int = _bulk_sauce.get_bulk_capacity() - SAUCE.units_per_case / 2
			if _bulk_sauce.get_bulk_left() != sauce_expected:
				fail("the bulk sauce bucket has %d, expected %d" % [_bulk_sauce.get_bulk_left(), sauce_expected])
				return
			_since = frame
			_phase = 1
		1:
			# The last sauce case waits on the pallet for room.
			if _count_cases(SAUCE) != 1:
				fail("a sauce case was put away with no room for it")
				return
			if frame - _since < WAIT_FRAMES:
				return
			# Some sauce is used: now there's room.
			while _bulk_sauce.get_bulk_room() < SAUCE.units_per_case:
				_bulk_sauce.use_fill()
			_sauce_after = _bulk_sauce.get_bulk_left() + SAUCE.units_per_case
			work.assign_all()
			_phase = 2
		2:
			for supply: SupplyItem in SUPPLIES.items:
				if _count_cases(supply) > 0:
					return
			if _bulk_sauce.get_bulk_left() != _sauce_after:
				fail("the bulk sauce bucket has %d after the last case, expected %d" % [
					_bulk_sauce.get_bulk_left(), _sauce_after])
				return
			pass_test("Wednesday's delivery was paid for and put away; a case waited for room")


## Cases of `supply` waiting on any delivery pallet.
func _count_cases(supply: SupplyItem) -> int:
	var count: int = 0
	for station: Station in work.get_stations():
		if station.get_dock_cases() != null:
			count += station.get_dock_cases().count(supply)
	return count


## Portions one dough container takes from the bulk dough tub.
func _dough_fill() -> int:
	return _bulk_dough.data.bulk_tub.per_fill


## Takes one stored unit out of `station`, as a pawn using it would.
func _take_unit(station: Station) -> void:
	station.claim_supply()
	station.take_supply()

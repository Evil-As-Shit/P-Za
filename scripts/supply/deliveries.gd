class_name Deliveries
extends Node
## Supply deliveries: on delivery days, at opening, each supply is topped up to the
## player's target in whole cases, set on the shop's delivery drop-offs (never more than
## fits there). The owner pays for what arrives.

## A delivery arrived costing `cost`.
signal delivered(cost: float)
## A supply's target changed.
signal targets_changed

@export var catalog: SupplyCatalog
## Weekdays a delivery comes, at opening (see ShopClock.Weekday).
@export var delivery_days: Array[ShopClock.Weekday] = [
	ShopClock.Weekday.MONDAY, ShopClock.Weekday.WEDNESDAY, ShopClock.Weekday.FRIDAY
]

var _work: WorkManager = null
## Units each supply is topped up to.
var _targets: Dictionary[SupplyItem, int] = {}


## Targets start at what the shop's storage for each supply holds.
func setup(work: WorkManager) -> void:
	_work = work
	for supply: SupplyItem in catalog.items:
		_targets[supply] = get_capacity(supply)


func get_target(supply: SupplyItem) -> int:
	return _targets.get(supply, 0)


func set_target(supply: SupplyItem, target: int) -> void:
	_targets[supply] = maxi(target, 0)
	targets_changed.emit()


## Units of `supply` in the shop: where it's kept, plus cases not yet put away.
func get_stock(supply: SupplyItem) -> int:
	var units: int = 0
	for station: Station in _work.get_stations():
		units += supply.get_units_at(station)
		var cases: DockCases = station.get_dock_cases()
		if cases != null:
			units += cases.count(supply) * supply.units_per_case
	return units


## Units the shop's storage for `supply` holds when full.
func get_capacity(supply: SupplyItem) -> int:
	var units: int = 0
	for station: Station in _work.get_stations():
		units += supply.get_capacity_at(station)
	return units


func is_delivery_day(day: int) -> bool:
	return delivery_days.has(ShopClock.get_weekday(day))


## The next day a delivery comes after `day`, or -1 if none ever does.
func get_next_delivery_day(day: int) -> int:
	for ahead: int in range(1, 8):
		if is_delivery_day(day + ahead):
			return day + ahead
	return -1


## Brings `day`'s delivery if it's a delivery day: each supply in whole cases up to its
## target, in catalog order while there's room on the drop-offs. Returns what it cost.
func deliver(day: int) -> float:
	if not is_delivery_day(day):
		return 0.0
	var cost: float = 0.0
	for supply: SupplyItem in catalog.items:
		var short: int = get_target(supply) - get_stock(supply)
		var cases: int = ceili(float(short) / supply.units_per_case) if short > 0 else 0
		for i: int in cases:
			if not _drop_case(supply):
				break
			cost += supply.get_case_price()
	if cost > 0.0:
		delivered.emit(cost)
		_work.assign_all()
	return cost


func _drop_case(supply: SupplyItem) -> bool:
	for station: Station in _work.get_stations():
		var cases: DockCases = station.get_dock_cases()
		if cases != null and cases.add_case(supply):
			return true
	return false

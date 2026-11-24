class_name OrderSource
extends Node
## Places customer orders at random between opening and last orders (the clock's
## ShopHours), more often during rushes.
## Stands in for real customers until they exist. Times are on the shop clock.

## One recipe per item ordered (e.g. three pizzas).
signal order_placed(recipes: Array[Recipe])

## Recipes customers pick from, at random.
@export var menu: Array[Recipe] = []
## Average shop-clock minutes between orders outside rushes.
@export var base_interval_minutes: float = 12.0
## Rush windows as (start, end) in minutes since midnight.
@export var rushes: Array[Vector2] = [Vector2(720, 810), Vector2(1080, 1170)]
## How many times more often orders come during a rush.
@export var rush_rate_multiplier: float = 2.0
## Relative chance of each order size: entry 0 is one item, entry 1 two items, and so on.
@export var size_weights: PackedFloat32Array = [60.0, 15.0, 15.0, 2.0, 2.0, 2.0, 2.0, 2.0]

## While false no orders come in (e.g. the shop has no manager, or nobody on shift).
var open: bool = true
## Times the normal order rate (from the shop's rating).
var demand_multiplier: float = 1.0

var _clock: ShopClock = null
var _rng := RandomNumberGenerator.new()


func setup(clock: ShopClock) -> void:
	_clock = clock


func _process(delta: float) -> void:
	if not open or _clock == null or menu.is_empty() or delta <= 0.0:
		return
	var now: int = _clock.get_minute_of_day()
	# Only between opening and last orders (see ShopHours).
	if not _clock.hours.is_taking_orders(now):
		return
	# Orders arrive at random at the current average rate (a Poisson process).
	var minutes: float = _clock.to_clock_minutes(delta)
	if randf() < minutes / get_interval_minutes(now):
		var recipes: Array[Recipe] = []
		for i: int in _rng.rand_weighted(size_weights) + 1:
			recipes.append(menu.pick_random())
		order_placed.emit(recipes)


## Average minutes between orders at `minute_of_day`.
func get_interval_minutes(minute_of_day: int) -> float:
	var rate: float = maxf(demand_multiplier, 0.01)
	for rush: Vector2 in rushes:
		if minute_of_day >= rush.x and minute_of_day < rush.y:
			rate *= rush_rate_multiplier
	return base_interval_minutes / rate

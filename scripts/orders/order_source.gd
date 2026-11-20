class_name OrderSource
extends Node
## Places customer orders at random while the shop is open, more often during rushes.
## Stands in for real customers until they exist. Times are on the shop clock.

signal order_placed(recipe: Recipe)

## Recipes customers pick from, at random.
@export var menu: Array[Recipe] = []
## Average shop-clock minutes between orders outside rushes.
@export var base_interval_minutes: float = 6.0
## Rush windows as (start, end) in minutes since midnight.
@export var rushes: Array[Vector2] = [Vector2(720, 810), Vector2(1080, 1170)]
## How many times more often orders come during a rush.
@export var rush_rate_multiplier: float = 2.0
## No new orders from this time on (minutes since midnight), so the kitchen can finish.
@export var last_order_minute: int = 21 * 60

var _clock: ShopClock = null


func setup(clock: ShopClock) -> void:
	_clock = clock


func _process(delta: float) -> void:
	if _clock == null or menu.is_empty() or delta <= 0.0:
		return
	var now: int = _clock.get_minute_of_day()
	if now >= last_order_minute:
		return
	# Orders arrive at random at the current average rate (a Poisson process).
	var minutes: float = _clock.to_clock_minutes(delta)
	if randf() < minutes / get_interval_minutes(now):
		order_placed.emit(menu.pick_random())


## Average minutes between orders at `minute_of_day`.
func get_interval_minutes(minute_of_day: int) -> float:
	for rush: Vector2 in rushes:
		if minute_of_day >= rush.x and minute_of_day < rush.y:
			return base_interval_minutes / rush_rate_multiplier
	return base_interval_minutes

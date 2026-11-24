class_name WaitEstimate
extends RefCounted
## The shop's best guess at how many shop minutes a new order will take, from ordering to
## hand-off: its own steps one after another (taking the order, the recipe, the hand-off),
## plus the work already queued ahead of it spread across the staff. Step times are scaled by
## the skill of the pawns assigned to that work, and each job adds the shop's recent average
## walk per job. Stations working unattended steps (e.g. the ovens) can be the bottleneck
## instead: their queued work is spread across the spots that do it.

var _pawns: Array[Pawn]
var _take_order_task: TaskType
var _stack_task: TaskType
var _hand_off_task: TaskType
## Shop minutes of walking added to each job.
var _walk_minutes: float
## Stations in use, for how many spots can work each unattended step.
var _stations: Array[Station]


func _init(
	pawns: Array[Pawn], take_order_task: TaskType, stack_task: TaskType, hand_off_task: TaskType,
	walk_minutes: float = 0.0, stations: Array[Station] = []
) -> void:
	_pawns = pawns
	_take_order_task = take_order_task
	_stack_task = stack_task
	_hand_off_task = hand_off_task
	_walk_minutes = walk_minutes
	_stations = stations


## Shop minutes for an order of `recipes`, with `tickets` already on the rack and `waiting`
## orders (take-order jobs) still at the register ahead of it.
func estimate(recipes: Array[Recipe], tickets: Array[Ticket], waiting: Array[Job]) -> float:
	if recipes.is_empty():
		return 0.0
	# Its own path: one item made start to finish (the others are worked alongside it).
	var path: float = _staff_minutes(_take_order_task) + _staff_minutes(_hand_off_task)
	for step: TaskType in recipes[0].steps:
		if step.unattended:
			path += _walk_minutes + step.work_minutes
		elif not step.prep:
			path += _staff_minutes(step)
	# Work the staff share: what's queued ahead, plus this order's other items and stacking.
	# Orders still in line only need the pawns who take orders.
	var shared: float = 0.0
	var at_register: float = 0.0
	# Station minutes queued for each unattended step (e.g. baking), ahead of this item.
	var station_work: Dictionary[TaskType, float] = {}
	for ticket: Ticket in tickets:
		shared += _ticket_minutes(ticket)
		_add_ticket_station_work(ticket, station_work)
	for job: Job in waiting:
		at_register += _staff_minutes(_take_order_task)
		shared += _order_minutes(job.recipes)
		for recipe: Recipe in job.recipes:
			_add_station_work(recipe.steps, 0, station_work)
	shared += _order_minutes(recipes) - _recipe_minutes(recipes[0])
	for index: int in range(1, recipes.size()):
		_add_station_work(recipes[index].steps, 0, station_work)
	var staff_wait: float = shared / maxf(_workers(), 1.0) + at_register / maxf(_cashiers(), 1.0)
	# The queue is whichever runs out last: the staff, or the busiest stations.
	var station_wait: float = 0.0
	for task: TaskType in station_work:
		station_wait = maxf(station_wait, station_work[task] / maxf(_spot_count(task), 1.0))
	return path + maxf(staff_wait, station_wait)


## Staff minutes to make and hand off a whole order from scratch.
func _order_minutes(recipes: Array[Recipe]) -> float:
	var minutes: float = _staff_minutes(_hand_off_task)
	minutes += _staff_minutes(_stack_task) * maxi(recipes.size() - 1, 0)
	for recipe: Recipe in recipes:
		minutes += _recipe_minutes(recipe)
	return minutes


## Staff minutes for every step of a recipe (stations work unattended steps on their own;
## the pawn only walks there to load it).
func _recipe_minutes(recipe: Recipe) -> float:
	var minutes: float = 0.0
	for step: TaskType in recipe.steps:
		minutes += _walk_minutes if step.unattended else _staff_minutes(step)
	return minutes


## Staff minutes left on a ticket: its items' remaining steps, stacking and the hand-off.
func _ticket_minutes(ticket: Ticket) -> float:
	if ticket.ready:
		return 0.0
	var minutes: float = 0.0
	for order_item: OrderItem in ticket.order_items:
		for job: Job in order_item.prep_jobs:
			minutes += _job_minutes(job)
		if order_item.current_job != null:
			minutes += _job_minutes(order_item.current_job)
			for index: int in range(order_item.step_index + 1, order_item.recipe.steps.size()):
				var step: TaskType = order_item.recipe.steps[index]
				if step.unattended:
					minutes += _walk_minutes
				elif not step.prep:
					minutes += _staff_minutes(step)
		if not order_item.stacked:
			minutes += _staff_minutes(_stack_task)
	if ticket.stack_base == null:
		# The first finished item is the stack's base and isn't stacked.
		minutes -= _staff_minutes(_stack_task)
	return maxf(minutes, 0.0) + _staff_minutes(_hand_off_task)


## Adds the ticket's unattended steps not started yet (the current one included, as it isn't
## loaded until its job is done) to `station_work`.
func _add_ticket_station_work(ticket: Ticket, station_work: Dictionary[TaskType, float]) -> void:
	if ticket.ready:
		return
	for order_item: OrderItem in ticket.order_items:
		if order_item.current_job != null:
			_add_station_work(order_item.recipe.steps, order_item.step_index, station_work)


## Adds the station minutes of each unattended step from `from` on to `station_work`.
func _add_station_work(
	steps: Array[TaskType], from: int, station_work: Dictionary[TaskType, float]
) -> void:
	for index: int in range(from, steps.size()):
		var step: TaskType = steps[index]
		if step.unattended:
			station_work[step] = station_work.get(step, 0.0) + step.work_minutes


## Spots on stations in use that can work `task`.
func _spot_count(task: TaskType) -> int:
	var count: int = 0
	for station: Station in _stations:
		if station.can_do(task):
			count += station.get_spot_count()
	return count


## Staff minutes left on a job, less any work already done on it (and the walk, once
## started).
func _job_minutes(job: Job) -> float:
	var walk: float = _walk_minutes if job.work_done <= 0.0 else 0.0
	if job.task_type.unattended:
		return walk
	var left: float = job.task_type.work_minutes - job.work_done / ShopClock.minutes_to_seconds(1.0)
	return walk + maxf(left, 0.0) * _time_multiplier(job.task_type.work_type)


## Shop minutes a step takes, walk included, at the skill of the pawns assigned to its work.
func _staff_minutes(task: TaskType) -> float:
	if task == null:
		return 0.0
	return _walk_minutes + task.work_minutes * _time_multiplier(task.work_type)


## Average work time multiplier of the pawns who do this work (1 if nobody does).
func _time_multiplier(work_type: WorkType) -> float:
	var total: float = 0.0
	var count: int = 0
	for pawn: Pawn in _pawns:
		if pawn.get_priority(work_type) > 0:
			total += 1.0 / pawn.get_work_rate(work_type)
			count += 1
	return total / count if count > 0 else 1.0


## Pawns who do any work.
func _workers() -> float:
	var count: int = 0
	for pawn: Pawn in _pawns:
		if not pawn.priorities.is_empty():
			count += 1
	return float(count)


## Pawns who take orders at the register.
func _cashiers() -> float:
	if _take_order_task == null:
		return 0.0
	var count: int = 0
	for pawn: Pawn in _pawns:
		if pawn.get_priority(_take_order_task.work_type) > 0:
			count += 1
	return float(count)

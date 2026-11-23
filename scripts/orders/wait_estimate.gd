class_name WaitEstimate
extends RefCounted
## The shop's best guess at how many shop minutes a new order will take, from ordering to
## hand-off: its own steps one after another (taking the order, the recipe, the hand-off),
## plus the work already queued ahead of it spread across the staff. Step times are scaled by
## the skill of the pawns assigned to that work, and each job adds the shop's recent average
## walk per job.

var _pawns: Array[Pawn]
var _take_order_task: TaskType
var _stack_task: TaskType
var _hand_off_task: TaskType
## Shop minutes of walking added to each job.
var _walk_minutes: float


func _init(
	pawns: Array[Pawn], take_order_task: TaskType, stack_task: TaskType, hand_off_task: TaskType,
	walk_minutes: float = 0.0
) -> void:
	_pawns = pawns
	_take_order_task = take_order_task
	_stack_task = stack_task
	_hand_off_task = hand_off_task
	_walk_minutes = walk_minutes


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
	var shared: float = 0.0
	for ticket: Ticket in tickets:
		shared += _ticket_minutes(ticket)
	for job: Job in waiting:
		shared += _staff_minutes(_take_order_task) + _order_minutes(job.recipes)
	shared += _order_minutes(recipes) - _recipe_minutes(recipes[0])
	return path + shared / maxf(_workers(), 1.0)


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

class_name Ticket
extends RefCounted
## A printed order on the rack. Each of its items (e.g. pizzas) is made in parallel. As
## they're finished, the first one becomes the base of a stack and the others are stacked
## on it; once all are stacked, the whole stack is handed off, and the order is ready.

enum Section { WAIT, MAKE }

var order_number: int
var section: Section = Section.WAIT
var order_items: Array[OrderItem] = []
## The first finished item, which the others are stacked on. Null until one is finished.
var stack_base: OrderItem = null
## Open jobs moving a finished item onto the stack.
var stack_jobs: Array[Job] = []
## Job carrying the finished stack to hand-off, once everything is stacked.
var hand_off_job: Job = null
## Handed off and waiting to go out. It stays on the rack until then.
var ready: bool = false
## Shop time it was handed off and became ready (-1 until then). Its wait ends here, not
## when the customer collects it.
var ready_at: int = -1
## Shop time the customer ordered (ShopClock.get_open_minutes()). Usually when it printed,
## but earlier if they waited at the register.
var printed_at: int = 0
## Shop minutes the customer waits before giving up, from printing.
var patience: int = 45
## The manager's quoted wait, in shop minutes from when the customer ordered (-1 if none).
var quoted_minutes: int = -1

var _stack_task: TaskType
var _hand_off_task: TaskType


func _init(
	p_order_number: int, recipes: Array[Recipe], stack_task: TaskType, hand_off_task: TaskType
) -> void:
	order_number = p_order_number
	_stack_task = stack_task
	_hand_off_task = hand_off_task
	for recipe: Recipe in recipes:
		order_items.append(OrderItem.new(self, recipe))


## Jobs that can be worked now, item by item, then stacking, then hand-off.
func get_active_jobs() -> Array[Job]:
	var jobs: Array[Job] = []
	for order_item: OrderItem in order_items:
		jobs.append_array(order_item.get_active_jobs())
	jobs.append_array(stack_jobs)
	if hand_off_job != null:
		jobs.append(hand_off_job)
	return jobs


func is_in_progress() -> bool:
	for job: Job in get_active_jobs():
		if job.claimed_by != null:
			return true
	return false


## Call after a job is finished: moves its item on, and the order once items are done.
func finish_job(job: Job) -> void:
	if job == hand_off_job:
		hand_off_job = null
		ready = true
		return
	if stack_jobs.has(job):
		stack_jobs.erase(job)
		job.order_item.stacked = true
		_open_hand_off()
		return
	var order_item: OrderItem = job.order_item
	order_item.finish_job(job)
	if not order_item.is_complete():
		return
	if stack_base == null:
		stack_base = order_item
		order_item.stacked = true
	else:
		var stack_job := Job.new(_stack_task, self, order_item)
		stack_jobs.append(stack_job)
	_open_hand_off()


## Items whose recipe is done (e.g. boxed).
func get_finished_count() -> int:
	var count: int = 0
	for order_item: OrderItem in order_items:
		if order_item.is_complete():
			count += 1
	return count


## The order's quality: its worst item's tier (see QualityRules.Tier), or -1 until every
## item is done.
func get_quality_tier() -> int:
	var worst: int = -1
	for order_item: OrderItem in order_items:
		if order_item.quality_tier < 0:
			return -1
		worst = order_item.quality_tier if worst < 0 else mini(worst, order_item.quality_tier)
	return worst


## What the customer pays for the whole order.
func get_price() -> float:
	var recipes: Array[Recipe] = []
	for order_item: OrderItem in order_items:
		recipes.append(order_item.recipe)
	return Recipe.get_total_price(recipes)


## Shop minutes the customer has waited for it: from ordering until it was ready (or now, if
## it isn't yet).
func get_age(now_minutes: int) -> int:
	var end: int = ready_at if ready and ready_at >= 0 else now_minutes
	return maxi(end - printed_at, 0)


## Shop minutes past the quote (negative: early). 0 if there was no quote.
func get_quote_miss(now_minutes: int) -> int:
	if quoted_minutes < 0:
		return 0
	return get_age(now_minutes) - quoted_minutes


## True once the customer has run out of patience. Handed-off orders still go out.
func is_overdue(now_minutes: int) -> bool:
	return not ready and get_age(now_minutes) >= patience


## How much of the customer's patience is used up (0-1).
func get_patience_used(now_minutes: int) -> float:
	return clampf(float(get_age(now_minutes)) / maxf(patience, 1), 0.0, 1.0)


func get_title() -> String:
	var name: String = order_items[0].recipe.display_name if not order_items.is_empty() else "?"
	if order_items.size() > 1:
		return "#%d · %d %s" % [order_number, order_items.size(), name]
	return "#%d · %s" % [order_number, name]


## Drops all jobs and items so the ticket, its items and its jobs (which reference each
## other) can be freed. Call once it's off the rack.
func release() -> void:
	for order_item: OrderItem in order_items:
		order_item.clear_jobs()
		order_item.ticket = null
	order_items.clear()
	stack_base = null
	stack_jobs.clear()
	hand_off_job = null


func _open_hand_off() -> void:
	if hand_off_job != null or ready:
		return
	for order_item: OrderItem in order_items:
		if not order_item.stacked:
			return
	hand_off_job = Job.new(_hand_off_task, self, stack_base)

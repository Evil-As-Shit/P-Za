class_name Job
extends RefCounted
## One step of an order, claimed and worked by a single pawn at one station.
## Progress is kept if the job is dropped and picked up again later.

var task_type: TaskType
var ticket: Ticket
## The order item the job works on or moves (e.g. one pizza). For a hand-off, the stack's
## base.
var order_item: OrderItem
## For shop jobs that aren't part of an order (ticket and order_item are null): the item
## the job moves, e.g. leftovers to throw out.
var target: Item = null
## For taking an order at the register (a shop job): what the customer is ordering, one
## recipe per item, and the shop time they ordered (ShopClock.get_open_minutes()).
var recipes: Array[Recipe] = []
var placed_at: int = 0
## The manager's quoted wait for that order, in shop minutes (-1 if none).
var quoted_minutes: int = -1
## While true no pawn takes the job (e.g. an order whose customer hasn't reached the
## register yet).
var on_hold: bool = false
## For jobs that put something away (e.g. a folded box): the storage it goes to. Its room
## is claimed until it's stored.
var destination: Station = null
## Shop minutes of work on top of the task's own (e.g. folding a flat box first).
var extra_minutes: float = 0.0
## How much was left in the unit last taken from storage (e.g. dough balls in a container
## put back partly used), or -1 for a full one. See Station.take_supply().
var taken_left: int = -1
## The dish last taken from storage that holds dishes (e.g. Empty Dishes), or null.
var taken_dish: Dish = null
## Dishes a pawn is washing (taken off a sink's dirty drainboard).
var dishes: Array[Dish] = []
## True for the steps of an order item's recipe (not stacking or hand-off).
var recipe_step: bool = false
## Station spot reserved for this job while it is claimed.
var station: Station = null
var spot: int = -1
## Stops still to make on the way to the work spot, in order.
var stops: Array[JobStop] = []
var claimed_by: Pawn = null
var work_done: float = 0.0
## For a job done in parts by one pawn (e.g. fold a box, then put it away): the part under
## way, from 0. See TaskBehavior.continue_job().
var part: int = 0


func _init(p_task_type: TaskType, p_ticket: Ticket, p_order_item: OrderItem) -> void:
	task_type = p_task_type
	ticket = p_ticket
	order_item = p_order_item


## Pawn work needed. Unattended tasks need none: the pawn just loads the item.
func get_work_required() -> float:
	if task_type.unattended:
		return 0.0
	return task_type.get_behavior().get_work_seconds(self) + ShopClock.minutes_to_seconds(extra_minutes)


func is_complete() -> bool:
	return work_done >= get_work_required()


## Adds work and returns true once the job is complete.
func add_work(amount: float) -> bool:
	if is_complete():
		return true
	work_done += amount
	return is_complete()


## How far along the work is (0-1). Jobs that need no work are done.
func get_progress() -> float:
	var required: float = get_work_required()
	return 1.0 if required <= 0.0 else minf(work_done / required, 1.0)

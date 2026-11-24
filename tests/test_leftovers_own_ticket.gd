extends "res://tests/test_base.gd"
## A cancelled order throws out only what was made for it: another order's pizza lying on
## the floor and a dough container with units left on the floor stay.

var _cancelled_ticket: Ticket
var _other_ticket: Ticket
var _other_item: Item
var _dough: Item
var _own_item: Item
var _armed: bool = false


func _start() -> void:
	stop_random_orders()
	clock.set_speed(6)
	_cancelled_ticket = order_pizzas(1)
	rack.ticket_cancelled.connect(_on_cancelled)


func _step() -> void:
	if _armed:
		return
	var item: Item = _cancelled_ticket.order_items[0].item
	if item == null:
		return
	_own_item = item
	_armed = true
	var cell: Vector2i = work.get_cell(work.get_pawns()[0])
	# Another order (in Wait, so nobody works it) whose pizza is on the floor.
	_other_ticket = rack.print_ticket([world.debug_recipe] as Array[Recipe])
	_other_item = work.spawn_item(null)
	work.drop_on_floor(_other_item, cell)
	_other_ticket.order_items[0].item = _other_item
	# A dough container with units left, on the floor, belonging to nobody.
	var behavior := world.debug_recipe.steps[0].get_behavior() as IngredientBehavior
	if behavior == null:
		fail("the debug recipe doesn't start from an ingredient container")
		return
	_dough = IngredientBehavior.spawn_container(behavior.ingredient, work)
	work.drop_on_floor(_dough, cell)
	_cancelled_ticket.patience = 0


func _on_cancelled(ticket: Ticket) -> void:
	if ticket != _cancelled_ticket:
		return
	var targets: Array[Item] = []
	for job: Job in work.get_shop_jobs():
		if job.task_type == work.throw_out_task and job.target != null:
			targets.append(job.target)
	if targets.has(_other_item):
		fail("another order's pizza on the floor was thrown out")
		return
	if targets.has(_dough):
		fail("a dough container with units left was thrown out")
		return
	if not is_instance_valid(_own_item) or not targets.has(_own_item.get_outermost()):
		fail("the cancelled order's own item wasn't thrown out")
		return
	pass_test("only the cancelled order's item went to the garbage")

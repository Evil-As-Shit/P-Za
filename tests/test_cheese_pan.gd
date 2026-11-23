extends "res://tests/test_base.gd"
## The prep table's cheese pan: with it empty and no cheese in storage, the cheese step
## waits. Once there's cheese again, a Hauling pawn takes a bag from the walk-in's Cheese
## rack, refills the pan in place and throws the empty bag in the garbage; the pizza is
## cheesed and the order goes out with the pan at 9 of 10.

const PAN := preload("res://resources/items/cheese_pan.tres")
## Frames the cheese step must wait while there's no cheese.
const WAIT_FRAMES: int = 300

var _prep: Station
var _cheese_rack: Station
var _build: BuildMode
var _ticket: Ticket
var _rack_stock: int = 0
var _waiting_since: int = -1
var _phase: int = 0
var _refilled: bool = false
var _bag_thrown: bool = false


func _start() -> void:
	stop_random_orders()
	clock.set_speed(6)
	rack.patience_minutes = 100000
	rack.patience_past_quote = 100000
	_prep = world.get_node("Entities/PrepTable")
	_cheese_rack = world.get_node("Entities/CheeseRack")
	_build = world.get_node("BuildMode")
	_rack_stock = _cheese_rack.get_stock()
	# The pan is empty and the cheese is out of reach.
	_prep.use_pan(PAN, PAN.portions)
	world._set_build_mode(true)
	_build.pick_up(_cheese_rack)
	_ticket = order_pizzas(1)
	rack.ticket_completed.connect(_on_completed)


func _step() -> void:
	for pawn: Pawn in work.get_pawns():
		var job: Job = pawn.get_job()
		if job == null or job.task_type.id != &"refill_cheese" or not pawn.is_working():
			continue
		if job.part == RefillPanBehavior.Part.REFILL:
			_refilled = true
		elif job.part == RefillPanBehavior.Part.THROW_OUT and job.station.data.display_name == "Garbage Can":
			_bag_thrown = true
	if _phase != 0:
		return
	var order_item: OrderItem = _ticket.order_items[0]
	if order_item.current_job == null or order_item.current_job.task_type.id != &"cheese":
		return
	if order_item.current_job.claimed_by != null:
		fail("the cheese step started with an empty pan")
		return
	if _waiting_since < 0:
		_waiting_since = frame
	elif frame - _waiting_since >= WAIT_FRAMES:
		# Cheese is back.
		_build.cancel()
		world._set_build_mode(false)
		_phase = 1


func _on_completed(ticket: Ticket) -> void:
	if ticket != _ticket:
		return
	if _phase == 0:
		fail("the order went out while there was no cheese")
	elif not _refilled or not _bag_thrown:
		fail("refilled %s, bag thrown out %s" % [_refilled, _bag_thrown])
	elif _prep.get_pan_left(PAN) != PAN.portions - 1:
		fail("the pan has %d left, not %d" % [_prep.get_pan_left(PAN), PAN.portions - 1])
	elif _cheese_rack.get_stock() != _rack_stock - 1:
		fail("the Cheese rack has %d bags, not %d" % [_cheese_rack.get_stock(), _rack_stock - 1])
	elif not work.get_floor_items().is_empty():
		fail("something was left on the floor")
	else:
		pass_test("cheese waited, then the pan was refilled from a bag and the bag thrown out")

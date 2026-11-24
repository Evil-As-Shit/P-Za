extends "res://tests/test_base.gd"
## A customer walks in the front door, lines up at the register (their order isn't taken
## until they're there), waits in the lobby once it's taken, walks to the pickup counter
## when it's ready, carries it out and leaves.

var _lobby: Lobby
var _shop_floor: ShopFloor
var _customer: Customer
var _ticket: Ticket = null
var _picked_up: bool = false


func _start() -> void:
	stop_random_orders()
	clock.set_speed(6)
	_lobby = world.get_node("Lobby")
	_shop_floor = world.get_node("ShopFloor")
	world._on_order_placed([world.debug_recipe] as Array[Recipe])
	if _lobby.get_line().size() != 1:
		fail("the customer didn't join the line")
		return
	_customer = _lobby.get_line()[0]
	if _shop_floor.is_walkable(_shop_floor.global_to_cell(_customer.global_position)):
		fail("the customer didn't come in from outside")
		return
	work.order_taken.connect(_on_order_taken)
	world.get_node("Lobby").reached_pickup.connect(func(_c: Customer) -> void: _picked_up = true)


func _on_order_taken(_job: Job) -> void:
	if not _customer.at_register:
		fail("the order was taken before the customer reached the register")
		return
	var front: Vector2i = _lobby.get_line_cells()[0]
	if _shop_floor.global_to_cell(_customer.global_position) != front:
		fail("the order was taken with the customer away from the register")


func _step() -> void:
	if not is_instance_valid(_customer):
		if not _picked_up:
			fail("the customer left without picking up their order")
			return
		if finances.get_today().orders_served != 1:
			fail("orders served is %d, expected 1" % finances.get_today().orders_served)
			return
		pass_test("customer lined up, waited, picked up and left")
		return
	if _ticket == null and _customer.ticket != null:
		_ticket = _customer.ticket
		if _customer.state != Customer.State.WAITING or _lobby.get_line().has(_customer):
			fail("the customer is still in line after ordering")
			return
	if _customer.state == Customer.State.WAITING and _customer.ticket != null \
			and not _customer.is_walking():
		var cell: Vector2i = _shop_floor.global_to_cell(_customer.global_position)
		if not _shop_floor.is_lobby(cell):
			fail("the customer waits outside the lobby, at %s" % cell)
			return
	if _customer.state == Customer.State.LEAVING and _customer.get_held_item() == null:
		fail("the customer left without carrying their order")

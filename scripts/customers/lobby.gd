class_name Lobby
extends Node
## The customers in the lobby. Each comes in the front door and joins the line at the
## register; once their order is taken they stand somewhere in the lobby, walk to the pickup
## counter when it's ready, and carry it out the front door. Customers who give up walk out.
## It only moves customers: the world places, takes and pays for their orders.

## The customer at the front of the line reached the register: their order can be taken.
signal reached_register(job: Job)
## A customer reached the pickup counter to collect their order (their ticket).
signal reached_pickup(customer: Customer)
## A customer walked onto a cell's center (a global position), e.g. to dirty the floor.
signal customer_cell_reached(at: Vector2)

## Target cell of a customer walking out through the front door, to the street.
const OUTSIDE := Vector2i(-100000, -100000)

@export var customer_scene: PackedScene
## Customers in the register line at most; more turn around (placeholder).
@export var max_line: int = 10
## Shirt colors are random hues at this saturation and value (placeholder).
@export var shirt_saturation: float = 0.65
@export var shirt_value: float = 0.65

var _floor: ShopFloor = null
var _parent: Node2D = null
var _stations: Array[Station] = []
var _take_order_task: TaskType = null
var _hand_off_task: TaskType = null
var _door_cell: Vector2i = Vector2i.ZERO
var _outside_cell: Vector2i = Vector2i.ZERO
## Customers in the register line, front first.
var _line: Array[Customer] = []
var _customers: Array[Customer] = []


## `stations` is the shop's list of stations in use (kept up to date by its owner), the
## tasks find the register and pickup counter, and customers come and go through the door
## on `door_cell`'s edge toward `outside_cell`.
func setup(
	shop_floor: ShopFloor, parent: Node2D, stations: Array[Station], take_order_task: TaskType,
	hand_off_task: TaskType, door_cell: Vector2i, outside_cell: Vector2i
) -> void:
	_floor = shop_floor
	_parent = parent
	_stations = stations
	_take_order_task = take_order_task
	_hand_off_task = hand_off_task
	_door_cell = door_cell
	_outside_cell = outside_cell


func has_room_in_line() -> bool:
	return _line.size() < max_line


## Customers in the register line, front first.
func get_line() -> Array[Customer]:
	return _line


## Every customer in the shop, including those on their way out.
func get_customers() -> Array[Customer]:
	return _customers


## A customer comes in to place the order of `job` (held until they reach the register).
func admit(job: Job) -> Customer:
	var customer := customer_scene.instantiate() as Customer
	customer.order_job = job
	customer.target_cell = OUTSIDE
	_parent.add_child(customer)
	customer.global_position = _floor.cell_to_global(_outside_cell)
	customer.set_shirt_color(Color.from_hsv(randf(), shirt_saturation, shirt_value))
	customer.arrived.connect(_on_arrived.bind(customer))
	customer.cell_reached.connect(customer_cell_reached.emit)
	_customers.append(customer)
	_line.append(customer)
	_move_line()
	return customer


## A pawn took the customer's order and its ticket printed: they step out of line to wait.
func order_taken(job: Job, ticket: Ticket) -> void:
	var customer: Customer = _find_by_job(job)
	if customer == null:
		return
	customer.order_job = null
	customer.ticket = ticket
	customer.state = Customer.State.WAITING
	_line.erase(customer)
	_walk(customer, _random_wait_cell(customer))
	_move_line()


## The ticket's order is on the pickup counter: its customer walks over for it. Returns
## false if no customer is waiting for it or the counter can't be reached.
func order_ready(ticket: Ticket) -> bool:
	var customer: Customer = _find_by_ticket(ticket)
	if customer == null or customer.state != Customer.State.WAITING:
		return false
	var stack: Item = ticket.stack_base.item if ticket.stack_base != null else null
	if stack == null or stack.station == null:
		return false
	for cell: Vector2i in _front_cells(stack.station):
		if not _floor.get_path_points(_floor.global_to_cell(customer.global_position), cell).is_empty():
			customer.state = Customer.State.PICKING_UP
			_walk(customer, cell)
			return true
	return false


## The customer whose order is `job` gave up in line.
func give_up_order(job: Job) -> void:
	var customer: Customer = _find_by_job(job)
	if customer != null:
		leave(customer)


## The customer of `ticket` is done: they gave up, or their order went out without them.
func ticket_done(ticket: Ticket) -> void:
	var customer: Customer = _find_by_ticket(ticket)
	if customer != null:
		leave(customer)


## The customer walks out the front door.
func leave(customer: Customer) -> void:
	if customer.state == Customer.State.LEAVING:
		return
	var was_in_line: bool = _line.has(customer)
	_line.erase(customer)
	customer.state = Customer.State.LEAVING
	customer.order_job = null
	_walk(customer, _door_cell)
	if was_in_line:
		_move_line()


## Stations moved, were built or sold: the line follows the register.
func refresh() -> void:
	_move_line()


## Sends each customer in line to their place in it. With no register they stand around.
func _move_line() -> void:
	var cells: Array[Vector2i] = get_line_cells()
	for i: int in _line.size():
		var customer: Customer = _line[i]
		var cell: Vector2i = customer.target_cell
		if not cells.is_empty():
			cell = cells[mini(i, cells.size() - 1)]
		elif cell == OUTSIDE or not _floor.is_lobby(cell):
			cell = _random_wait_cell(customer)
		if cell != customer.target_cell:
			_walk(customer, cell)
		elif i == 0 and not customer.is_walking():
			# Already standing at the front (e.g. a one-cell line): they're at the register.
			_on_arrived(customer)


func _walk(customer: Customer, cell: Vector2i) -> void:
	customer.target_cell = cell
	var from: Vector2i = _floor.global_to_cell(customer.global_position)
	# Coming in from the street: through the door first.
	if not _floor.is_walkable(from):
		from = _door_cell
	customer.walk(_floor.get_path_points(from, cell))


func _on_arrived(customer: Customer) -> void:
	match customer.state:
		Customer.State.IN_LINE:
			var register: Station = _get_register()
			if register == null:
				return
			customer.look_toward(_floor.cell_to_global(register.cell))
			var cells: Array[Vector2i] = get_line_cells()
			if _line.find(customer) == 0 and customer.target_cell == cells[0] and not customer.at_register:
				customer.at_register = true
				reached_register.emit(customer.order_job)
		Customer.State.PICKING_UP:
			reached_pickup.emit(customer)
		Customer.State.LEAVING:
			if customer.target_cell == OUTSIDE:
				_customers.erase(customer)
				customer.queue_free()
			else:
				customer.target_cell = OUTSIDE
				customer.walk(PackedVector2Array([_floor.cell_to_global(_outside_cell)]))


## The cells of the register line, front first: in front of the register, a step back into
## the lobby, then snaking along the lobby away from the pickup counter. Empty with no
## register (or none open to the lobby).
func get_line_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var register: Station = _get_register()
	if register == null:
		return cells
	var front: Vector2i = Vector2i.ZERO
	var inward: Vector2i = Vector2i.ZERO
	for cell: Vector2i in register.get_footprint_cells():
		for step: Vector2i in ShopWalls.SIDE_STEP:
			if cells.is_empty() and _is_open(cell, cell + step, register, cells):
				front = cell + step
				inward = step
				cells.append(front)
	if cells.is_empty():
		return cells
	var pickup_cells: Array[Vector2i] = _get_pickup_cells()
	var along := Vector2i(inward.y, inward.x)
	if not pickup_cells.is_empty() and Vector2(pickup_cells[0] - front).dot(Vector2(along)) > 0.0:
		along = -along
	var current: Vector2i = front
	var steps: Array[Vector2i] = [inward]
	while cells.size() < max_line:
		var moved: bool = false
		for step: Vector2i in steps:
			if _is_open(current, current + step, register, cells) and not pickup_cells.has(current + step):
				current += step
				cells.append(current)
				moved = true
				if step == inward and steps.size() > 1:
					along = -along
				break
		if not moved:
			break
		steps = [along, inward]
	return cells


## True if a customer can stand on `cell`, stepping there from `from`: open lobby floor,
## not the door, not the station or a cell already taken.
func _is_open(from: Vector2i, cell: Vector2i, station: Station, taken: Array[Vector2i]) -> bool:
	return _floor.is_lobby(cell) and _floor.is_walkable(cell) and cell != _door_cell \
			and not station.get_footprint_cells().has(cell) and not taken.has(cell) \
			and not _floor.is_edge_blocked(from, cell)


## Lobby cells beside a station's footprint, where a customer stands to use it.
func _front_cells(station: Station) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for cell: Vector2i in station.get_footprint_cells():
		for step: Vector2i in ShopWalls.SIDE_STEP:
			if _is_open(cell, cell + step, station, cells):
				cells.append(cell + step)
	return cells


func _get_register() -> Station:
	for station: Station in _stations:
		if station.can_do(_take_order_task) and not _front_cells(station).is_empty():
			return station
	return null


func _get_pickup_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for station: Station in _stations:
		if station.can_do(_hand_off_task):
			cells.append_array(_front_cells(station))
	return cells


## A lobby cell to stand on while waiting: not in the line, at a counter or the door, and
## not where another customer is headed, if there's room.
func _random_wait_cell(customer: Customer) -> Vector2i:
	var avoid: Array[Vector2i] = get_line_cells()
	avoid.append_array(_get_pickup_cells())
	var taken: Array[Vector2i] = []
	for other: Customer in _customers:
		if other != customer:
			taken.append(other.target_cell)
	var open: Array[Vector2i] = []
	var free: Array[Vector2i] = []
	for cell: Vector2i in _floor.get_used_cells():
		if _floor.is_lobby(cell) and _floor.is_walkable(cell) and cell != _door_cell and not avoid.has(cell):
			open.append(cell)
			if not taken.has(cell):
				free.append(cell)
	if not free.is_empty():
		return free.pick_random()
	if not open.is_empty():
		return open.pick_random()
	return _door_cell


func _find_by_job(job: Job) -> Customer:
	for customer: Customer in _customers:
		if customer.order_job == job and job != null:
			return customer
	return null


func _find_by_ticket(ticket: Ticket) -> Customer:
	for customer: Customer in _customers:
		if customer.ticket == ticket and ticket != null:
			return customer
	return null

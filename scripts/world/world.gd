extends Node2D
## The shop. Sets up the floor, stations and staff, and connects the systems: the manager
## quotes each order (no orders come in without one), orders are taken at the register and
## print tickets, the WorkManager has pawns work them, finished orders are paid for, late
## ones are cancelled, customers review each order (the rating scales demand), and each day
## closes with a report. Also handles the player's input.

## Recipe printed by the debug hotkey (J).
@export var debug_recipe: Recipe
## Shop minutes a finished order with no customer to collect it (e.g. from the debug
## hotkey) waits where it was handed off before it goes out.
@export var pickup_wait_minutes: float = 0.6
## Placeholder: new tickets go straight to the bottom of Make instead of waiting in Wait.
@export var auto_make: bool = true

var _stations: Array[Station] = []
## Station shown in the station panel, or null.
var _selected_station: Station = null
## Item shown in the item panel, or null.
var _selected_item: Item = null

@onready var _floor: ShopFloor = $ShopFloor
@onready var _floor_dirt: FloorDirt = $FloorDirt
@onready var _entities: Node2D = $Entities
@onready var _walls: ShopWalls = $Entities/Walls
@onready var _camera: ShopCamera = $ShopCamera
@onready var _work: WorkManager = $Work
@onready var _rack: TicketRack = $TicketRack
@onready var _clock: ShopClock = $ShopClock
@onready var _orders: OrderSource = $OrderSource
@onready var _finances: ShopFinances = $ShopFinances
@onready var _reputation: ShopReputation = $ShopReputation
@onready var _hud: Hud = $Hud
@onready var _build: BuildMode = $BuildMode
@onready var _lobby: Lobby = $Lobby
@onready var _deliveries: Deliveries = $Deliveries
@onready var _social: Social = $Social


func _ready() -> void:
	_camera.position = _floor.cell_to_global(_floor.get_used_rect().get_center())
	_walls.build(_floor)
	_work.setup(_floor, _entities, _rack)
	_floor_dirt.setup(_floor)
	_work.floor_dirt = _floor_dirt
	# Walk-ins first, so the stations inside them know they're in one.
	for walk_ins_first: bool in [true, false]:
		for child: Node in _entities.get_children():
			var station := child as Station
			if station != null and (station.data.walk_in != null) == walk_ins_first:
				_setup_station(station)
				# The starting shop opens stocked; stations built later start empty.
				station.stock_up()
	var rng := RandomNumberGenerator.new()
	for child: Node in _entities.get_children():
		if child is Pawn:
			var pawn := child as Pawn
			pawn.global_position = _floor.cell_to_global(_floor.get_random_walkable_cell())
			pawn.roll_skills(_work.get_skill_types(), rng)
			pawn.roll_traits(rng)
			pawn.cell_reached.connect(_floor_dirt.add_step)
			_work.add_pawn(pawn)
	_social.setup(_work.get_pawns(), _floor, rng)

	_rack.jobs_changed.connect(_work.assign_all)
	_rack.job_withdrawn.connect(_work.withdraw_job)
	_rack.ticket_cancelled.connect(_on_ticket_cancelled)
	_work.order_ready.connect(_on_order_ready)
	_deliveries.setup(_work)
	_deliveries.delivered.connect(_finances.record_supplies)
	_clock.time_changed.connect(_on_time_changed)
	_clock.day_started.connect(_on_day_started)
	_orders.setup(_clock)
	_orders.order_placed.connect(_on_order_placed)
	_work.order_taken.connect(_on_order_taken)
	_setup_lobby()

	_hud.setup(_clock, _rack, _finances, _work.get_pawns(), _work.work_types, _work.managing)
	_hud.priority_change_requested.connect(_on_priority_change_requested)
	_hud.manager_change_requested.connect(_on_manager_change_requested)
	_work.manager_changed.connect(_on_manager_changed)
	_on_manager_changed(_work.get_manager())
	for pawn: Pawn in _work.get_pawns():
		pawn.skill_leveled_up.connect(_hud.refresh_priorities.unbind(2))
	_hud.role_change_requested.connect(_on_role_change_requested)
	_hud.station_close_requested.connect(_select_station.bind(null))
	_hud.setup_items(_rack.find_order_item, _work.quality_rules)
	_hud.item_close_requested.connect(_select_item.bind(null))
	_hud.report_closed.connect(_on_report_closed)
	_hud.setup_supplies(_deliveries)
	_hud.supply_target_change_requested.connect(_deliveries.set_target)
	_work.waiting_orders_changed.connect(_hud.show_waiting_orders)
	_work.rush_changed.connect(_hud.show_rush)
	_hud.pawn_select_requested.connect(_on_pawn_select_requested)
	_hud.setup_social(_social)
	_reputation.rating_changed.connect(_on_rating_changed)
	_on_rating_changed(_reputation.rating)

	_build.setup(_floor, _entities, _stations, _work.get_pawns(), _work.get_floor_items)
	_build.station_built.connect(_on_station_built)
	_build.move_started.connect(_on_station_move_started)
	_build.move_finished.connect(_on_station_built)
	_hud.setup_build(_build.catalog)
	_hud.build_choice_requested.connect(_build.choose)
	_hud.build_close_requested.connect(_set_build_mode.bind(false))
	_hud.build_mode_requested.connect(_set_build_mode)
	_hud.sell_requested.connect(_build.sell)
	_build.holding_changed.connect(_hud.set_can_sell)
	_build.station_sold.connect(_work.assign_all.unbind(1))
	_build.station_sold.connect(_lobby.refresh.unbind(1))


## Customers come and go through the front door: the first door onto lobby floor.
func _setup_lobby() -> void:
	var door_cell := Vector2i.ZERO
	var outside := Vector2i.ZERO
	for door: Vector3i in _walls.doors:
		var cell := Vector2i(door.x, door.y)
		if _floor.is_lobby(cell):
			door_cell = cell
			outside = cell + ShopWalls.SIDE_STEP[door.z]
			break
	_lobby.setup(_floor, _entities, _stations, _work.take_order_task, _rack.hand_off_task, door_cell, outside)
	_lobby.reached_register.connect(_work.release_order)
	_lobby.reached_pickup.connect(_on_customer_at_pickup)
	_lobby.customer_cell_reached.connect(_floor_dirt.add_step)


func _unhandled_input(event: InputEvent) -> void:
	if _build.active and _build.handle_input(event):
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"toggle_build"):
		_set_build_mode(not _build.active)
	elif _build.active and event.is_action_pressed(&"ui_cancel"):
		_set_build_mode(false)
	elif event.is_action_pressed(&"debug_queue_job"):
		var recipes: Array[Recipe] = [debug_recipe]
		_print_ticket(recipes, -1, _work.quote_order(recipes))
	elif event.is_action_pressed(&"toggle_priorities"):
		_hud.toggle_priorities()
	elif event.is_action_pressed(&"toggle_walls"):
		_walls.cycle_view_mode()
		for station: Station in _stations:
			station.set_wall_view(_walls.view_mode)
	elif event.is_action_pressed(&"toggle_pause"):
		_clock.toggle_pause()
	elif event.is_action_pressed(&"speed_1"):
		_clock.set_speed(_clock.speeds[1])
	elif event.is_action_pressed(&"speed_2"):
		_clock.set_speed(_clock.speeds[2])
	elif event.is_action_pressed(&"speed_3"):
		_clock.set_speed(_clock.speeds[3])
	elif event.is_action_pressed(&"speed_4"):
		_clock.set_speed(_clock.speeds[4])
	elif not _build.active and event is InputEventMouseButton \
			and (event as InputEventMouseButton).pressed \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_select_at(get_global_mouse_position())
	else:
		return
	get_viewport().set_input_as_handled()


## Puts a station to work: its cells (or a walk-in's walls) block pawns, and a walk-in's
## floor is off limits to wandering. A station inside a walk-in can take roles that need
## one; one outside loses them.
func _setup_station(station: Station) -> void:
	station.place(_floor)
	station.set_wall_view(_walls.view_mode)
	for cell: Vector2i in station.get_blocked_cells():
		_floor.set_cell_blocked(cell, true)
	_set_walls_up(station, true)
	station.in_walk_in = _walk_in_around(station) != null
	if station.role != null and station.role.needs_walk_in and not station.in_walk_in:
		station.set_role(null)
	_stations.append(station)
	_work.add_station(station)


## Puts a walk-in's walls up (or takes them down), and keeps wandering pawns off its floor.
func _set_walls_up(station: Station, up: bool) -> void:
	for edge: Vector4i in station.get_wall_edges():
		_floor.set_edge_blocked(Vector2i(edge.x, edge.y), Vector2i(edge.z, edge.w), up)
	if station.data.walk_in != null:
		for cell: Vector2i in station.get_footprint_cells():
			_floor.set_no_wander(cell, up)


## The walk-in in use that the station stands inside, or null.
func _walk_in_around(station: Station) -> Station:
	if station.data.walk_in != null:
		return null
	for other: Station in _stations:
		if station.get_footprint_cells().all(other.is_room_cell):
			return other
	return null


#region Stations

func _set_build_mode(on: bool) -> void:
	_select(null)
	_build.set_active(on)
	_hud.show_build(on)


## A station was built, or put down after a move: it's in use again.
func _on_station_built(station: Station) -> void:
	_setup_station(station)
	# Pawns walking across a walk-in's footprint may now be walking through its walls.
	var cells: Array[Vector2i] = station.get_blocked_cells()
	if station.data.walk_in != null:
		cells = station.get_footprint_cells()
	_work.reroute_around(cells)
	_work.assign_all()
	_lobby.refresh()


## A station was picked up to move: nobody uses it until it's put down, and pawns using it
## stop (what's on it comes along).
func _on_station_move_started(station: Station) -> void:
	for cell: Vector2i in station.get_blocked_cells():
		_floor.set_cell_blocked(cell, false)
	_set_walls_up(station, false)
	if station == _selected_station:
		_select_station(null)
	_stations.erase(station)
	_work.remove_station(station)
	_lobby.refresh()


## Selects what's drawn in front at a point, pixel by pixel (see PixelPick): a pawn, an
## item (on a station, the floor or in someone's hands) or a station. Clicking empty floor,
## or something that can't be selected (a wall, a customer), clears the selection.
func _select_at(point: Vector2) -> void:
	_select(_selectable_from(PixelPick.find(_entities, point)))


## The pawn, item or station a drawn node belongs to (the innermost item, e.g. a pizza in
## its box), or null.
func _selectable_from(node: Node) -> Node:
	while node != null and node != _entities:
		if node is Item or node is Pawn or node is Station:
			return node
		if node is Customer:
			return null
		node = node.get_parent()
	return null


## Shows `target` (a pawn, item or station) in its panel and hides the others; null hides all.
func _select(target: Node) -> void:
	_select_station(target as Station)
	_select_item(target as Item)
	_hud.show_pawn(target as Pawn)


## A pawn card was clicked: select them, and on a double-click center the camera on them.
func _on_pawn_select_requested(pawn: Pawn, focus: bool) -> void:
	_select(pawn)
	if focus:
		_camera.focus_on(pawn.global_position)


func _select_item(item: Item) -> void:
	if _selected_item != null and is_instance_valid(_selected_item):
		_selected_item.set_selected(false)
	_selected_item = item
	if item != null:
		item.set_selected(true)
	_hud.show_item(item)


func _select_station(station: Station) -> void:
	if _selected_station != null:
		_selected_station.set_selected(false)
	_selected_station = station
	# Role labels show while a station is selected, like zones while editing them.
	for each: Station in _stations:
		each.show_role_label(station != null)
	if station != null:
		station.set_selected(true)
	_hud.show_station(station)


## Pawns using the station stop: what they were fetching or bringing may not be stored there
## any more. Their jobs keep their progress and are offered again, under the new role.
func _on_role_change_requested(station: Station, role: StationRole) -> void:
	if role != null and not station.get_available_roles().has(role):
		return
	if role != station.role:
		station.set_role(role)
		_work.interrupt_jobs_at(station)
	# Refreshed even when unchanged, so the picked role's button stays pressed.
	if station == _selected_station:
		_hud.show_station(station)
	_work.assign_all()


func _on_priority_change_requested(pawn: Pawn, work_type: WorkType, priority: int) -> void:
	pawn.set_priority(work_type, priority)
	_hud.refresh_priorities()
	_work.try_assign(pawn)


func _on_manager_change_requested(pawn: Pawn, on: bool) -> void:
	if on:
		_work.set_manager(pawn)
	elif pawn.is_manager:
		_work.set_manager(null)


## The shop only takes orders with a manager on shift.
func _on_manager_changed(manager: Pawn) -> void:
	_orders.open = manager != null
	_hud.show_no_manager(manager == null)
	_hud.refresh_priorities()

#endregion


#region Orders

## A customer comes in and the manager quotes the wait: they join the register line, and a
## Cashier pawn takes the order once they reach the register. With the line full they turn
## around: the sale is lost, with no review.
func _on_order_placed(recipes: Array[Recipe]) -> void:
	if not _lobby.has_room_in_line():
		_finances.record_missed(Recipe.get_total_price(recipes))
		return
	var job: Job = _work.take_order(recipes, _rack.now_minutes, _work.quote_order(recipes), true)
	_lobby.admit(job)


## A pawn took the order at the register: its ticket prints and the customer waits.
func _on_order_taken(job: Job) -> void:
	var ticket: Ticket = _print_ticket(job.recipes, job.placed_at, job.quoted_minutes)
	_lobby.order_taken(job, ticket)


## Prints the order's ticket and returns it. `placed_at` is when the customer ordered (-1
## for now) and `quoted` the manager's quote (-1 for none). The debug hotkey prints straight
## here, skipping the register (and with no customer).
func _print_ticket(recipes: Array[Recipe], placed_at: int = -1, quoted: int = -1) -> Ticket:
	var ticket: Ticket = _rack.print_ticket(recipes, placed_at, quoted)
	if auto_make:
		_rack.move_ticket(ticket, Ticket.Section.MAKE, _rack.get_tickets(Ticket.Section.MAKE).size())
	return ticket


## Handed off: the customer walks up for it. With no customer to collect it, it goes out
## after a short wait.
func _on_order_ready(ticket: Ticket) -> void:
	if _lobby.order_ready(ticket):
		return
	get_tree().create_timer(ShopClock.minutes_to_seconds(pickup_wait_minutes)).timeout.connect(
		_send_out.bind(ticket, null)
	)


## The customer is at the pickup counter: they take their order, pay and leave.
func _on_customer_at_pickup(customer: Customer) -> void:
	_send_out(customer.ticket, customer)


## The finished order is picked up and paid for: its stack leaves its spot, carried out by
## `customer` (or just gone with none), and the customer heads out. Its wait (for the review
## and the day's ticket times) ran until it was ready, not until it was collected.
func _send_out(ticket: Ticket, customer: Customer) -> void:
	_finances.record_sale(ticket.get_price(), ticket.order_items.size(), ticket.get_age(_rack.now_minutes))
	_reputation.review_order(ticket, _rack.now_minutes)
	var stack: Item = ticket.stack_base.item if ticket.stack_base != null else null
	for order_item: OrderItem in ticket.order_items:
		order_item.item = null
	if stack != null:
		if stack.station != null:
			stack.station.take_item(stack.spot)
		if customer != null:
			customer.hold_item(stack)
		else:
			stack.queue_free()
	_rack.send_out(ticket)
	if customer != null:
		_lobby.leave(customer)
	else:
		_lobby.ticket_done(ticket)


## The customer gave up: the sale is lost and whatever was made for it is thrown out.
func _on_ticket_cancelled(ticket: Ticket) -> void:
	_finances.record_missed(ticket.get_price())
	_reputation.review_left(false)
	_work.throw_out_leftovers(ticket)
	_lobby.ticket_done(ticket)


## Reviews move the rating, and the rating scales how often orders come in.
func _on_rating_changed(rating: float) -> void:
	_orders.demand_multiplier = _reputation.get_demand_multiplier()
	_hud.show_rating(rating)

#endregion


#region Time

func _on_time_changed(_day: int, _minute: int) -> void:
	_rack.now_minutes = _clock.get_open_minutes()
	_rack.cancel_overdue()
	# Customers still waiting at the register give up after the same patience.
	for job: Job in _work.get_waiting_orders():
		if _rack.now_minutes - job.placed_at >= _rack.get_patience(job.quoted_minutes):
			_work.drop_order(job)
			_lobby.give_up_order(job)
			_finances.record_missed(Recipe.get_total_price(job.recipes))
			_reputation.review_left(true)
	_hud.update_ticket_times()


## A day ended: pay wages and bills, and pause on the day's report until it's closed.
## Orders still open carry over into the new day. Then the new day's delivery (if any)
## arrives and is paid for on the new day.
func _on_day_started(day: int) -> void:
	if day <= 1:
		return
	_close_day(day - 1)
	for pawn: Pawn in _work.get_pawns():
		pawn.rest_overnight()
	_deliveries.deliver(day)


func _close_day(day: int) -> void:
	var hours: float = float(_clock.close_hour - _clock.open_hour)
	var pawns: Array[Pawn] = _work.get_pawns()
	var wages: float = 0.0
	for pawn: Pawn in pawns:
		wages += pawn.hourly_wage * hours
	var open_orders: int = _rack.get_ticket_count() + _work.get_waiting_orders().size()
	var report: DayReport = _finances.close_day(day, wages, pawns.size(), hours, open_orders)
	_reputation.close_day(report)
	if _clock.speed > 0:
		_clock.toggle_pause()
	_hud.show_report(report)


func _on_report_closed() -> void:
	_hud.hide_report()
	if _clock.speed == 0:
		_clock.toggle_pause()

#endregion

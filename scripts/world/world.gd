extends Node2D
## The shop. Sets up the floor, stations and staff, and connects the systems: orders print
## tickets, the WorkManager has pawns work them, finished orders are paid for, late ones are
## cancelled, and each day closes with a report. Also handles the player's input.

## Recipe printed by the debug hotkey (J).
@export var debug_recipe: Recipe
## Shop minutes a finished order waits where it was handed off before it goes out
## (placeholder until customers pick orders up).
@export var pickup_wait_minutes: float = 0.6
## Placeholder: new tickets go straight to the bottom of Make instead of waiting in Wait.
@export var auto_make: bool = true

var _stations: Array[Station] = []
## Station shown in the station panel, or null.
var _selected_station: Station = null

@onready var _floor: ShopFloor = $ShopFloor
@onready var _entities: Node2D = $Entities
@onready var _walls: ShopWalls = $Entities/Walls
@onready var _camera: ShopCamera = $ShopCamera
@onready var _work: WorkManager = $Work
@onready var _rack: TicketRack = $TicketRack
@onready var _clock: ShopClock = $ShopClock
@onready var _orders: OrderSource = $OrderSource
@onready var _finances: ShopFinances = $ShopFinances
@onready var _hud: Hud = $Hud


func _ready() -> void:
	_camera.position = _floor.cell_to_global(_floor.get_used_rect().get_center())
	_walls.build(_floor)
	_work.setup(_floor, _entities, _rack)
	for child: Node in _entities.get_children():
		if child is Station:
			_setup_station(child as Station)
	for child: Node in _entities.get_children():
		if child is Pawn:
			var pawn := child as Pawn
			pawn.global_position = _floor.cell_to_global(_floor.get_random_walkable_cell())
			_work.add_pawn(pawn)

	_rack.jobs_changed.connect(_work.assign_all)
	_rack.job_withdrawn.connect(_work.withdraw_job)
	_rack.ticket_completed.connect(_on_ticket_completed)
	_rack.ticket_cancelled.connect(_on_ticket_cancelled)
	_work.order_ready.connect(_on_order_ready)
	_work.ingredients_used.connect(_finances.record_ingredients)
	_clock.time_changed.connect(_on_time_changed)
	_clock.day_started.connect(_on_day_started)
	_orders.setup(_clock)
	_orders.order_placed.connect(_print_ticket)

	_hud.setup(_clock, _rack, _finances, _work.get_pawns(), _work.work_types)
	_hud.priority_change_requested.connect(_on_priority_change_requested)
	_hud.role_change_requested.connect(_on_role_change_requested)
	_hud.station_close_requested.connect(_select_station.bind(null))
	_hud.report_closed.connect(_on_report_closed)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"debug_queue_job"):
		_print_ticket([debug_recipe] as Array[Recipe])
	elif event.is_action_pressed(&"toggle_priorities"):
		_hud.toggle_priorities()
	elif event.is_action_pressed(&"toggle_walls"):
		_walls.cycle_view_mode()
	elif event.is_action_pressed(&"toggle_pause"):
		_clock.toggle_pause()
	elif event.is_action_pressed(&"speed_1"):
		_clock.set_speed(_clock.speeds[1])
	elif event.is_action_pressed(&"speed_2"):
		_clock.set_speed(_clock.speeds[2])
	elif event.is_action_pressed(&"speed_3"):
		_clock.set_speed(_clock.speeds[3])
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_select_station(_station_at(get_global_mouse_position()))
	else:
		return
	get_viewport().set_input_as_handled()


func _setup_station(station: Station) -> void:
	station.place(_floor)
	for cell: Vector2i in station.get_footprint_cells():
		_floor.set_cell_blocked(cell, true)
	_stations.append(station)
	_work.add_station(station)


#region Stations

## The role-taking station under a point, or null. Checks a little below the point too,
## since tabletops are drawn above their floor cells.
func _station_at(point: Vector2) -> Station:
	for lift: float in [0.0, 16.0]:
		var cell: Vector2i = _floor.global_to_cell(point + Vector2(0.0, lift))
		for station: Station in _stations:
			if station.has_roles() and station.get_footprint_cells().has(cell):
				return station
	return null


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


func _on_role_change_requested(station: Station, role: StationRole) -> void:
	station.set_role(role)
	if station == _selected_station:
		_hud.show_station(station)
	_work.assign_all()


func _on_priority_change_requested(pawn: Pawn, work_type: WorkType, priority: int) -> void:
	pawn.set_priority(work_type, priority)
	_hud.refresh_priorities()
	_work.try_assign(pawn)

#endregion


#region Orders

func _print_ticket(recipes: Array[Recipe]) -> void:
	var ticket: Ticket = _rack.print_ticket(recipes)
	if auto_make:
		_rack.move_ticket(ticket, Ticket.Section.MAKE, _rack.get_tickets(Ticket.Section.MAKE).size())


## Handed off: after a short wait the customer picks it up.
func _on_order_ready(ticket: Ticket) -> void:
	get_tree().create_timer(ShopClock.minutes_to_seconds(pickup_wait_minutes)).timeout.connect(
		_send_out.bind(ticket)
	)


## The finished order is picked up and paid for: its stack leaves and frees its spot.
func _send_out(ticket: Ticket) -> void:
	_finances.record_sale(ticket.get_price(), ticket.order_items.size(), ticket.get_age(_rack.now_minutes))
	var stack: Item = ticket.stack_base.item if ticket.stack_base != null else null
	for order_item: OrderItem in ticket.order_items:
		order_item.item = null
	if stack != null:
		if stack.station != null:
			stack.station.take_item(stack.spot)
		stack.queue_free()
	_rack.send_out(ticket)


func _on_ticket_completed(ticket: Ticket) -> void:
	print("Ticket %s complete" % ticket.get_title())


## The customer gave up: the sale is lost and whatever was made for it is thrown out.
func _on_ticket_cancelled(ticket: Ticket) -> void:
	_finances.record_missed(ticket.get_price())
	_work.throw_out_leftovers(ticket)

#endregion


#region Time

func _on_time_changed(_day: int, _minute: int) -> void:
	_rack.now_minutes = _clock.get_open_minutes()
	_rack.cancel_overdue()
	_hud.update_ticket_times()


## A day ended: pay wages and bills, and pause on the day's report until it's closed.
## Orders still open carry over into the new day.
func _on_day_started(day: int) -> void:
	if day <= 1:
		return
	var hours: float = float(_clock.close_hour - _clock.open_hour)
	var pawns: Array[Pawn] = _work.get_pawns()
	var wages: float = 0.0
	for pawn: Pawn in pawns:
		wages += pawn.hourly_wage * hours
	var report: DayReport = _finances.close_day(day - 1, wages, pawns.size(), hours, _rack.get_ticket_count())
	if _clock.speed > 0:
		_clock.toggle_pause()
	_hud.show_report(report)


func _on_report_closed() -> void:
	_hud.hide_report()
	if _clock.speed == 0:
		_clock.toggle_pause()

#endregion

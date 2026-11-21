extends Node2D
## Prototype shop scene. Wires the floor, stations, ticket rack, HUD and pawns together.
## Idle pawns take Make-ticket work by their priorities; with nothing to do they wander.


## A station spot a job could be done at.
class Spot:
	var station: Station
	var index: int

	func _init(p_station: Station, p_index: int) -> void:
		station = p_station
		index = p_index


## Recipe printed by the debug hotkey until customers exist.
@export var debug_recipe: Recipe
## Columns of the priority grid, left to right. On a priority tie, pawns pick leftmost.
@export var work_types: Array[WorkType] = []
@export var idle_time_min: float = 0.5
@export var idle_time_max: float = 2.0
## Chance an idle pawn checks their phone instead of just standing (placeholder).
@export_range(0.0, 1.0) var phone_chance: float = 0.3
@export var phone_time_min: float = 3.0
@export var phone_time_max: float = 6.0
## Item scene spawned when a ticket's first step starts (no ingredient storage yet).
@export var item_scene: PackedScene
## Seconds a finished order waits where it was handed off before it goes out (placeholder
## until customers pick orders up).
@export var pickup_wait: float = 1.5
## Placeholder: new tickets go straight to the bottom of Make instead of waiting in Wait.
@export var auto_make: bool = true

var _pawns: Array[Pawn] = []
var _stations: Array[Station] = []
## Pawns standing by a busy item (e.g. at the oven), waiting to pick it up.
var _waiting_for: Dictionary[Item, Pawn] = {}
## Pawns holding a ticket's item (e.g. by the oven) while someone sets out its container.
var _waiting_for_container: Dictionary[OrderItem, Pawn] = {}
## Station shown in the station panel, or null.
var _selected_station: Station = null

@onready var _floor: ShopFloor = $ShopFloor
@onready var _entities: Node2D = $Entities
@onready var _walls: ShopWalls = $Entities/Walls
@onready var _camera: ShopCamera = $ShopCamera
@onready var _rack: TicketRack = $TicketRack
@onready var _rack_panel: TicketRackPanel = $Hud/TicketRackPanel
@onready var _priority_panel: PriorityPanel = $Hud/PriorityPanel
@onready var _station_panel: StationPanel = $Hud/StationPanel
@onready var _clock: ShopClock = $ShopClock
@onready var _clock_panel: ClockPanel = $Hud/ClockPanel
@onready var _orders: OrderSource = $OrderSource
@onready var _finances: ShopFinances = $ShopFinances
@onready var _day_report_panel: DayReportPanel = $Hud/DayReportPanel


func _ready() -> void:
	_camera.position = _floor.cell_to_global(_floor.get_used_rect().get_center())
	_walls.build(_floor)
	for child: Node in _entities.get_children():
		if child is Station:
			_setup_station(child as Station)
	for child: Node in _entities.get_children():
		if child is Pawn:
			_setup_pawn(child as Pawn)

	_rack.changed.connect(_on_rack_changed)
	_rack.jobs_changed.connect(_on_rack_jobs_changed)
	_rack.job_withdrawn.connect(_on_rack_job_withdrawn)
	_rack.ticket_completed.connect(_on_rack_ticket_completed)
	_rack_panel.move_requested.connect(_rack.move_ticket)
	_on_rack_changed()
	_priority_panel.priority_change_requested.connect(_on_priority_change_requested)
	_priority_panel.show_priorities(_pawns, work_types)
	_station_panel.role_change_requested.connect(_on_role_change_requested)
	_station_panel.close_requested.connect(_select_station.bind(null))
	_clock_panel.setup(_clock.speeds)
	_clock_panel.speed_requested.connect(_clock.set_speed)
	_clock.time_changed.connect(_clock_panel.show_time)
	_clock.speed_changed.connect(_clock_panel.show_speed)
	_clock_panel.show_time(_clock.day, _clock.get_minute_of_day())
	_clock_panel.show_speed(_clock.speed)
	_clock.time_changed.connect(_on_time_changed)
	_clock.day_started.connect(_on_day_started)
	_finances.cash_changed.connect(_clock_panel.show_cash)
	_clock_panel.show_cash(_finances.cash)
	_day_report_panel.continue_requested.connect(_on_report_closed)
	_orders.setup(_clock)
	_orders.order_placed.connect(_print_ticket)

	for pawn: Pawn in _pawns:
		_wait_then_wander(pawn)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"debug_queue_job"):
		_print_ticket([debug_recipe] as Array[Recipe])
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"toggle_priorities"):
		_priority_panel.visible = not _priority_panel.visible
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"toggle_walls"):
		_walls.cycle_view_mode()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"toggle_pause"):
		_clock.toggle_pause()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"speed_1"):
		_clock.set_speed(_clock.speeds[1])
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"speed_2"):
		_clock.set_speed(_clock.speeds[2])
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"speed_3"):
		_clock.set_speed(_clock.speeds[3])
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		if click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
			_select_station(_station_at(get_global_mouse_position()))
			get_viewport().set_input_as_handled()


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
	if station == null:
		_station_panel.hide()
		return
	station.set_selected(true)
	_station_panel.show_station(station)


func _on_role_change_requested(station: Station, role: StationRole) -> void:
	station.set_role(role)
	if station == _selected_station:
		_station_panel.show_station(station)
	_on_rack_jobs_changed()


func _setup_station(station: Station) -> void:
	station.place(_floor)
	for cell: Vector2i in station.get_footprint_cells():
		_floor.set_cell_blocked(cell, true)
	_stations.append(station)


func _setup_pawn(pawn: Pawn) -> void:
	pawn.global_position = _floor.cell_to_global(_floor.get_random_walkable_cell())
	pawn.path_finished.connect(_on_pawn_path_finished.bind(pawn))
	pawn.stop_reached.connect(_on_pawn_stop_reached.bind(pawn))
	pawn.work_started.connect(_on_pawn_work_started.bind(pawn))
	pawn.job_finished.connect(_on_pawn_job_finished.bind(pawn))
	pawn.work_progressed.connect(_on_pawn_work_progressed.bind(pawn))
	_pawns.append(pawn)


## Gives the pawn work by their priorities: priority 1 first, ties going to the leftmost
## work type, and within a work type the first open job in Make-rack order. Returns false
## if there's nothing they can do.
## Only priorities up to `max_priority` are considered.
func _try_assign_work(pawn: Pawn, max_priority: int = Pawn.LOWEST_PRIORITY) -> bool:
	if pawn.has_job():
		return true
	var jobs: Array[Job] = _rack.get_open_jobs()
	for priority: int in range(1, max_priority + 1):
		for work_type: WorkType in work_types:
			if pawn.get_priority(work_type) != priority:
				continue
			for job: Job in jobs:
				if job.task_type.work_type == work_type and _try_job(pawn, job):
					return true
	return false


## Assigns the job if the pawn can reach a free spot for it. If the job needs something
## brought (the ticket's item, a supply from storage, an ingredient), the pawn fetches it
## on the way. A busy item (e.g. still baking) can be fetched early: the pawn waits by it.
func _try_job(pawn: Pawn, job: Job) -> bool:
	var task: TaskType = job.task_type
	var carried: Item = _get_carried(job)
	if carried == null and task.ingredient != null:
		return _try_ingredient_job(pawn, job)
	var supply_station: Station = null
	if carried == null and task.fetch_supply != &"":
		supply_station = _find_supply(task.fetch_supply)
		if supply_station == null:
			return false
	for spot: Spot in _spots_for(job):
		var stops: Array[JobStop] = []
		if supply_station != null:
			stops.append(JobStop.take_supply(supply_station))
		elif carried != null and not _is_at(carried, spot):
			stops.append(JobStop.pick_up(_get_pickup_cell(carried)))
		elif carried != null and carried.busy:
			# Can't work an item in place while a station is still working it.
			continue
		if _start_job(pawn, job, spot, stops):
			return true
	return false


## For a step that starts from an ingredient (e.g. stretching a dough ball): takes a unit
## from an open container on a station that does the step, or if none is open, sets a full
## one out from storage first. Whoever takes the last unit drops the empty container off at
## storage for empties on the way, if there's room.
func _try_ingredient_job(pawn: Pawn, job: Job) -> bool:
	var ingredient: IngredientContainer = job.task_type.ingredient
	var spots: Array[Spot] = _spots_for(job)
	var container: Item = _find_open_container(job)
	if container != null:
		# Whoever ends up taking the last unit is decided on arrival (see TAKE_UNIT).
		var stops: Array[JobStop] = [JobStop.take_unit(container)]
		for spot: Spot in spots:
			if _start_job(pawn, job, spot, stops):
				return true
		return false
	# One container set out at a time; the others wait for it.
	if _is_setting_out(ingredient):
		return false
	var storage: Station = _find_supply(ingredient.full_kind)
	if storage == null:
		return false
	for set_out_spot: Spot in spots:
		for spot: Spot in spots:
			if spot.station == set_out_spot.station and spot.index == set_out_spot.index:
				continue
			var stops: Array[JobStop] = [
				JobStop.take_supply(storage),
				JobStop.set_out(set_out_spot.station, set_out_spot.index),
			]
			if _start_job(pawn, job, spot, stops):
				return true
	return false


## Gives the pawn the job if they can walk to each stop and then the spot. Claims what the
## stops need and reserves the spot.
func _start_job(pawn: Pawn, job: Job, spot: Spot, stops: Array[JobStop]) -> bool:
	var from_cell: Vector2i = _floor.global_to_cell(pawn.global_position)
	var stop_paths: Array[PackedVector2Array] = []
	for stop: JobStop in stops:
		var path: PackedVector2Array = _floor.get_path_points(from_cell, stop.cell)
		if path.is_empty():
			return false
		stop_paths.append(path)
		from_cell = stop.cell
	var work_path: PackedVector2Array = _floor.get_path_points(
		from_cell, spot.station.get_work_cell(spot.index)
	)
	if work_path.is_empty():
		return false
	spot.station.reserve(spot.index)
	job.station = spot.station
	job.spot = spot.index
	for stop: JobStop in stops:
		stop.claim()
	job.stops = stops
	pawn.assign_job(job, stop_paths, work_path, spot.station.get_work_target(spot.index))
	_rack.notify_job_state_changed()
	return true


## An ingredient container for the job's step, set out on a station that does the step,
## with a unit no one has claimed. Null if there's none.
func _find_open_container(job: Job) -> Item:
	for station: Station in _stations:
		if not station.can_do(job.task_type):
			continue
		for index: int in station.get_spot_count():
			var item: Item = station.get_item(index)
			if (
				item != null and item.ingredient == job.task_type.ingredient
				and item.get_free_units() > 0
			):
				return item
	return null


## True if a pawn is on their way to set out a container of `ingredient`.
func _is_setting_out(ingredient: IngredientContainer) -> bool:
	for pawn: Pawn in _pawns:
		var job: Job = pawn.get_job()
		if job == null or job.task_type.ingredient != ingredient:
			continue
		for stop: JobStop in job.stops:
			if stop.action == JobStop.Action.SET_OUT:
				return true
	return false


## The item this job moves to its spot: the container for set-out steps, otherwise the
## order item's thing being made (for a hand-off, the stack's base, carrying the stack).
## Null if it doesn't exist yet.
func _get_carried(job: Job) -> Item:
	if job.task_type.fetch_supply != &"":
		return job.order_item.container
	return job.order_item.item


## Free spots where the job can be done, with the one already holding its item first.
## Steps worked at the container go to the spot where it's set out. If it isn't ready, a
## step that puts the item in it sets the item down on a free spot instead (so a pizza
## doesn't wait in the oven for a box), and a later step moves it into the box.
func _spots_for(job: Job) -> Array[Spot]:
	var task: TaskType = job.task_type
	var own: Item = _get_carried(job)
	var result: Array[Spot] = []
	if task.onto_stack:
		# Worked where the order's stack stands.
		var base: Item = job.ticket.stack_base.item
		if base.station != null and not base.station.is_reserved(base.spot):
			result.append(Spot.new(base.station, base.spot))
		return result
	if task.is_at_container():
		var box_spot: Spot = _get_container_spot(job.order_item)
		if box_spot != null:
			result.append(box_spot)
			return result
		if not task.into_container:
			return result
	for station: Station in _stations:
		if not station.can_do(task):
			continue
		for index: int in station.get_spot_count():
			if station.is_reserved(index):
				continue
			var held: Item = station.get_item(index)
			if held != null and held != own:
				continue
			if held != null:
				result.push_front(Spot.new(station, index))
			else:
				result.append(Spot.new(station, index))
	if task.into_container and result.size() < _count_waiting_for_container() + 2:
		# Setting this item down without its container must leave a spot free to set the
		# container out on, for it and every other item already waiting. Otherwise unboxed
		# pizzas could fill every spot and no box could ever be opened.
		result.clear()
	return result


## Order items whose item sits set down on a spot, waiting for its container (e.g. a pizza
## out of the oven before its box was opened).
func _count_waiting_for_container() -> int:
	var count: int = 0
	for ticket: Ticket in _rack.get_tickets(Ticket.Section.MAKE):
		for order_item: OrderItem in ticket.order_items:
			var job: Job = order_item.current_job
			if (
				order_item.container == null and order_item.item != null
				and order_item.item.station != null and job != null
				and job.task_type.is_at_container() and not job.task_type.into_container
			):
				count += 1
	return count


## The free spot where the order item's container sits set out and ready, or null.
func _get_container_spot(order_item: OrderItem) -> Spot:
	var container: Item = order_item.container
	if container == null or container.station == null:
		return null
	if container.station.is_reserved(container.spot):
		return null
	return Spot.new(container.station, container.spot)


## First storage station with an unclaimed unit of `kind`, or null.
func _find_supply(kind: StringName) -> Station:
	for station: Station in _stations:
		if station.has_supply(kind):
			return station
	return null


## First storage station with an unclaimed free place for `kind`, or null.
func _find_room(kind: StringName) -> Station:
	for station: Station in _stations:
		if station.has_room(kind):
			return station
	return null


func _is_at(item: Item, spot: Spot) -> bool:
	var outer: Item = item.get_outermost()
	return outer.station == spot.station and outer.spot == spot.index


## Where a pawn stands to pick up an item: its spot's work cell, or the floor cell it's on.
func _get_pickup_cell(item: Item) -> Vector2i:
	var outer: Item = item.get_outermost()
	if outer.station != null:
		return outer.station.get_work_cell(outer.spot)
	return _floor.global_to_cell(outer.global_position)


func _spawn_item(texture: Texture2D) -> Item:
	var item := item_scene.instantiate() as Item
	_entities.add_child(item)
	item.set_texture(texture)
	return item


## A full ingredient container, lid on.
func _spawn_ingredient_container(ingredient: IngredientContainer) -> Item:
	var container: Item = _spawn_item(null)
	container.ingredient = ingredient
	container.set_wrap(ingredient.back_texture, ingredient.front_texture)
	container.set_lid(ingredient.lid_texture)
	for offset: Vector2 in ingredient.unit_offsets:
		container.put_in(_spawn_item(ingredient.unit_texture), offset)
	return container


## The station works the item on its own; when done it takes its new look and can be
## moved again.
func _work_unattended(item: Item, task: TaskType, done_texture: Texture2D) -> void:
	item.busy = true
	var station: Station = item.station
	var spot: int = item.spot
	var tween: Tween = create_tween()
	tween.tween_method(
		func(progress: float) -> void: station.show_work(spot, progress),
		0.0, 1.0, task.base_work_time
	)
	await tween.finished
	station.hide_work()
	if not is_instance_valid(item):
		return
	item.busy = false
	item.set_texture(done_texture)
	var waiting: Pawn = _waiting_for.get(item)
	if waiting != null:
		_waiting_for.erase(item)
		_pick_up(waiting.get_job(), waiting)
		if not _waiting_for_container.values().has(waiting):
			waiting.resume_job()
	_on_rack_jobs_changed()


## The finished order is picked up and paid for: its stack leaves and frees its spot.
func _send_out(ticket: Ticket) -> void:
	var revenue: float = 0.0
	for order_item: OrderItem in ticket.order_items:
		revenue += order_item.recipe.price
	_finances.record_sale(
		revenue, ticket.order_items.size(), maxi(_rack.now_minutes - ticket.printed_at, 0)
	)
	var stack: Item = ticket.stack_base.item if ticket.stack_base != null else null
	for order_item: OrderItem in ticket.order_items:
		order_item.item = null
	if stack != null:
		if stack.station != null:
			stack.station.take_item(stack.spot)
		stack.queue_free()
	_rack.send_out(ticket)


func _drop_on_floor(item: Item, cell: Vector2i) -> void:
	item.reparent(_entities, false)
	item.global_position = _floor.cell_to_global(cell)


func _work_or_wander(pawn: Pawn) -> void:
	if not _try_assign_work(pawn):
		_wait_then_wander(pawn)


func _release_station(job: Job) -> void:
	if job.station != null:
		job.station.release(job.spot)
		job.station = null
		job.spot = -1
	for stop: JobStop in job.stops:
		stop.release()
	job.stops.clear()


func _send_to_random_cell(pawn: Pawn) -> void:
	if pawn.has_job():
		return
	var from_cell: Vector2i = _floor.global_to_cell(pawn.global_position)
	var path: PackedVector2Array = _floor.get_path_points(
		from_cell, _floor.get_random_walkable_cell()
	)
	if path.size() < 2:
		_wait_then_wander(pawn)
		return
	pawn.follow_path(path)


func _wait_then_wander(pawn: Pawn) -> void:
	var wait: float = randf_range(idle_time_min, idle_time_max)
	if randf() < phone_chance:
		pawn.use_phone()
		wait = randf_range(phone_time_min, phone_time_max)
	get_tree().create_timer(wait).timeout.connect(_send_to_random_cell.bind(pawn))


func _print_ticket(recipes: Array[Recipe]) -> void:
	var ticket: Ticket = _rack.print_ticket(recipes)
	if auto_make:
		_rack.move_ticket(
			ticket, Ticket.Section.MAKE, _rack.get_tickets(Ticket.Section.MAKE).size()
		)


## A day ended: pay wages and bills, and pause on the day's report until it's closed.
## Orders still open carry over into the new day.
func _on_day_started(day: int) -> void:
	if day <= 1:
		return
	var hours: float = float(_clock.close_hour - _clock.open_hour)
	var wages: float = 0.0
	for pawn: Pawn in _pawns:
		wages += pawn.hourly_wage * hours
	var open_orders: int = (
		_rack.get_tickets(Ticket.Section.WAIT).size() + _rack.get_tickets(Ticket.Section.MAKE).size()
	)
	var report: DayReport = _finances.close_day(day - 1, wages, _pawns.size(), hours, open_orders)
	if _clock.speed > 0:
		_clock.toggle_pause()
	_day_report_panel.show_report(report)


func _on_report_closed() -> void:
	_day_report_panel.hide()
	if _clock.speed == 0:
		_clock.toggle_pause()


func _on_time_changed(_day: int, _minute: int) -> void:
	_rack.now_minutes = _clock.get_open_minutes()
	_rack_panel.update_times(_rack.now_minutes)


func _on_rack_changed() -> void:
	_rack_panel.show_rack(
		_rack.get_tickets(Ticket.Section.WAIT), _rack.get_tickets(Ticket.Section.MAKE),
		_rack.now_minutes
	)


func _on_priority_change_requested(pawn: Pawn, work_type: WorkType, priority: int) -> void:
	pawn.set_priority(work_type, priority)
	_priority_panel.show_priorities(_pawns, work_types)
	_try_assign_work(pawn)


## Offers open work to idle pawns, priority 1 first across everyone, so a pawn with a job
## at 1 gets it before another pawn who has it at 3.
func _on_rack_jobs_changed() -> void:
	for max_priority: int in range(1, Pawn.LOWEST_PRIORITY + 1):
		for pawn: Pawn in _pawns:
			_try_assign_work(pawn, max_priority)


func _on_rack_job_withdrawn(job: Job) -> void:
	var pawn: Pawn = job.claimed_by
	var waited_for: Item = _waiting_for.find_key(pawn)
	if waited_for != null:
		_waiting_for.erase(waited_for)
	var waited_item: OrderItem = _waiting_for_container.find_key(pawn)
	if waited_item != null:
		_waiting_for_container.erase(waited_item)
	pawn.drop_job()
	var held: Item = pawn.release_item()
	if held != null:
		_drop_on_floor(held, _floor.global_to_cell(pawn.global_position))
	_release_station(job)
	_rack.notify_job_state_changed()
	_work_or_wander(pawn)


func _on_rack_ticket_completed(ticket: Ticket) -> void:
	print("Ticket %s complete" % ticket.get_title())


func _on_pawn_path_finished(pawn: Pawn) -> void:
	_work_or_wander(pawn)


func _on_pawn_stop_reached(job: Job, pawn: Pawn) -> void:
	var stop: JobStop = job.stops.pop_front()
	match stop.action:
		JobStop.Action.PICK_UP:
			var item: Item = _get_carried(job)
			if item.busy:
				# Not ready yet (e.g. still baking): stand by until the station is done.
				_waiting_for[item] = pawn
				pawn.wait_at_stop(item.get_outermost().global_position)
				return
			_pick_up(job, pawn)
		JobStop.Action.TAKE_SUPPLY:
			_take_supply(job, stop.station, pawn)
		JobStop.Action.SET_OUT:
			# Lid off, onto the spot, and the first unit out.
			var container: Item = pawn.release_item()
			stop.station.release(stop.spot)
			container.set_lid(null)
			stop.station.put_item(stop.spot, container)
			container.claim_unit()
			_take_unit(job, container, pawn)
			_on_rack_jobs_changed()
		JobStop.Action.TAKE_UNIT:
			var container: Item = stop.container
			if container.get_units().size() == 1 and _detour_to_store_empty(job, pawn):
				# The last unit: carry the container off with it, and take it out there.
				job.order_item.item = container.get_units().back()
				container.unclaim_unit()
				container.station.take_item(container.spot)
				pawn.hold_item(container)
				_on_rack_jobs_changed()
			else:
				_take_unit(job, container, pawn)
		JobStop.Action.STORE_EMPTY:
			var container: Item = pawn.release_item()
			var unit: Item = job.order_item.item
			container.take_out(unit)
			pawn.hold_item(unit)
			container.queue_free()
			stop.station.add_stock()
			_on_rack_jobs_changed()


## Takes a claimed unit of stock from storage and carries it: a full ingredient container
## for ingredient steps, otherwise the order item's container (e.g. a box).
func _take_supply(job: Job, station: Station, pawn: Pawn) -> void:
	station.take_supply()
	if job.task_type.ingredient != null:
		pawn.hold_item(_spawn_ingredient_container(job.task_type.ingredient))
		return
	job.order_item.container = _spawn_item(station.get_storage_layout().textures[0])
	pawn.hold_item(job.order_item.container)


## Adds a stop at storage for empties before the pawn goes on to work, if there's room
## and they can get there. Returns false if not (the empty container stays where it is).
func _detour_to_store_empty(job: Job, pawn: Pawn) -> bool:
	var empties: Station = _find_room(job.task_type.ingredient.empty_kind)
	if empties == null:
		return false
	var stop: JobStop = JobStop.store_empty(empties)
	var to_stop: PackedVector2Array = _floor.get_path_points(
		_floor.global_to_cell(pawn.global_position), stop.cell
	)
	var to_work: PackedVector2Array = _floor.get_path_points(
		stop.cell, job.station.get_work_cell(job.spot)
	)
	if to_stop.is_empty() or to_work.is_empty() or not pawn.detour(to_stop, to_work):
		return false
	stop.claim()
	job.stops.push_front(stop)
	return true


## Takes a claimed unit out of an ingredient container; it becomes the order item's item.
func _take_unit(job: Job, container: Item, pawn: Pawn) -> void:
	var unit: Item = container.take_unit()
	job.order_item.item = unit
	pawn.hold_item(unit)


func _pick_up(job: Job, pawn: Pawn) -> void:
	var item: Item = _get_carried(job)
	if item.container != null and item.container.ingredient != null:
		# Left in a dropped ingredient container: take it out.
		item.container.take_out(item)
	var from_station: Station = item.station
	if from_station != null:
		from_station.take_item(item.spot)
	pawn.hold_item(item)
	if job.task_type.into_container:
		_redirect_to_container(job, pawn)
	if from_station != null:
		# The spot is free for other tickets now.
		_on_rack_jobs_changed()


## The pawn was headed to set the item down on a free spot because its container wasn't
## ready when they took the job (e.g. they waited by the oven). If it's ready now, they
## take the item straight to it instead.
## If someone is setting the container out right now, the pawn waits holding the item.
func _redirect_to_container(job: Job, pawn: Pawn) -> void:
	var box_spot: Spot = _get_container_spot(job.order_item)
	if box_spot == null:
		if _is_container_on_its_way(job.order_item):
			_waiting_for_container[job.order_item] = pawn
			pawn.wait_at_stop(pawn.global_position + Vector2(0.0, -1.0))
		return
	if box_spot.station == job.station and box_spot.index == job.spot:
		return
	var path: PackedVector2Array = _floor.get_path_points(
		_floor.global_to_cell(pawn.global_position),
		box_spot.station.get_work_cell(box_spot.index)
	)
	if path.is_empty():
		return
	job.station.release(job.spot)
	box_spot.station.reserve(box_spot.index)
	job.station = box_spot.station
	job.spot = box_spot.index
	pawn.redirect_work(path, box_spot.station.get_work_target(box_spot.index))
	_on_rack_jobs_changed()


## True if a pawn is fetching or opening the order item's container.
func _is_container_on_its_way(order_item: OrderItem) -> bool:
	for job: Job in order_item.prep_jobs:
		if job.task_type.fetch_supply != &"" and job.claimed_by != null:
			return true
	return false


## The container is set out: a pawn holding its item by the oven takes it there.
func _on_container_ready(order_item: OrderItem) -> void:
	var pawn: Pawn = _waiting_for_container.get(order_item)
	if pawn == null:
		return
	_waiting_for_container.erase(order_item)
	var job: Job = pawn.get_job()
	if job != null:
		_redirect_to_container(job, pawn)
	pawn.resume_job()


func _on_pawn_work_started(job: Job, pawn: Pawn) -> void:
	var order_item: OrderItem = job.order_item
	var item: Item = pawn.release_item()
	if item == null and order_item.item == null and job.task_type.fetch_supply == &"":
		item = _spawn_item(order_item.recipe.get_stage_texture(order_item.step_index))
		order_item.item = item
	if item == null:
		return
	if job.task_type.onto_stack:
		# On top of the order's stack.
		var stack: Item = job.ticket.stack_base.item
		stack.put_in(
			item, Vector2(0.0, -job.task_type.stack_step * (stack.get_units().size() + 1))
		)
		return
	var container: Item = order_item.container
	var at_box: bool = container != null and job.station.get_item(job.spot) == container
	if job.task_type.is_at_container() and at_box:
		container.put_in(item)
		return
	job.station.put_item(job.spot, item)


func _on_pawn_work_progressed(job: Job, progress: float, _pawn: Pawn) -> void:
	var frames: Array[Texture2D] = job.task_type.work_frames
	if frames.is_empty() or job.order_item.item == null:
		return
	# The work is split into one stretch with no overlay, then one per frame.
	var index: int = mini(int(progress * (frames.size() + 1)), frames.size()) - 1
	job.order_item.item.set_overlay(frames[index] if index >= 0 else null)


func _on_pawn_job_finished(job: Job, pawn: Pawn) -> void:
	var ticket: Ticket = job.ticket
	var order_item: OrderItem = job.order_item
	var task: TaskType = job.task_type
	# Stacking and hand-off move finished items; the rest are recipe steps.
	var recipe_step: bool = not task.onto_stack and job != ticket.hand_off_job
	if task.fetch_supply != &"":
		# The container is set out: show it open.
		order_item.container.set_texture(null)
		order_item.container.set_wrap(
			task.container_under_texture, task.container_over_texture,
			task.container_contents_offset
		)
	if task.closes_container:
		# The item and its container become one (e.g. a closed box).
		order_item.container.take_out(order_item.item)
		order_item.item.queue_free()
		order_item.item = order_item.container
		order_item.container = null
		order_item.item.set_wrap(null, null)

	var item: Item = order_item.item
	_finances.record_ingredients(task.ingredient_cost)
	_release_station(job)
	_rack.complete_job(job)
	if task.fetch_supply != &"":
		_on_container_ready(order_item)
	if recipe_step and item != null and task.unattended:
		_work_unattended(
			item, task, order_item.recipe.get_stage_texture(order_item.step_index)
		)
	elif recipe_step and item != null and task.fetch_supply == &"":
		item.set_texture(order_item.recipe.get_stage_texture(order_item.step_index))
	if ticket.ready:
		get_tree().create_timer(pickup_wait).timeout.connect(_send_out.bind(ticket))
	if not pawn.has_job():
		_work_or_wander(pawn)

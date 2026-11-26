class_name WorkManager
extends Node
## Hands out work and sees it through. Idle pawns take open jobs by their priorities: the
## ticket rack's, plus shop jobs like throwing out leftovers. Each job's task behavior
## plans where it's done and what's fetched on the way, and handles what happens to the
## items; this node walks pawns through it. With nothing to do, pawns wander.

## An order's last job is done: it's ready to go out.
signal order_ready(ticket: Ticket)
## A pawn took a customer's order at the register (`job`, with its recipes, when they
## ordered and the manager's quote): its ticket should print now.
signal order_taken(job: Job)
## The manager changed (null: nobody is).
signal manager_changed(manager: Pawn)
## The number of customers waiting at the register changed.
signal waiting_orders_changed(count: int)
## The shop started or stopped rushing (see is_rushing()).
signal rush_changed(rushing: bool)
## A fired pawn is out the door and no longer staff (see fire()).
signal pawn_left(pawn: Pawn)

## Columns of the priority grid, left to right. On a priority tie, pawns pick leftmost.
@export var work_types: Array[WorkType] = []
## Spawned for every item (pizzas, boxes, containers).
@export var item_scene: PackedScene
## Taking leftovers to the garbage.
@export var throw_out_task: TaskType
## How good finished items are (see QualityRules).
@export var quality_rules: QualityRules
## Taking a customer's order at the register.
@export var take_order_task: TaskType
## Restocking tasks (e.g. folding boxes): a job opens for one whenever its behavior says
## it's needed. Pawns only take them when they have nothing else to do.
@export var restock_tasks: Array[TaskType] = []
## Chores (e.g. washing dishes): a job opens for one whenever its behavior says it's needed,
## and pawns take it by their priorities like order work.
@export var chore_tasks: Array[TaskType] = []
## The manager's skill. Not a priority-grid column: the manager is picked separately.
@export var managing: WorkType
## How the manager quotes each order's wait.
@export var quote_rules: QuoteRules
## A tired pawn's break at a break table (a table with the Break role).
@export var break_task: TaskType
## How many recent order jobs the average walk per job is taken over (for quotes).
@export var walk_samples: int = 50
## A pawn is sent for a baking item this many shop minutes before it's done (it's not
## offered before then), enough to walk over before the earliest pull time.
@export var fetch_lead_minutes: float = 1.0
@export var idle_time_min: float = 0.5
@export var idle_time_max: float = 2.0
## Chance an idle pawn checks their phone instead of just standing (placeholder).
@export_range(0.0, 1.0) var phone_chance: float = 0.3
@export var phone_time_min: float = 3.0
@export var phone_time_max: float = 6.0
@export_group("Rush")
## The shop rushes when unfinished tickets on the rack outnumber this many per pawn, or any
## ticket is past its quote (placeholder).
@export var rush_tickets_per_pawn: float = 2.0
## Shop minutes without being busy before a rush ends (placeholder).
@export var rush_end_minutes: float = 5.0
@export_group("Cleanliness")
## Dirt each piece of work done at a station adds to it, 0 to 1 (placeholder). See
## TaskType.dirties_station.
@export var station_dirt_per_task: float = 0.1
@export_group("")

## How dirty the floor is (set by the world), for cleaning chores. Null: no floor dirt.
var floor_dirt: FloorDirt = null

var _floor: ShopFloor
var _entities: Node2D
var _rack: TicketRack
var _pawns: Array[Pawn] = []
var _stations: Array[Station] = []
## Pawns standing by a busy item (e.g. at the oven), waiting to pick it up.
var _waiting_for: Dictionary[Item, Pawn] = {}
## Pawns holding an order item's item (e.g. by the oven) while someone sets out its
## container.
var _waiting_for_container: Dictionary[OrderItem, Pawn] = {}
## Shop jobs outside any order (throwing out leftovers), not done yet.
var _shop_jobs: Array[Job] = []
## Items a station is working on its own (e.g. baking), and ones done with doneness rules
## that nobody has taken out yet.
var _bakes: Array[Bake] = []
## The timer a pawn standing by an item is waiting on to take it out (see _bakes).
var _pull_timers: Dictionary[Item, SceneTreeTimer] = {}
## Shop minutes pawns walked for each recent order job, before starting work (newest last).
var _walk_minutes: Array[float] = []
## Game seconds so far (speed included), for timing bakes.
var _now: float = 0.0
var _rushing: bool = false
## Shop minutes the shop has gone without being busy during a rush.
var _calm_minutes: float = 0.0
## Where staff come in and go home: the front door's cell and the street outside it.
var _door_cell: Vector2i = Vector2i.ZERO
var _outside_cell: Vector2i = Vector2i.ZERO
var _has_door: bool = false
## Pawns off shift, walking out to go home.
var _leaving: Array[Pawn] = []


## An item a station works on its own (see TaskType.unattended).
class Bake:
	var item: Item
	var order_item: OrderItem
	var station: Station
	var spot: int
	var done_texture: Texture2D
	var rules: DonenessRules
	var tween: Tween
	## Game seconds (see WorkManager._now) when the station is done with it.
	var done_at: float


func _process(delta: float) -> void:
	_now += delta
	_update_rush(delta / ShopClock.minutes_to_seconds(1.0))


## True while the shop is rushing: pawns work faster, but it stresses them (see PawnMood).
func is_rushing() -> bool:
	return _rushing


## Starts a rush as soon as the shop is busy, and ends it after rush_end_minutes calm.
func _update_rush(minutes: float) -> void:
	if _is_busy():
		_calm_minutes = 0.0
		if not _rushing:
			_set_rushing(true)
	elif _rushing:
		_calm_minutes += minutes
		if _calm_minutes >= rush_end_minutes:
			_set_rushing(false)


func _set_rushing(rushing: bool) -> void:
	_rushing = rushing
	_calm_minutes = 0.0
	for pawn: Pawn in _pawns:
		pawn.set_rushing(rushing)
	rush_changed.emit(rushing)


## Busy: more unfinished tickets than rush_tickets_per_pawn per pawn, or any past its quote.
func _is_busy() -> bool:
	if _rack == null or _pawns.is_empty():
		return false
	var open: int = 0
	for section: Ticket.Section in [Ticket.Section.WAIT, Ticket.Section.MAKE]:
		for ticket: Ticket in _rack.get_tickets(section):
			if ticket.ready:
				continue
			if ticket.get_quote_miss(_rack.now_minutes) > 0:
				return true
			open += 1
	return open > rush_tickets_per_pawn * maxi(get_pawns_on_shift().size(), 1)


## Call once before adding stations and pawns. Items are spawned under `entities`.
func setup(shop_floor: ShopFloor, entities: Node2D, rack: TicketRack) -> void:
	_floor = shop_floor
	_entities = entities
	_rack = rack


func add_station(station: Station) -> void:
	_stations.append(station)


## Stops using the station (e.g. while it's picked up to move): no new jobs go to it or take
## things off it, and pawns whose jobs involve it stop (see interrupt_jobs_at()).
func remove_station(station: Station) -> void:
	_stations.erase(station)
	interrupt_jobs_at(station)


## Stops every pawn whose job involves the station: working at it, or on the way to take
## something from it or bring something to it. They set down what they carry; the jobs
## keep their progress and are offered again (see withdraw_job()).
func interrupt_jobs_at(station: Station) -> void:
	for pawn: Pawn in _pawns:
		var job: Job = pawn.get_job()
		if job != null and _involves(job, station):
			withdraw_job(job)


func _involves(job: Job, station: Station) -> bool:
	if job.station == station or job.destination == station:
		return true
	for stop: JobStop in job.stops:
		if stop.station == station:
			return true
		if stop.container != null and is_instance_valid(stop.container) \
				and stop.container.get_outermost().station == station:
			return true
	var carried: Item = job.task_type.get_behavior().get_carried(job)
	return carried != null and is_instance_valid(carried) and carried.get_outermost().station == station


## True if pawns can use the item: it isn't on a station that's out of use (e.g. picked up).
func is_available(item: Item) -> bool:
	var station: Station = item.get_outermost().station
	if station != null and not _stations.has(station):
		return false
	# A baking item isn't fetched until it's nearly done, so nobody stands at the oven for
	# the whole bake.
	var bake: Bake = _find_bake(item)
	return bake == null or _now >= bake.done_at - _fetch_lead_seconds()


func _fetch_lead_seconds() -> float:
	return ShopClock.minutes_to_seconds(fetch_lead_minutes)


## Takes the pawn on as staff; they start by idling.
func add_pawn(pawn: Pawn) -> void:
	pawn.path_finished.connect(_on_pawn_path_finished.bind(pawn))
	pawn.stop_reached.connect(_on_pawn_stop_reached.bind(pawn))
	pawn.work_started.connect(_on_pawn_work_started.bind(pawn))
	pawn.job_finished.connect(_on_pawn_job_finished.bind(pawn))
	pawn.work_progressed.connect(_on_pawn_work_progressed.bind(pawn))
	pawn.breakdown_ended.connect(_on_pawn_back_to_work.bind(pawn))
	pawn.break_ended.connect(_on_pawn_back_to_work.bind(pawn))
	pawn.shop_floor = _floor
	pawn.set_rushing(_rushing)
	_pawns.append(pawn)
	_wait_then_wander(pawn)


func get_pawns() -> Array[Pawn]:
	return _pawns


## Lets `pawn` go: they finish their job, walk out the door and are gone (pawn_left). A
## fired manager leaves the shop with none.
func fire(pawn: Pawn) -> void:
	if not _pawns.has(pawn) or pawn.let_go:
		return
	pawn.let_go = true
	pawn.on_shift = false
	if pawn.is_manager:
		set_manager(null)
	if pawn.is_away():
		_remove_pawn(pawn)
	elif not pawn.has_job():
		_send_home(pawn)


func _remove_pawn(pawn: Pawn) -> void:
	_pawns.erase(pawn)
	_leaving.erase(pawn)
	pawn_left.emit(pawn)


## Pawns at the shop on shift (not gone home or heading out).
func get_pawns_on_shift() -> Array[Pawn]:
	var on_shift: Array[Pawn] = []
	for pawn: Pawn in _pawns:
		if pawn.on_shift and not pawn.is_away() and not _leaving.has(pawn):
			on_shift.append(pawn)
	return on_shift


## Staff come in and go home through the door on `door_cell`'s edge toward `outside_cell`.
func set_staff_door(door_cell: Vector2i, outside_cell: Vector2i) -> void:
	_door_cell = door_cell
	_outside_cell = outside_cell
	_has_door = true


## Brings each pawn's shift up to date at `minute_of_day`: pawns whose shift starts come in;
## pawns whose shift is over finish their job, then go home. Also sets the length of each
## pawn's break today (from how long they're scheduled) and whether it's due. With
## `instant`, pawns off shift are simply gone (e.g. as the game starts).
func update_shifts(minute_of_day: int, instant: bool = false) -> void:
	for pawn: Pawn in _pawns:
		var on: bool = not pawn.let_go and pawn.is_scheduled_at(minute_of_day)
		pawn.on_shift = on
		if pawn.mood != null:
			var rules: MoodRules = pawn.mood.rules
			pawn.mood.break_length = rules.get_break_minutes(pawn.get_scheduled_minutes(24 * 60))
			pawn.mood.break_due = on and pawn.schedule != null \
				and pawn.schedule.get_shift_end(minute_of_day) - minute_of_day <= rules.break_due_minutes_left
		if on:
			if pawn.is_away():
				_clock_in(pawn)
			elif _leaving.has(pawn):
				# Their shift started again on the way out: they turn back.
				_leaving.erase(pawn)
				pawn.stop_walking()
				_work_or_wander(pawn)
		elif instant and not pawn.has_job() and not pawn.is_away():
			_leaving.erase(pawn)
			pawn.set_away(true)
		elif not pawn.has_job():
			_send_home(pawn)


## A pawn off shift with no job walks out the front door, then is gone until their next
## shift.
func _send_home(pawn: Pawn) -> void:
	if pawn.is_away() or _leaving.has(pawn):
		return
	if not _has_door:
		pawn.set_away(true)
		if pawn.let_go:
			_remove_pawn(pawn)
		return
	_leaving.append(pawn)
	pawn.stop_walking()
	var path: PackedVector2Array = get_walk_path(get_cell(pawn), _door_cell)
	path.append(_floor.cell_to_global(_outside_cell))
	pawn.follow_path(path)


## A pawn's shift starts: they walk in the front door and look for work.
func _clock_in(pawn: Pawn) -> void:
	pawn.set_away(false)
	if not _has_door:
		pawn.global_position = _floor.cell_to_global(_floor.get_random_walkable_cell())
		_work_or_wander(pawn)
		return
	pawn.global_position = _floor.cell_to_global(_outside_cell)
	pawn.follow_path(PackedVector2Array([_floor.cell_to_global(_door_cell)]))


## Every work type pawns have a skill level in: the grid's, plus Managing.
func get_skill_types() -> Array[WorkType]:
	var types: Array[WorkType] = []
	for work_type: WorkType in work_types:
		if work_type.has_skill:
			types.append(work_type)
	if managing != null:
		types.append(managing)
	return types


## The pawn managing the shop, or null.
func get_manager() -> Pawn:
	for pawn: Pawn in _pawns:
		if pawn.is_manager:
			return pawn
	return null


## Who quotes orders right now: the manager if they're on shift, or else the pawn on shift
## with the best Managing skill. Null with nobody on shift, or no manager at all.
func get_quoting_pawn() -> Pawn:
	if get_manager() == null:
		return null
	var on_shift: Array[Pawn] = get_pawns_on_shift()
	var best: Pawn = null
	for pawn: Pawn in on_shift:
		if pawn.is_manager:
			return pawn
		if best == null or pawn.get_skill(managing) > best.get_skill(managing):
			best = pawn
	return best


## Makes `pawn` the manager, replacing any other; null leaves the shop with none.
func set_manager(pawn: Pawn) -> void:
	for each: Pawn in _pawns:
		each.is_manager = each == pawn
	manager_changed.emit(pawn)


## Shop minutes pawns have recently walked per order job, on average (0 before any).
## Follows the layout: a spread-out kitchen walks more.
func get_average_walk_minutes() -> float:
	if _walk_minutes.is_empty():
		return 0.0
	var total: float = 0.0
	for minutes: float in _walk_minutes:
		total += minutes
	return total / _walk_minutes.size()


## The quoted wait for an order of `recipes`, in shop minutes, by the manager or whoever
## covers for them (see get_quoting_pawn()), or -1 with nobody. Quoting is Managing practice.
func quote_order(recipes: Array[Recipe]) -> int:
	var manager: Pawn = get_quoting_pawn()
	if manager == null or quote_rules == null:
		return -1
	var estimate := WaitEstimate.new(
		get_pawns_on_shift(), take_order_task, _rack.stack_task, _rack.hand_off_task, get_average_walk_minutes(),
		_stations
	)
	var tickets: Array[Ticket] = _rack.get_tickets(Ticket.Section.WAIT)
	tickets.append_array(_rack.get_tickets(Ticket.Section.MAKE))
	var minutes: float = estimate.estimate(recipes, tickets, get_waiting_orders())
	var quote: int = quote_rules.roll_quote(minutes, manager.get_skill(managing), manager.skill_rules)
	manager.practice(managing, quote_rules.practice_per_quote)
	return quote


func get_stations() -> Array[Station]:
	return _stations


func get_shop_jobs() -> Array[Job]:
	return _shop_jobs


## Tracks a job outside any order (e.g. a restock job once it's claimed) until it's done.
func add_shop_job(job: Job) -> void:
	if not _shop_jobs.has(job):
		_shop_jobs.append(job)


func get_make_tickets() -> Array[Ticket]:
	return _rack.get_tickets(Ticket.Section.MAKE)


#region Handing out work

## Offers open work to idle pawns, priority 1 first across everyone, so a pawn with a job
## at 1 gets it before another pawn who has it at 3.
func assign_all() -> void:
	for max_priority: int in range(1, Pawn.LOWEST_PRIORITY + 1):
		for pawn: Pawn in _pawns:
			try_assign(pawn, max_priority)


## Gives the pawn work by their priorities: priority 1 first, ties going to the leftmost
## work type, and within a work type the first open job in Make-rack order (shop jobs
## last). Only priorities up to `max_priority` are considered. Returns false if there's
## nothing they can do.
func try_assign(pawn: Pawn, max_priority: int = Pawn.LOWEST_PRIORITY) -> bool:
	if pawn.has_job():
		return true
	if pawn.is_away() or _leaving.has(pawn):
		return false
	if not pawn.on_shift:
		_send_home(pawn)
		return false
	if pawn.is_off_work():
		return false
	if pawn.wants_break():
		# A free break table spot, or else they rest where they stand.
		if break_task != null and break_task.get_behavior().try_start(pawn, Job.new(break_task, null, null), self):
			return true
		pawn.start_standing_break()
		return false
	var jobs: Array[Job] = _rack.get_open_jobs()
	for job: Job in _shop_jobs:
		if job.claimed_by == null and not job.on_hold:
			jobs.append(job)
	for task: TaskType in chore_tasks:
		if task.get_behavior().is_needed(self):
			jobs.append(Job.new(task, null, null))
	if _try_jobs(pawn, jobs, max_priority):
		return true
	# Restocking (e.g. folding boxes) is filler: only for a pawn with nothing else to do at
	# any priority, so it never holds up orders.
	if max_priority < Pawn.LOWEST_PRIORITY:
		return false
	var restock: Array[Job] = []
	for task: TaskType in restock_tasks:
		if task.get_behavior().is_needed(self):
			restock.append(Job.new(task, null, null))
	return _try_jobs(pawn, restock, max_priority)


## Starts the first of `jobs` the pawn can do, by their priorities (see try_assign()).
func _try_jobs(pawn: Pawn, jobs: Array[Job], max_priority: int) -> bool:
	for priority: int in range(1, max_priority + 1):
		for work_type: WorkType in work_types:
			if pawn.get_priority(work_type) != priority:
				continue
			for job: Job in jobs:
				if job.task_type.work_type != work_type:
					continue
				if job.task_type.get_behavior().try_start(pawn, job, self):
					return true
	return false


## Gives the pawn the job if they can walk to each stop and then the spot. Claims what the
## stops need and reserves the spot.
func start_job(pawn: Pawn, job: Job, spot: WorkSpot, stops: Array[JobStop]) -> bool:
	# Nothing goes to a station that's out of use (e.g. picked up to move).
	if not _stations.has(spot.station):
		return false
	for stop: JobStop in stops:
		if stop.station != null and not _stations.has(stop.station):
			return false
		if stop.container != null and not is_available(stop.container):
			return false
	var from_cell: Vector2i = get_cell(pawn)
	var stop_paths: Array[PackedVector2Array] = []
	for stop: JobStop in stops:
		var path: PackedVector2Array = get_walk_path(from_cell, stop.cell)
		if path.is_empty():
			return false
		stop_paths.append(path)
		from_cell = stop.cell
	var work_path: PackedVector2Array = get_walk_path(from_cell, spot.station.get_work_cell(spot.index))
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


## Gives the pawn a job worked standing on a floor cell (e.g. mopping it) rather than at a
## station spot, if they can walk there. The job has no station.
func start_floor_job(pawn: Pawn, job: Job, cell: Vector2i) -> bool:
	var path: PackedVector2Array = get_walk_path(get_cell(pawn), cell)
	if path.is_empty():
		return false
	job.floor_cell = cell
	pawn.assign_job(job, [] as Array[PackedVector2Array], path, _floor.cell_to_global(cell))
	_rack.notify_job_state_changed()
	return true


## For a job done in parts (see TaskBehavior.continue_job()): lets go of its spot, moves it
## on to `part` with no work done, and gives the same pawn that part at the first of `spots`
## they can reach. Returns false if they can't reach any.
func start_next_part(pawn: Pawn, job: Job, part: int, spots: Array[WorkSpot]) -> bool:
	job.station.release(job.spot)
	job.station = null
	job.spot = -1
	job.part = part
	job.work_done = 0.0
	for spot: WorkSpot in spots:
		if start_job(pawn, job, spot, [] as Array[JobStop]):
			return true
	return false


## Sends the pawn to work at `spot` instead of where they were headed (e.g. straight to a
## box that was opened while they waited at the oven). Returns false if they can't get
## there.
func redirect(job: Job, pawn: Pawn, spot: WorkSpot) -> bool:
	var path: PackedVector2Array = get_walk_path(get_cell(pawn), spot.station.get_work_cell(spot.index))
	if path.is_empty():
		return false
	job.station.release(job.spot)
	spot.station.reserve(spot.index)
	job.station = spot.station
	job.spot = spot.index
	pawn.redirect_work(path, spot.station.get_work_target(spot.index))
	assign_all()
	return true


## The pawn's job was pulled (e.g. its ticket went back to Wait or was cancelled): they
## drop what they carry and look for other work.
func withdraw_job(job: Job) -> void:
	var pawn: Pawn = job.claimed_by
	var waited_for: Item = _waiting_for.find_key(pawn)
	if waited_for != null:
		_waiting_for.erase(waited_for)
		_pull_timers.erase(waited_for)
	var waited_item: OrderItem = _waiting_for_container.find_key(pawn)
	if waited_item != null:
		_waiting_for_container.erase(waited_item)
	pawn.drop_job()
	var held: Item = pawn.release_item()
	if held != null:
		drop_on_floor(held, get_cell(pawn))
	if job.task_type.opens_station and job.station != null:
		job.station.set_opened(job.spot, false)
	_release(job)
	job.task_type.get_behavior().on_withdrawn(job, self)
	_rack.notify_job_state_changed()
	_work_or_wander(pawn)


## Drops a shop job that won't be done (e.g. restocking interrupted halfway).
func cancel_shop_job(job: Job) -> void:
	_shop_jobs.erase(job)

#endregion


#region Queries for task behaviors

## Free spots on stations that do `task`, with the one already holding `own` first.
func get_free_spots(task: TaskType, own: Item) -> Array[WorkSpot]:
	var result: Array[WorkSpot] = []
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
				result.push_front(WorkSpot.new(station, index))
			else:
				result.append(WorkSpot.new(station, index))
	return result


## The free spot where the order item's container sits set out and ready, or null.
func get_container_spot(order_item: OrderItem) -> WorkSpot:
	var container: Item = order_item.container
	if container == null or container.station == null or not _stations.has(container.station):
		return null
	if container.station.is_reserved(container.spot):
		return null
	return WorkSpot.new(container.station, container.spot)


## First storage station with an unclaimed unit of `kind`, or null.
func find_supply(kind: StorageKind) -> Station:
	for station: Station in _stations:
		if station.has_supply(kind):
			return station
	return null


## First storage station with an unclaimed free place for `kind` (as `dish`, for storage
## that holds dishes), or null.
func find_room(kind: StorageKind, dish: Dish = null) -> Station:
	for station: Station in _stations:
		if station.has_room(kind, dish):
			return station
	return null


## Dish sinks in use, in station order.
func get_sinks() -> Array[Station]:
	var sinks: Array[Station] = []
	for station: Station in _stations:
		if station.get_dish_boards() != null:
			sinks.append(station)
	return sinks


## First dish sink with an unclaimed free place on its dirty drainboard, or null.
func find_dish_room() -> Station:
	for sink: Station in get_sinks():
		if sink.get_dish_boards().has_dirty_room():
			return sink
	return null


## True if the item (or what it's in) sits on the spot.
func is_item_at(item: Item, spot: WorkSpot) -> bool:
	var outer: Item = item.get_outermost()
	return outer.station == spot.station and outer.spot == spot.index


## Where a pawn stands to pick up an item: its spot's work cell, or the floor cell it's on.
func get_pickup_cell(item: Item) -> Vector2i:
	var outer: Item = item.get_outermost()
	if outer.station != null:
		return outer.station.get_work_cell(outer.spot)
	return _floor.global_to_cell(outer.global_position)


func get_cell(node: Node2D) -> Vector2i:
	return _floor.global_to_cell(node.global_position)


## Cells were just blocked (a station was put down): pawns whose walk crosses them find
## another way to the same places. A pawn on a job that can't get there any more drops it
## (see withdraw_job()); a wandering pawn that can't stops and wanders again later.
func reroute_around(cells: Array[Vector2i]) -> void:
	for pawn: Pawn in _pawns:
		var route: Array[PackedVector2Array] = pawn.get_route()
		if not _route_crosses(route, cells):
			continue
		if _leaving.has(pawn):
			# On their way home: a new way out.
			_leaving.erase(pawn)
			_send_home(pawn)
			continue
		if not pawn.has_job():
			var wander: PackedVector2Array = route[0]
			var path: PackedVector2Array = get_walk_path(
				get_cell(pawn), _floor.global_to_cell(wander[wander.size() - 1]))
			if path.size() >= 2:
				pawn.follow_path(path)
			else:
				pawn.stop_walking()
				_wait_then_wander(pawn)
			continue
		var new_route: Array[PackedVector2Array] = []
		var from_cell: Vector2i = get_cell(pawn)
		for leg: PackedVector2Array in route:
			if leg.is_empty():
				new_route.append(leg)
				continue
			var to_cell: Vector2i = _floor.global_to_cell(leg[leg.size() - 1])
			var path: PackedVector2Array = get_walk_path(from_cell, to_cell)
			if path.is_empty():
				withdraw_job(pawn.get_job())
				new_route.clear()
				break
			new_route.append(path)
			from_cell = to_cell
		if not new_route.is_empty():
			pawn.set_route(new_route)


func _route_crosses(route: Array[PackedVector2Array], cells: Array[Vector2i]) -> bool:
	for leg: PackedVector2Array in route:
		for point: Vector2 in leg:
			if cells.has(_floor.global_to_cell(point)):
				return true
	return false


## True if pawns can stand on the cell (floor, not under furniture).
func is_walkable(cell: Vector2i) -> bool:
	return _floor.is_walkable(cell)


## Walking path between floor cells, or empty if there's no way.
func get_walk_path(from_cell: Vector2i, to_cell: Vector2i) -> PackedVector2Array:
	return _floor.get_path_points(from_cell, to_cell)


func spawn_item(texture: Texture2D) -> Item:
	var item := item_scene.instantiate() as Item
	_entities.add_child(item)
	item.set_texture(texture)
	return item

#endregion


#region Containers

## The pawn holds the order item's item and waits until its container is set out.
func wait_for_container(order_item: OrderItem, pawn: Pawn) -> void:
	_waiting_for_container[order_item] = pawn
	pawn.wait_at_stop(pawn.global_position + Vector2(0.0, -1.0))


## The order item's container is set out: a pawn waiting with its item takes it there.
func on_container_ready(order_item: OrderItem) -> void:
	var pawn: Pawn = _waiting_for_container.get(order_item)
	if pawn == null:
		return
	_waiting_for_container.erase(order_item)
	var job: Job = pawn.get_job()
	if job != null:
		job.task_type.get_behavior().on_picked_up(job, pawn, self)
	pawn.resume_job()

#endregion


#region Register

## A customer orders `recipes` at shop time `placed_at`: they wait at the register until a
## pawn takes the order (see order_taken). `quoted` is the manager's quote (-1 if none).
## With `on_hold`, nobody takes it until release_order() (the customer is still in line).
## Returns the take-order job.
func take_order(recipes: Array[Recipe], placed_at: int, quoted: int = -1, on_hold: bool = false) -> Job:
	var job := Job.new(take_order_task, null, null)
	job.recipes = recipes
	job.placed_at = placed_at
	job.quoted_minutes = quoted
	job.on_hold = on_hold
	_shop_jobs.append(job)
	waiting_orders_changed.emit(get_waiting_orders().size())
	assign_all()
	return job


## The customer reached the register: a Cashier pawn can take their order now.
func release_order(job: Job) -> void:
	if not job.on_hold:
		return
	job.on_hold = false
	assign_all()


## Orders waiting at the register to be taken, oldest first.
func get_waiting_orders() -> Array[Job]:
	var waiting: Array[Job] = []
	for job: Job in _shop_jobs:
		if not job.recipes.is_empty():
			waiting.append(job)
	return waiting


## The customer gave up before their order was taken: it's dropped, and a pawn taking it
## stops.
func drop_order(job: Job) -> void:
	_shop_jobs.erase(job)
	if job.claimed_by != null:
		withdraw_job(job)
	waiting_orders_changed.emit(get_waiting_orders().size())

#endregion


#region Leftovers

## Adds a job to take `item` to the garbage, unless there is one already.
func throw_out(item: Item) -> void:
	for job: Job in _shop_jobs:
		if job.target == item:
			return
	var job := Job.new(throw_out_task, null, null)
	job.target = item
	_shop_jobs.append(job)


## Throws out everything made for a cancelled order (its items, or what they're in), wherever
## it is. Its claimed jobs must already be withdrawn, so what was being carried is on the
## floor. Other orders' things stay, and so does an ingredient container with units left
## that aren't this order's (e.g. a dough tub set out for everyone, or one a pawn was
## fetching): it's put away as usual.
func throw_out_leftovers(ticket: Ticket) -> void:
	var own: Array[Item] = []
	for order_item: OrderItem in ticket.order_items:
		for item: Item in [order_item.item, order_item.container]:
			if item != null and is_instance_valid(item):
				own.append(item)
	var leftovers: Array[Item] = []
	for item: Item in own:
		var outer: Item = item.get_outermost()
		if outer.ingredient != null and _has_other_units(outer, own):
			continue
		if not leftovers.has(outer):
			leftovers.append(outer)
	for item: Item in leftovers:
		throw_out(item)
	assign_all()


## True if the ingredient container holds a unit that isn't one of `own`.
func _has_other_units(container: Item, own: Array[Item]) -> bool:
	for unit: Item in container.get_units():
		if not own.has(unit):
			return true
	return false

#endregion


#region Pawns working

func _on_pawn_path_finished(pawn: Pawn) -> void:
	if _leaving.has(pawn):
		# Out the door: gone until their next shift (or for good, if fired).
		_leaving.erase(pawn)
		pawn.set_away(true)
		if pawn.let_go:
			_remove_pawn(pawn)
		return
	_work_or_wander(pawn)


func _on_pawn_stop_reached(job: Job, pawn: Pawn) -> void:
	var stop: JobStop = job.stops.pop_front()
	var behavior: TaskBehavior = job.task_type.get_behavior()
	match stop.action:
		JobStop.Action.PICK_UP:
			var item: Item = behavior.get_carried(job)
			if _is_unjudged(item, job):
				# Taken out when the pawn thinks it's time, which sets how done it is.
				var wait: float = _roll_pull_time(item, pawn, job) - _now
				if wait <= 0.0:
					_pull(job, pawn)
					return
				_stand_by(item, pawn, stop)
				var timer: SceneTreeTimer = get_tree().create_timer(wait)
				_pull_timers[item] = timer
				timer.timeout.connect(_on_pull_time.bind(_find_bake(item), pawn, job, timer))
				return
			if item.busy:
				# Not ready yet (e.g. still baking): stand by until the station is done.
				_stand_by(item, pawn, stop)
				return
			_pick_up(job, pawn)
		JobStop.Action.TAKE_SUPPLY:
			job.taken_kind = stop.kind
			job.taken_dish = stop.dish if stop.dish != null else stop.station.get_top_dish(stop.kind)
			job.taken_left = stop.station.take_supply(stop.kind, stop.dish)
			behavior.on_supply_taken(job, stop.station, pawn, self)
		_:
			behavior.on_stop_reached(job, stop, pawn, self)


## The pawn stands at the stop facing the item until it can be picked up.
func _stand_by(item: Item, pawn: Pawn, stop: JobStop) -> void:
	_waiting_for[item] = pawn
	var look_at: Vector2 = item.get_outermost().global_position
	if stop.station != null and stop.spot >= 0:
		look_at = stop.station.get_work_target(stop.spot)
	pawn.wait_at_stop(look_at)


## True if the job's pawn taking the item out sets how done it is (the next recipe step
## after a station worked it with doneness rules).
func _is_unjudged(item: Item, job: Job) -> bool:
	var bake: Bake = _find_bake(item)
	return bake != null and bake.rules != null and job.recipe_step


func _find_bake(item: Item) -> Bake:
	for bake: Bake in _bakes:
		if bake.item == item:
			return bake
	return null


## Game seconds (see _now) when the pawn thinks it's time to take the item out, by their
## skill in the job's work type.
func _roll_pull_time(item: Item, pawn: Pawn, job: Job) -> float:
	var bake: Bake = _find_bake(item)
	var level: int = pawn.get_skill(job.task_type.work_type)
	var minutes: float = bake.rules.roll_pull_minutes(level, pawn.skill_rules)
	return bake.done_at + ShopClock.minutes_to_seconds(minutes)


func _on_pull_time(bake: Bake, pawn: Pawn, job: Job, timer: SceneTreeTimer) -> void:
	# The pawn may have been stopped meanwhile (and maybe come back on a new timer), and the
	# item thrown out.
	var item: Item = bake.item
	if (
		not is_instance_valid(item) or _pull_timers.get(item) != timer
		or _waiting_for.get(item) != pawn or pawn.get_job() != job
	):
		return
	_pull_timers.erase(item)
	_waiting_for.erase(item)
	_pull(job, pawn)
	if not _waiting_for_container.values().has(pawn):
		pawn.resume_job()


## The pawn takes the item out now, which sets how done it is, and picks it up. If the
## station isn't done with it yet, it stops there (under).
func _pull(job: Job, pawn: Pawn) -> void:
	var item: Item = job.task_type.get_behavior().get_carried(job)
	var bake: Bake = _find_bake(item)
	_bakes.erase(bake)
	var minutes_after: float = (_now - bake.done_at) / ShopClock.minutes_to_seconds(1.0)
	var doneness: DonenessRules.Doneness = bake.rules.judge(minutes_after)
	var early: bool = item.busy
	if early:
		bake.tween.kill()
		_finish_bake(bake, false)
	item.set_tint(bake.rules.get_tint(doneness))
	if bake.order_item != null:
		bake.order_item.doneness = doneness
	_pick_up(job, pawn)
	if early:
		assign_all()


func _pick_up(job: Job, pawn: Pawn) -> void:
	var behavior: TaskBehavior = job.task_type.get_behavior()
	var item: Item = behavior.get_carried(job)
	if item.container != null and item.container.ingredient != null:
		# Left in a dropped ingredient container: take it out.
		item.container.take_out(item)
	var from_station: Station = item.station
	if from_station != null:
		from_station.take_item(item.spot)
	pawn.hold_item(item)
	behavior.on_picked_up(job, pawn, self)
	if from_station != null:
		# The spot is free for other tickets now.
		assign_all()


func _on_pawn_work_started(job: Job, pawn: Pawn) -> void:
	if job.ticket != null or not job.recipes.is_empty():
		_walk_minutes.append(pawn.get_walk_seconds() / ShopClock.minutes_to_seconds(1.0))
		if _walk_minutes.size() > walk_samples:
			_walk_minutes.pop_front()
	if job.task_type.opens_station and job.station != null:
		job.station.set_opened(job.spot, true)
	job.task_type.get_behavior().on_work_started(job, pawn, self)


func _on_pawn_work_progressed(job: Job, progress: float, _pawn: Pawn) -> void:
	var frames: Array[Texture2D] = job.task_type.work_frames
	if frames.is_empty() or job.order_item == null or job.order_item.item == null:
		return
	# The work is split into one stretch with no overlay, then one per frame.
	var index: int = mini(int(progress * (frames.size() + 1)), frames.size()) - 1
	job.order_item.item.set_overlay(frames[index] if index >= 0 else null)


func _on_pawn_job_finished(job: Job, pawn: Pawn) -> void:
	var task: TaskType = job.task_type
	var behavior: TaskBehavior = task.get_behavior()
	# Only work that took time dirties the station (not just setting something down).
	if job.station != null and task.dirties_station and not task.rest and job.get_work_required() > 0.0:
		job.station.add_dirt(station_dirt_per_task)
	behavior.on_finished(job, pawn, self)
	if behavior.continue_job(job, pawn, self):
		# The same pawn goes on to the job's next part.
		return
	if not behavior.is_step_done(job):
		# The item was only moved out of the way (e.g. parked on a rack): the step is open again.
		_release(job)
		job.claimed_by = null
		job.work_done = 0.0
		job.part = 0
		_rack.notify_job_state_changed()
		assign_all()
		if not pawn.has_job():
			_work_or_wander(pawn)
		return
	if task.affects_quality and job.recipe_step and job.order_item != null:
		job.order_item.skill_levels.append(pawn.get_quality_level(task.work_type))
	var station: Station = job.station
	var spot: int = job.spot
	if station != null and floor_dirt != null and randf() < task.spill_chance:
		floor_dirt.add_spill(station.get_work_cell(spot))
	_release(job)
	var order_item: OrderItem = job.order_item
	# A recipe step changes how the item looks (a baking pizza changes once it's done).
	# Prep steps run alongside the others and don't.
	var shows_step: bool = job.recipe_step and not task.prep and order_item.item != null
	if shows_step and task.unattended:
		# Started before the rack hands out the next step, so taking it out isn't offered
		# until it's nearly done (see is_available()).
		_work_unattended(order_item, task, order_item.recipe.get_stage_texture(order_item.step_index + 1))
	if job.ticket != null:
		# The rack moves the order on, which hands out work.
		_rack.complete_job(job)
		_judge_quality(job.order_item)
	else:
		_shop_jobs.erase(job)
		if not job.recipes.is_empty():
			waiting_orders_changed.emit(get_waiting_orders().size())
			order_taken.emit(job)
		assign_all()
	if task.opens_station and station != null and not _next_step_opens_station(job.order_item):
		station.set_opened(spot, false)
	behavior.after_finished(job, self)
	if shows_step and not task.unattended and order_item.item != null:
		order_item.item.set_texture(order_item.recipe.get_stage_texture(order_item.step_index))
	if job.ticket != null and job.ticket.ready:
		order_ready.emit(job.ticket)
	if not pawn.has_job():
		_work_or_wander(pawn)


## Sets an order item's quality once every step of it is done.
func _judge_quality(order_item: OrderItem) -> void:
	if quality_rules == null or order_item == null or order_item.quality_tier >= 0:
		return
	if order_item.is_complete():
		order_item.quality_tier = quality_rules.get_tier(quality_rules.get_score(order_item))


## The station works the order item's item on its own; when done it takes its new look and
## can be moved again. With doneness rules, how done it is gets set when it's taken out.
func _work_unattended(order_item: OrderItem, task: TaskType, done_texture: Texture2D) -> void:
	var bake := Bake.new()
	bake.item = order_item.item
	bake.order_item = order_item
	bake.station = bake.item.station
	bake.spot = bake.item.spot
	bake.done_texture = done_texture
	bake.rules = task.doneness_rules
	bake.done_at = _now + task.get_work_seconds()
	bake.item.busy = true
	# Drop ones whose item is gone (e.g. thrown out before it was taken out).
	_bakes.assign(_bakes.filter(func(other: Bake) -> bool: return is_instance_valid(other.item)))
	_bakes.append(bake)
	bake.tween = create_tween()
	# The station may be moved meanwhile (the item goes with it), or sold.
	var show_progress := func(progress: float) -> void:
		if is_instance_valid(bake.station):
			bake.station.show_work(bake.spot, progress)
	bake.tween.tween_method(show_progress, 0.0, 1.0, task.get_work_seconds())
	bake.tween.finished.connect(_finish_bake.bind(bake))
	# Offer taking it out once it's nearly done (see is_available()).
	var lead: float = task.get_work_seconds() - _fetch_lead_seconds()
	if lead > 0.0:
		get_tree().create_timer(lead).timeout.connect(assign_all)


## The station is done with the item (or it was taken out early): it takes its new look and
## can be moved again. Then open work is handed out, unless `assign` is false.
func _finish_bake(bake: Bake, assign: bool = true) -> void:
	if bake.tween == null:
		return
	# Let go of the tween (its finished signal is bound to this bake), so neither leaks.
	bake.tween = null
	if is_instance_valid(bake.station):
		bake.station.hide_work(bake.spot)
	var item: Item = bake.item
	if not is_instance_valid(item) or bake.rules == null:
		_bakes.erase(bake)
	if not is_instance_valid(item):
		return
	item.busy = false
	item.set_texture(bake.done_texture)
	var waiting: Pawn = _waiting_for.get(item)
	# A pawn timing when to take it out (see _on_pull_time()) keeps waiting.
	if waiting != null and not _pull_timers.has(item):
		_waiting_for.erase(item)
		_pick_up(waiting.get_job(), waiting)
		if not _waiting_for_container.values().has(waiting):
			waiting.resume_job()
	if assign:
		assign_all()


## Whether the order item's next step also opens its station (e.g. cheese after sauce), so
## the station stays open between them.
func _next_step_opens_station(order_item: OrderItem) -> bool:
	return order_item != null and order_item.current_job != null \
			and order_item.current_job.task_type.opens_station


func _release(job: Job) -> void:
	if job.station != null:
		job.station.release(job.spot)
		job.station = null
		job.spot = -1
	for stop: JobStop in job.stops:
		stop.release()
	job.stops.clear()


## Items lying on the floor (set down by an interrupted job, or dropped).
func get_floor_items() -> Array[Item]:
	var items: Array[Item] = []
	for child: Node in _entities.get_children():
		if child is Item:
			items.append(child as Item)
	return items


## Sets an item down on the floor at `cell` (e.g. one a pawn can't take where it goes).
func drop_on_floor(item: Item, cell: Vector2i) -> void:
	item.reparent(_entities, false)
	item.global_position = _floor.cell_to_global(cell)

#endregion


#region Idling

func _work_or_wander(pawn: Pawn) -> void:
	if not try_assign(pawn):
		_wait_then_wander(pawn)


func _wait_then_wander(pawn: Pawn) -> void:
	if pawn.is_away() or _leaving.has(pawn):
		return
	var wait: float = randf_range(idle_time_min, idle_time_max)
	# During a breakdown or a standing break they stay on their phone.
	if pawn.is_off_work() or randf() < phone_chance * pawn.get_slack():
		pawn.use_phone()
		wait = randf_range(phone_time_min, phone_time_max)
	# By id: a fired pawn may be gone by then.
	get_tree().create_timer(wait).timeout.connect(_send_to_random_cell.bind(pawn.get_instance_id()))


func _send_to_random_cell(pawn_id: int) -> void:
	var pawn := instance_from_id(pawn_id) as Pawn
	if pawn == null or not _pawns.has(pawn):
		return
	# Gone home, or on their way in or out (their walk's end picks things up again).
	if pawn.has_job() or pawn.is_away() or _leaving.has(pawn) or pawn.is_walking():
		return
	if not pawn.on_shift:
		_send_home(pawn)
		return
	if pawn.is_off_work():
		_wait_then_wander(pawn)
		return
	var path: PackedVector2Array = get_walk_path(get_cell(pawn), _floor.get_random_walkable_cell())
	if path.size() < 2:
		_wait_then_wander(pawn)
		return
	pawn.follow_path(path)


## Back from a breakdown or a standing break: they look for work again. (Their idle loop
## is still running, so it isn't restarted here.)
func _on_pawn_back_to_work(_pawn: Pawn) -> void:
	assign_all()

#endregion

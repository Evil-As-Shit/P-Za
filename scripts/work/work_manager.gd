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
## How many recent order jobs the average walk per job is taken over (for quotes).
@export var walk_samples: int = 50
@export var idle_time_min: float = 0.5
@export var idle_time_max: float = 2.0
## Chance an idle pawn checks their phone instead of just standing (placeholder).
@export_range(0.0, 1.0) var phone_chance: float = 0.3
@export var phone_time_min: float = 3.0
@export var phone_time_max: float = 6.0

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
	return station == null or _stations.has(station)


## Takes the pawn on as staff; they start by idling.
func add_pawn(pawn: Pawn) -> void:
	pawn.path_finished.connect(_on_pawn_path_finished.bind(pawn))
	pawn.stop_reached.connect(_on_pawn_stop_reached.bind(pawn))
	pawn.work_started.connect(_on_pawn_work_started.bind(pawn))
	pawn.job_finished.connect(_on_pawn_job_finished.bind(pawn))
	pawn.work_progressed.connect(_on_pawn_work_progressed.bind(pawn))
	pawn.shop_floor = _floor
	_pawns.append(pawn)
	_wait_then_wander(pawn)


func get_pawns() -> Array[Pawn]:
	return _pawns


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


## The manager's quoted wait for an order of `recipes`, in shop minutes, or -1 with no
## manager. Quoting is Managing practice.
func quote_order(recipes: Array[Recipe]) -> int:
	var manager: Pawn = get_manager()
	if manager == null or quote_rules == null:
		return -1
	var estimate := WaitEstimate.new(
		_pawns, take_order_task, _rack.stack_task, _rack.hand_off_task, get_average_walk_minutes()
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


## First storage station with an unclaimed free place for `kind`, or null.
func find_room(kind: StorageKind) -> Station:
	for station: Station in _stations:
		if station.has_room(kind):
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


## Throws out everything made for a cancelled order. Its claimed jobs must already be
## withdrawn, so anything being carried is on the floor; that goes too.
func throw_out_leftovers(ticket: Ticket) -> void:
	var leftovers: Array[Item] = []
	for order_item: OrderItem in ticket.order_items:
		for item: Item in [order_item.item, order_item.container]:
			if item == null or not is_instance_valid(item):
				continue
			var outer: Item = item.get_outermost()
			# A dough container set out for everyone stays.
			if outer.ingredient != null and outer.station != null:
				continue
			if not leftovers.has(outer):
				leftovers.append(outer)
	for child: Node in _entities.get_children():
		# Loose portion containers (e.g. a sauce bucket) aren't leftovers; they're put back.
		if child is Item and (child as Item).portions != null:
			continue
		if child is Item and not leftovers.has(child) and not _is_shop_job_target(child as Item):
			leftovers.append(child as Item)
	for item: Item in leftovers:
		throw_out(item)
	assign_all()


## True if a shop job is already moving the item (e.g. a folded box set down on its way to
## storage), so it isn't a leftover.
func _is_shop_job_target(item: Item) -> bool:
	for job: Job in _shop_jobs:
		if job.target == item and job.task_type != throw_out_task:
			return true
	return false

#endregion


#region Pawns working

func _on_pawn_path_finished(pawn: Pawn) -> void:
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
			job.taken_dish = stop.dish if stop.dish != null else stop.station.get_top_dish()
			job.taken_left = stop.station.take_supply(stop.dish)
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
		job.order_item.skill_levels.append(pawn.get_skill(task.work_type))
	var station: Station = job.station
	var spot: int = job.spot
	_release(job)
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
	# A recipe step changes how the item looks (a baking pizza changes once it's done).
	# Prep steps run alongside the others and don't.
	var order_item: OrderItem = job.order_item
	if job.recipe_step and not task.prep and order_item.item != null:
		var look: Texture2D = order_item.recipe.get_stage_texture(order_item.step_index)
		if task.unattended:
			_work_unattended(order_item, task, look)
		else:
			order_item.item.set_texture(look)
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
	var wait: float = randf_range(idle_time_min, idle_time_max)
	if randf() < phone_chance:
		pawn.use_phone()
		wait = randf_range(phone_time_min, phone_time_max)
	get_tree().create_timer(wait).timeout.connect(_send_to_random_cell.bind(pawn))


func _send_to_random_cell(pawn: Pawn) -> void:
	if pawn.has_job():
		return
	var path: PackedVector2Array = get_walk_path(get_cell(pawn), _floor.get_random_walkable_cell())
	if path.size() < 2:
		_wait_then_wander(pawn)
		return
	pawn.follow_path(path)

#endregion
